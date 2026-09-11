"""LM Studio GPU-kernel stall watchdog (G3) — ADDITIVE recovery layer.

Recurring failure (3× this session, audit 2026-09-01): after ~3 tool
round-trips the LM Studio GPU kernel pegs 98–100% and the model stops emitting
tokens; unload/reload clears it, but nothing was watching, so the run sat
"running" until the runner's own watchdog gave up.

This module watches one active phase: while its pi child is alive, it samples
(a) the agent's `raw_output.jsonl` mtime and (b) the GPU utilization. When the
stream has produced NO new bytes for `stall_s` seconds AND the GPU is pegged
(`gpu_pct` or more), it:

  1. traces a `model_stall` event (so the UI + audit show what happened),
  2. unloads the stalled model and reloads it (clears the kernel),
  3. SIGKILLs the stuck child so the phase fails fast with a clear reason
     instead of hanging forever — the existing model-fallback retry in
     agents.py resumes the same session cleanly on the fallback model.

Nothing existing is altered: the watchdog is a separate thread the caller
starts per dispatch and stops when the child exits. Env knobs (all additive,
all best-effort):

    FACTORY_STALL_WATCH=1          on by default; 0 disables
    FACTORY_STALL_SECS=180         no-new-bytes threshold before recovery
    FACTORY_STALL_GPU_PCT=90       GPU util at/above which a stall counts
    FACTORY_STALL_POLL=5           watchdog sampling interval
"""

from __future__ import annotations

import os
import signal
import threading
import time

from . import lm_local

_ENABLED = os.environ.get("FACTORY_STALL_WATCH", "1") == "1"
_STALL_S = int(os.environ.get("FACTORY_STALL_SECS", "180"))
_GPU_PCT = int(os.environ.get("FACTORY_STALL_GPU_PCT", "90"))
_POLL_S = float(os.environ.get("FACTORY_STALL_POLL", "5"))


class StallWatch:
    """Watch one phase's raw stream; unload→reload + kill on a GPU-pegged stall."""

    def __init__(self, factory_id: str, phase_id: str, agent: str,
                 model_key: str, raw_path: str, tracer,
                 poll_s: float = _POLL_S, stall_s: int = _STALL_S,
                 gpu_pct: int = _GPU_PCT) -> None:
        self.factory_id = factory_id
        self.phase_id = phase_id
        self.agent = agent
        self.model_key = model_key
        self.raw_path = raw_path
        self.tracer = tracer
        self.poll_s = poll_s
        self.stall_s = stall_s
        self.gpu_pct = gpu_pct
        self._pid: int | None = None
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    # ── lifecycle ────────────────────────────────────────────────────────────

    def arm(self, pid: int) -> None:
        """Start watching a live child (call from on_spawn)."""
        if not _ENABLED:
            return
        self._pid = pid
        self._stop.clear()
        self._thread = threading.Thread(target=self._run, name="stall-watch", daemon=True)
        self._thread.start()

    def disarm(self) -> None:
        """Stop watching (call from on_exit)."""
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=2)

    # ── watchdog loop ────────────────────────────────────────────────────────

    def _last_write(self) -> float:
        try:
            return os.path.getmtime(self.raw_path)
        except OSError:
            return time.time()

    def _trace(self, type_: str, payload: dict) -> None:
        try:
            from .data_types import EventRecord  # late import — avoids cycles
            self.tracer.event(EventRecord(
                factory_id=self.factory_id, phase_id=self.phase_id,
                type=type_, name=self.agent, payload=payload))
        except Exception:
            pass

    def _recover(self, stalled_since: float) -> None:
        self._trace("model_stall", {
            "agent": self.agent, "model": self.model_key,
            "stalled_seconds": int(time.time() - stalled_since),
            "recovery": "unload→reload",
            "gpu_pct": lm_local.gpu_util_pct(),
        })
        lm_local.unload_one(self.model_key)
        lm_local.load(self.model_key)
        # The child is stuck on a dead kernel — kill it so the phase fails fast
        # and the existing fallback retry in agents.py resumes the session.
        if self._pid:
            try:
                os.kill(self._pid, signal.SIGKILL)
            except ProcessLookupError:
                pass

    def _run(self) -> None:
        last = self._last_write()
        stalled_since: float | None = None
        while not self._stop.is_set():
            time.sleep(self.poll_s)
            now = self._last_write()
            if now > last:                       # stream advanced → healthy
                last, stalled_since = now, None
                continue
            if stalled_since is None:
                stalled_since = time.time()
                continue
            if time.time() - stalled_since < self.stall_s:
                continue
            gpu = lm_local.gpu_util_pct()
            if gpu is None or gpu >= self.gpu_pct:
                self._recover(stalled_since)
                return
            stalled_since = time.time()          # GPU not pegged → re-arm timer


def watch_for(request, run, phase, agent) -> StallWatch | None:
    """Build a watchdog for a pi/LM-Studio dispatch, or None when not applicable
    (opencode surface, cloud model, watchdog disabled). Additive helper."""
    if not _ENABLED:
        return None
    if agent.coding_agent != "pi":
        return None
    if not getattr(request, "model", "").startswith("lmstudio/"):
        return None
    return StallWatch(
        factory_id=run.factory_id, phase_id=phase.phase_id, agent=agent.name,
        model_key=request.model.split("/", 1)[1],
        raw_path=request.raw_output_path, tracer=run.tracer,
    )