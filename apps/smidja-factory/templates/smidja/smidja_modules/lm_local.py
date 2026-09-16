"""LM Studio local model management — load/unload via the native /api/v1 API.

Why: the smidja runs one coding agent per phase; each pi invocation asks LM
Studio to (re)load a model on demand. If models from earlier phases are left
resident, the next load attempt has no room in VRAM and the llama.cpp engine
refuses (HTTP 400) or crashes the engine (SIGABRT) — the failure mode that made
whole rosters "broken". Between uses we therefore give the target model room:
if it is already loaded we leave it (several models may be resident at once —
repeated phases on the same model stay fast), otherwise we unload whatever else
is loaded first.

Uses LM Studio's native v1 API (0.4+), not the OpenAI-compatible DELETE which
server-side returns 200 but does NOT free the VRAM allocation:
    GET  /api/v1/models                -> per-model loaded_instances[]
    POST /api/v1/models/load   {model}
    POST /api/v1/models/unload {instance_id}

Controlled by:
    SMIDJA_LM_SERVER       default http://localhost:1234
    SMIDJA_UNLOAD_MODELS   1 (default) unload non-targets when needed; 0 = disable
Everything is best-effort and never raises — a missing/unreachable server or a
non-LM-Studio backend is a no-op.
"""

from __future__ import annotations

import json
import os
import subprocess
import urllib.error
import urllib.request

SERVER = os.environ.get("SMIDJA_LM_SERVER", "http://localhost:1234")


def _get(path: str, timeout: float = 5.0):
    with urllib.request.urlopen(SERVER + path, timeout=timeout) as resp:
        return json.load(resp)


def _post(path: str, payload: dict, timeout: float = 15.0):
    req = urllib.request.Request(
        SERVER + path,
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.load(resp)


def loaded_ids() -> set[str]:
    """Set of LM Studio model keys currently resident in memory."""
    try:
        data = _get("/api/v1/models")
        return {m["key"] for m in data.get("models", []) if m.get("loaded_instances")}
    except Exception:
        return set()


def load(model_key: str) -> bool:
    """Load a single model by key (additive — used by the stall watchdog's
    unload→reload recovery). Best-effort; True if the server accepted the load."""
    try:
        _post("/api/v1/models/load", {"model": model_key}, timeout=60)
        return True
    except Exception:
        return False


def gpu_util_pct() -> float | None:
    """Current NVIDIA GPU utilization percent via nvidia-smi, or None if the
    GPU isn't reachable / this isn't an NVIDIA box. Additive — used by the
    stall watchdog to distinguish a GPU-kernel pegged stall from an ordinary
    slow model."""
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5,
        )
        if out.returncode != 0 or not out.stdout.strip():
            return None
        vals = [int(v) for v in out.stdout.strip().splitlines() if v.strip().isdigit()]
        return float(max(vals)) if vals else None
    except Exception:
        return None


def unload_all() -> int:
    """Unload every loaded LM Studio model; return the number unloaded."""
    unloaded = 0
    try:
        data = _get("/api/v1/models")
    except Exception:
        return unloaded
    for m in data.get("models", []):
        for inst in m.get("loaded_instances") or []:
            iid = inst.get("id")
            if not iid:
                continue
            try:
                _post("/api/v1/models/unload", {"instance_id": iid}, timeout=20)
                unloaded += 1
            except Exception:
                pass
    return unloaded


def unload_one(model_key: str) -> bool:
    """Unload a single model by key; best-effort. True if it was resident."""
    try:
        data = _get("/api/v1/models")
        for m in data.get("models", []):
            if m.get("key") != model_key:
                continue
            for inst in m.get("loaded_instances") or []:
                iid = inst.get("id")
                if iid:
                    _post("/api/v1/models/unload", {"instance_id": iid}, timeout=20)
                    return True
    except Exception:
        pass
    return False


def make_room_for(model_key: str) -> None:
    """Ensure `model_key` can load on LM Studio without VRAM overflow.

    - Model already loaded  -> keep it (and any other residents that fit).
    - Model not loaded      -> unload all residents first, then it loads fresh.
    - Disabled / unreachable -> no-op.
    """
    if os.environ.get("SMIDJA_UNLOAD_MODELS", "1") == "0":
        return
    try:
        data = _get("/api/v1/models")
        loaded = [m["key"] for m in data.get("models", []) if m.get("loaded_instances")]
    except Exception:
        return  # not LM Studio or server down — do nothing
    if model_key in loaded:
        return
    if loaded:
        unload_all()