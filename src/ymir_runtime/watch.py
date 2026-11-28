"""Sýn — the standing arm's behaviour, owned once by the engine.

The arm is a SERVICE (plan 58, Phase 2): it keeps its own lease, beats a
heartbeat every cycle, IDLES when no session is seated instead of retiring, and
raises exactly one `signal:` / `stale:` / `check:` / `heartbeat:` line when the
primary is needed. Until now that judgement lived in bash (`bin/pi/syn-watch.sh`,
409 lines), while the vendored watcher (`.agents/backend/fm-watch.sh`, 1962
lines) carried a second, drifting copy of the same questions over the same
record: is the arm live, is the beat fresh, what is due to be raised.

Plan 58, Phase 5 folds that seam HERE. This module is the ONE owner of "where is
the arm, is it live, what does it raise"; `bin/pi/syn-watch.sh` becomes a thin door
over it, and every caller that reads the state — Eir's `arm` surface, the thin
client `bin/pi/syn-watch-arm.sh`, the harness adapters — gets the same answer, in
the same grammar, with the same exit codes.

The state, all under the resolved state dir (Rule 04: the home, never the tree):

    .watch.heartbeat    epoch seconds, touched every cycle (the liveness door)
    .supervision-armed  the armed marker the turn-end guard reads
    .arm.lease          pid=… starttime=… gen=… mode=… role=… session=… heartbeat=… state=…
                        seat=… charter=… host=… machine=… fleetrole=… fleet=… pin=…
                        pin_behind=… identity=… missing=…   (plans 254 B1b/B1c · 257 H8)
    .arm.event          the raised-but-undelivered line (the delivery slot)
    .arm.wake           append-only journal of every line this arm has raised
    .arm.gen            the recovery-generation counter
    .wake-queue         the durable wake queue the raise reads (owned elsewhere)
    .wake-last-hash     the flood brake: one signal per DISTINCT queue content
    *.signal / *.check  one-shot raise triggers, consumed as they are raised
    .watcher-stop       the operator's stop request, raised as `stale:`
    .arm.errand-woke    the errand ledger: "<id>|dead|done|stall" -> the fact last raised
    .arm.errand-epoch   when `done:` lines were first judged against git (older ones never are)
    <id>.meta/.status   the dispatched errands the arm now questions (`errand_wake`)
    eindri-reports/<id>.md  the report whose `## Record` a `done:` is verified against (plan 339.2)
    eindri-questions/<id>.md  a question; unanswered 15 min wakes the helm, 1 h the operator (plan 339.3)
    fleet/messages.jsonl  the send log: a line into the worker's pane after its question answers it
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import signal
import socket
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping, Sequence

from . import identity as identity_mod
from . import paths as paths_mod
from . import proc
from .state import lock as lock_mod

VERSION = "1.0.0"

DEFAULT_POLL_SECONDS = 5
DEFAULT_HEARTBEAT_STALE_SECONDS = 60
DEFAULT_UNIT = "ymir-syn-watch.service"
DEFAULT_DAEMON_GRACE_SECONDS = 15

UP = "up"
IDLE = "idle"
STALE = "stale"
DOWN = "down"

WATCH_DOOR = ("bin", "pi", "syn-watch.sh")

# The lease's `role=` names the holder's declared duty set (plan 254), beside the
# service shape `mode=`. A Pi seat holds as `counsellor`; Rödd's helm declares
# `rodd`; the other harnesses keep their own comm name. `unknown` means no holder
# declared and no harness could be read — never a guess.
ROLE_BY_COMM = {"pi": "counsellor"}

# ── the cadence law ─────────────────────────────────────────────────────────
# A condition that has not changed is not news. The queue signal carries its own
# brake (one line per DISTINCT queue content); every other line is braked here:
# the same line may not repeat inside the floor, and no more than the ceiling may
# be raised in one hour — above it the arm reports its own rate once and falls
# silent. A poll loop that speaks every cycle is a heartbeat pretending to be an
# alarm (2026-10-24: twenty copies of one falsehood over a healthy arm).
RAISE_FLOOR_SECONDS = 900
RAISE_HOURLY_CEILING = 3
BRAKED_PREFIXES = ("stale:", "check:")

# H3 (plan 257): a terminal status line is itself a wake — the worker writes `done:`
# (or `failed:` / `needs-decision:` / `paused:`) and the arm raises, without the worker
# remembering to run acclaim. `blocked:` is NOT here: a blocked seat needs Brokk, and it
# travels the loud acclaim road or the failsafe, never the silent status scan.
TERMINAL_WAKE_PREFIXES = ("done:", "failed:", "needs-decision:", "paused:")

# ── the errands the house dispatched (2026-11-20) ───────────────────────────
# The arm raised on what it already knew (the queue, the lease, a status line) but
# never on the errands themselves: a pane that held no agent, a `done:` over an
# empty branch, a `working:` that had gone quiet. Three workers ended so in one
# night and were found by hand. These are the arm's own questions now, each raised
# once per (errand, kind, fact) through `.arm.errand-woke`.
#
# A status that has ended (per the brief: `done:` · `resolved:` · `failed:`) is no
# longer a dead or a stalled worker — only a `done:` is still checked against git.
ERRAND_ENDED_PREFIXES = ("done:", "resolved:", "failed:", "false-done:")
# The lines these checks raise carry their own dedup ledger, so the generic brake
# (three per hour) must not swallow the fourth dead worker of a bad night.
ERRAND_PREFIXES = ("stale: errand ", "check: errand ")
DEFAULT_ERRAND_HORIZON_SECONDS = 86400
DEFAULT_ERRAND_STALL_SECONDS = 1800
# herdr reports an agent's state; these two mean "sitting at the prompt".
IDLE_AGENT_STATES = ("idle", "done")

# ── a report counts only with its record (plan 339.2) ───────────────────────
# A `done:` is a claim. The terminal act (bin/agents/eindri-acclaim.sh) writes a
# `## Record` block into the report — the commit, the branch, the repo, the machine
# and where the commit is (pushed · parked · local only) — and the arm checks that
# claim against git, on the machine the report names. A claim git does not bear out
# turns the status to `false-done:` and wakes the helm.
FALSE_DONE_PREFIX = "false-done:"
# Errands whose deliverable is a report, not a commit: "nothing committed" is honest.
NO_COMMIT_MODES = ("scout", "review", "recon")
# Errands that owe a pushed branch; a record that says `local only` is short of it.
PUSHING_MODES = ("direct-PR", "no-mistakes", "pr")
_SHA = re.compile(r"\b([0-9a-f]{7,40})\b")
_ONELINE = re.compile(r"^\s*[`>*-]*\s*([0-9a-f]{7,40})\s+\S")

# ── the arm's fourth eye: the unanswered question (plan 339.3) ──────────────
# An errand that files `eindri-questions/<id>.md` stands waiting, and the hall shows it
# idle. Unanswered past the wake window it wakes the helm; past the escalation window it
# reaches the operator as one line through the hotline (bin/notify/send.sh).
DEFAULT_QUESTION_WAKE_SECONDS = 900
DEFAULT_QUESTION_ESCALATE_SECONDS = 3600
# A question is answered when the file carries an answer line, when the helm spoke into
# the worker's pane after it was filed, or when the worker moved on (a new status line).
_ANSWER_LINE = re.compile(r"^\s*(?:#+\s*answer|answer(?:ed)?\s*[:\u2014-])", re.IGNORECASE)
WAITING_PREFIXES = ("needs-decision:", "blocked:", "paused:")


def _positive_int(value: str | None, default: int) -> int:
    try:
        number = int(str(value))
    except (TypeError, ValueError):
        return default
    return number if number > 0 else default


@dataclass(frozen=True)
class ArmPaths:
    """The arm's record, once resolved — nothing here is guessed twice."""

    state: Path
    root: Path
    unit: str
    stale_seconds: int
    poll_seconds: int
    grace_seconds: int
    errand_horizon_seconds: int = DEFAULT_ERRAND_HORIZON_SECONDS
    errand_stall_seconds: int = DEFAULT_ERRAND_STALL_SECONDS
    question_wake_seconds: int = DEFAULT_QUESTION_WAKE_SECONDS
    question_escalate_seconds: int = DEFAULT_QUESTION_ESCALATE_SECONDS

    @property
    def questions(self) -> Path:
        return self.state / "eindri-questions"

    @property
    def reports(self) -> Path:
        return self.state / "eindri-reports"

    @property
    def message_log(self) -> Path:
        return self.state / "fleet" / "messages.jsonl"

    @property
    def errand_woke(self) -> Path:
        return self.state / ".arm.errand-woke"

    @property
    def lease(self) -> Path:
        return self.state / ".arm.lease"

    @property
    def role(self) -> Path:
        return self.state / ".arm.role"

    @property
    def event(self) -> Path:
        return self.state / ".arm.event"

    @property
    def wake(self) -> Path:
        return self.state / ".arm.wake"

    @property
    def heartbeat(self) -> Path:
        return self.state / ".watch.heartbeat"

    @property
    def armed(self) -> Path:
        return self.state / ".supervision-armed"

    @property
    def generation(self) -> Path:
        return self.state / ".arm.gen"

    @property
    def wake_queue(self) -> Path:
        return self.state / ".wake-queue"

    @property
    def wake_hash(self) -> Path:
        return self.state / ".wake-last-hash"

    @property
    def raise_state(self) -> Path:
        return self.state / ".arm.raise"

    @property
    def stop_marker(self) -> Path:
        return self.state / ".watcher-stop"

    def triggers(self, suffix: str) -> list[Path]:
        """The one-shot raise triggers (`*.signal`, `*.check`), name-ordered."""
        try:
            return sorted(
                (entry for entry in self.state.iterdir() if entry.name.endswith(suffix)),
                key=lambda entry: entry.name,
            )
        except OSError:
            return []


def arm_paths(
    env: Mapping[str, str] | None = None,
    *,
    unit: str = "",
    stale_seconds: int = 0,
    poll_seconds: int = 0,
    grace_seconds: int = 0,
) -> ArmPaths:
    """Resolve every path and threshold the arm uses, from the home law."""
    environ = dict(os.environ) if env is None else dict(env)
    roots = paths_mod.resolve(environ)
    return ArmPaths(
        state=roots.state,
        root=roots.root,
        unit=unit or environ.get("SYN_WATCH_UNIT", "") or DEFAULT_UNIT,
        stale_seconds=stale_seconds
        or _positive_int(environ.get("BROKK_WATCH_HEARTBEAT_STALE_SECONDS"), DEFAULT_HEARTBEAT_STALE_SECONDS),
        poll_seconds=poll_seconds
        or _positive_int(environ.get("BROKK_WATCH_POLL_SECONDS"), DEFAULT_POLL_SECONDS),
        grace_seconds=grace_seconds
        or _positive_int(environ.get("BROKK_WATCH_DAEMON_GRACE_SECONDS"), DEFAULT_DAEMON_GRACE_SECONDS),
        errand_horizon_seconds=_positive_int(
            environ.get("BROKK_WATCH_ERRAND_HORIZON_SECONDS"), DEFAULT_ERRAND_HORIZON_SECONDS
        ),
        errand_stall_seconds=_positive_int(
            environ.get("BROKK_WATCH_ERRAND_STALL_SECONDS"), DEFAULT_ERRAND_STALL_SECONDS
        ),
        question_wake_seconds=_positive_int(
            environ.get("BROKK_WATCH_QUESTION_WAKE_SECONDS"), DEFAULT_QUESTION_WAKE_SECONDS
        ),
        question_escalate_seconds=_positive_int(
            environ.get("BROKK_WATCH_QUESTION_ESCALATE_SECONDS"), DEFAULT_QUESTION_ESCALATE_SECONDS
        ),
    )


def say_err(message: str) -> None:
    """The arm's one voice on stderr — `syn-watch: <what>`."""
    print(f"syn-watch: {message}", file=sys.stderr)


# ── the lease ───────────────────────────────────────────────────────────────


def read_lease(path: Path) -> dict[str, str]:
    """The lease as a mapping. Last value wins, as the shell's awk reads it."""
    values: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return values
    for token in text.split():
        key, separator, value = token.partition("=")
        if separator:
            values[key] = value
    return values


def _session_comm(pid: str) -> str:
    """The harness comm of a session pid, or "" — /proc/<pid>/comm is the truth; where there is no /proc
    (macOS), ps answers, the same fallback the lock module's _comm uses."""
    try:
        return Path(f"/proc/{pid}/comm").read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return lock_mod._comm(pid).rsplit("/", 1)[-1] if str(pid).isdigit() else ""


def _sidecar_role(path: Path, session: str) -> str:
    """The declared role from the arm client's sidecar, only for THIS session."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return ""
    fields = dict(token.partition("=")[::2] for token in text.split() if "=" in token)
    if fields.get("session") == session:
        return fields.get("role", "")
    return ""


def resolve_role(
    paths: ArmPaths,
    env: Mapping[str, str],
    *,
    session: str = "",
) -> str:
    """The lease's `role=` — the holder's declared duty set, never guessed.

    Order: `BROKK_ARM_ROLE` (the daemon's own env, inline mode) → the arm
    client's sidecar (the service path) → the session's harness comm. No holder,
    no declaration and no readable harness is `unknown`.
    """
    if not session or session == "none" or not session.isdigit():
        return "unknown"
    declared = (env.get("BROKK_ARM_ROLE") or "").strip()
    if not declared:
        declared = _sidecar_role(paths.role, session)
    if declared:
        return declared
    comm = _session_comm(session)
    if comm in ROLE_BY_COMM:
        return ROLE_BY_COMM[comm]
    if comm in lock_mod.HARNESS_COMMS:
        return comm
    return "unknown"


def write_lease(
    paths: ArmPaths,
    *,
    pid: int,
    mode: str,
    session: str,
    generation: int,
    role: str = "unknown",
    helm: identity_mod.Helm | None = None,
    now: float | None = None,
    stat_reader: Callable[[int], str] | None = None,
    pin: str = "",
    pin_behind: str = "",
) -> bool:
    """Write the lease atomically; a torn lease is a lying one.

    The identity fields (plan 254 B1b/B1c, plan 257 H8) are written HERE, at take,
    from the identity the caller resolved — so a reader never has to infer whose hand
    holds the helm, which machine it stands on, or which pinned code it runs.
    """
    starttime = proc.proc_starttime(pid, stat_reader=stat_reader or proc._proc_stat) or "0"
    stamp = int(now if now is not None else time.time())
    identity_fields = f" {helm.lease_tokens()}" if helm is not None else ""
    body = (
        f"pid={pid} starttime={starttime} gen={generation} mode={mode} role={role} "
        f"session={session} heartbeat={stamp} state={paths.state}{identity_fields}"
    )
    # H6/H8 (plan 257): with no resolved helm the pin facts are written alone; a helm carries
    # its own pin= and pin_behind= tokens, so they are never written twice.
    if helm is None:
        if pin:
            body += f" pin={pin}"
        if pin_behind:
            body += f" pin_behind={pin_behind}"
    body += "\n"
    paths.state.mkdir(parents=True, exist_ok=True)
    temporary = paths.lease.with_name(f"{paths.lease.name}.{pid}")
    try:
        temporary.write_text(body, encoding="utf-8")
        temporary.replace(paths.lease)
    except OSError:
        return False
    return True


def pin_facts(env: Mapping[str, str], runner: proc.Runner = proc.run) -> tuple[str, str]:
    """`(sha, behind)` for the pinned runtime, read from git — never guessed.

    The sha is the pin's HEAD; `behind` is the commit count to `origin/main` on the
    LOCAL ref of the pin's own branch (YMIR_RUNTIME_BRANCH, default main). A missing pin or an
    unreadable git returns empty strings — a seat with no pin reports no currency,
    and Eir's `armpin` surface turns that into a named failure, never a lie.
    """
    pin = paths_mod.runtime_pin_dir(env)
    if not str(pin) or not pin.is_dir():
        return "", ""
    sha = ""
    result = runner(("git", "-C", str(pin), "rev-parse", "--short=8", "HEAD"), env=dict(env))
    if proc.ok(result):
        sha = proc.out(result)
    behind = ""
    branch = paths_mod.runtime_pin_branch(env)
    result = runner(
        ("git", "-C", str(pin), "rev-list", "--count", f"HEAD..origin/{branch}"), env=dict(env)
    )
    if proc.ok(result):
        behind = proc.out(result)
    return sha, behind


def release_lease(paths: ArmPaths, *, pid: int | None = None) -> None:
    """Drop the lease only when this process holds it — never another's."""
    mine = str(pid if pid is not None else os.getpid())
    if read_lease(paths.lease).get("pid", "") == mine:
        paths.lease.unlink(missing_ok=True)


def lease_alive(
    paths: ArmPaths,
    *,
    stat_reader: Callable[[int], str] | None = None,
    signal_zero: Callable[[int], None] | None = None,
) -> bool:
    """Is a live arm holding THIS state? — the shell's `lease_alive` twin."""
    lease = read_lease(paths.lease)
    pid = lease.get("pid", "")
    if not pid.isdigit():
        return False
    if lease.get("state", "") != str(paths.state):
        return False
    return proc.pid_alive(
        pid,
        lease.get("starttime", ""),
        stat_reader=stat_reader or proc._proc_stat,
        signal_zero=signal_zero,
    )


def next_generation(paths: ArmPaths) -> int:
    """Advance and record the recovery generation."""
    current = 0
    try:
        raw = paths.generation.read_text(encoding="utf-8").strip()
    except OSError:
        raw = ""
    if raw.isdigit():
        current = int(raw)
    generation = current + 1
    try:
        paths.generation.write_text(f"{generation}\n", encoding="utf-8")
    except OSError:
        pass
    return generation


# ── the heartbeat ───────────────────────────────────────────────────────────


def heartbeat_touch(paths: ArmPaths, *, now: float | None = None) -> None:
    stamp = int(now if now is not None else time.time())
    try:
        paths.heartbeat.write_text(f"{stamp}\n", encoding="utf-8")
    except OSError:
        pass


def heartbeat_age(paths: ArmPaths, *, now: float | None = None) -> int:
    """Seconds since the beat, or -1 when there is no readable beat."""
    try:
        raw = paths.heartbeat.read_text(encoding="utf-8").strip()
    except OSError:
        return -1
    if not raw.isdigit():
        return -1
    moment = now if now is not None else time.time()
    return int(moment) - int(raw)


# ── the session helm ────────────────────────────────────────────────────────


def session_owner(
    paths: ArmPaths,
    *,
    env: Mapping[str, str],
    runner: proc.Runner = proc.run,
    stat_reader: Callable[[int], str] | None = None,
) -> str:
    """The live session that holds this home's helm, or `none`.

    The lock law is Gleipnir's (`bin/vault/gleipnir-lock-lib.sh`): the machine-global
    lock for the primary, the per-home lock for an Eindri-home, the legacy path
    honoured for a session that started before the contract. This module does not
    re-derive it — it asks the library, exactly as the bash arm did.
    """
    library = paths.root / "bin" / "vault" / "gleipnir-lock-lib.sh"
    if not library.is_file():
        return "none"
    script = "\n".join(
        [
            f'. "{library}" 2>/dev/null || exit 1',
            "gleipnir_lock_owner _ymir_owner 2>/dev/null || true",
            # Fallback: the owner reader can answer empty when the lock exists but
            # its starttime sidecar is missing (a stale or hand-written lock). The
            # pid in the lock file is still the truth; the caller checks liveness.
            'if [ -z "${_ymir_owner:-}" ]; then gleipnir_lock_path _p 2>/dev/null || true; [ -n "${_p:-}" ] && [ -r "$_p" ] && _ymir_owner="$(cat "$_p" 2>/dev/null)"; fi',
            'printf "%s" "${_ymir_owner:-}"',
            "",
        ]
    )
    result = runner(["bash", "-c", script], env=dict(env))
    owner = (result.stdout or "").strip()
    if not owner.isdigit():
        return "none"
    return owner if proc.pid_alive(owner, stat_reader=stat_reader or proc._proc_stat) else "none"


# ── the raise ───────────────────────────────────────────────────────────────


def raise_line(paths: ArmPaths, *, runner: proc.Runner = proc.run, now: float | None = None) -> str:
    """The ONE actionable line the arm owes, or "" when nothing is due.

    Order is the contract the harvest calls rely on: the durable wake queue
    first (one signal per DISTINCT content — an unconsumed queue must never
    re-inject on every poll), then the errands the house dispatched (a dead pane,
    a false done, a stalled worker), then a terminal status line, then the
    one-shot triggers, then the operator's stop request.
    """
    try:
        payload = paths.wake_queue.read_bytes()
    except OSError:
        payload = b""
    if payload:
        digest = hashlib.md5(payload).hexdigest()  # noqa: S324 - a dedup key, not a security control
        previous = ""
        try:
            previous = paths.wake_hash.read_text(encoding="utf-8")
        except OSError:
            previous = ""
        if previous != digest:
            try:
                paths.wake_hash.write_text(digest, encoding="utf-8")
            except OSError:
                pass
            return "signal: wake queue"
        # An UNCHANGED, unconsumed queue was already raised once: stay silent and
        # KEEP WATCHING. A bare return here made the watcher leave without
        # raising anything, so the harness read the close as "ended without an
        # actionable reason", retried five times, and flapped (2026-09-23).

    # H3 — the record is the wake: a terminal status line newer than its per-id
    # cursor raises exactly one wake, so a worker that writes only `done: …` wakes
    # the arm within one poll with no acclaim and no sweep. The queue above keeps
    # first call; this is the direct road a finished worker travels by default.
    # The errands come BEFORE the terminal line, so a false `done:` reaches the helm as
    # a `check:` ahead of the `signal:` that would otherwise read as a finished job.
    errand = errand_wake(paths, runner=runner, now=now)
    if errand:
        return errand

    asked = question_wake(paths, runner=runner, now=now)
    if asked:
        return asked

    terminal = terminal_status_wake(paths)
    if terminal:
        return terminal

    for suffix, prefix in ((".signal", "signal"), (".check", "check")):
        found = paths.triggers(suffix)
        if found:
            trigger = found[0]
            try:
                trigger.unlink()
            except OSError:
                pass
            return f"{prefix}: {trigger.name[: -len(suffix)]}"

    if paths.stop_marker.exists():
        try:
            paths.stop_marker.unlink()
        except OSError:
            pass
        return "stale: watcher stopped by operator"

    return ""


def _cursor(path: Path) -> float:
    try:
        return float(path.read_text(encoding="utf-8", errors="replace").strip() or 0)
    except (OSError, ValueError):
        return 0.0


def _terminal_epoch(paths: ArmPaths) -> float:
    """When this house first read terminal lines as wakes (`.arm.terminal-epoch`).

    A status that turned terminal BEFORE the record-as-wake existed was already carried
    by acclaim or the sweep, so it is seeded silently rather than re-presented: the
    first poll after an upgrade must not raise a hundred old `done:` lines (plan 257,
    risk "a derived wake firing on an old terminal line").
    """
    marker = paths.state / ".arm.terminal-epoch"
    value = _cursor(marker)
    if value > 0:
        return value
    stamp = time.time()
    try:
        marker.write_text(f"{stamp}\n", encoding="utf-8")
    except OSError:
        pass
    return stamp


def terminal_status_wake(paths: ArmPaths) -> str:
    """One `signal:` per terminal status line, keyed by the per-id `.woke` cursor.

    Plan 257 H3 — the record is the wake. A `state/<id>.status` whose last line is
    terminal (`done:` · `failed:` · `needs-decision:` · `paused:`) and whose mtime is
    newer than `state/<id>.woke` raises exactly one wake. The cursor is written BEFORE
    the line is returned, so a second poll never re-wakes the same line; a newer
    terminal line (a later mtime) is news once more. `eindri-acclaim.sh` writes the same
    cursor when it delivers the loud wake, so the two roads never wake twice.
    """
    try:
        entries = sorted(
            (entry for entry in paths.state.iterdir() if entry.name.endswith(".status")),
            key=lambda entry: entry.name,
        )
    except OSError:
        return ""
    # Stamped EAGERLY, on the first scan (2026-11-20). Stamped lazily — when the first
    # terminal line was met — the epoch was always a moment AFTER that line, so the
    # first `done:` a fresh home ever wrote was seeded in silence, never raised.
    epoch = _terminal_epoch(paths)
    for status in entries:
        seat_id = status.name[: -len(".status")]
        if not seat_id or seat_id.startswith("."):
            continue
        try:
            status_mtime = status.stat().st_mtime
        except OSError:
            continue
        cursor = paths.state / f"{seat_id}.woke"
        cursor_value = _cursor(cursor)
        if status_mtime <= cursor_value:
            continue  # the cheap test first: nothing new since the last wake
        try:
            lines = status.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        last = lines[-1].strip() if lines else ""
        if not last.lower().startswith(TERMINAL_WAKE_PREFIXES):
            continue
        if cursor_value <= 0:
            if status_mtime < epoch:
                # older than the record-as-wake itself: seed, never raise
                try:
                    cursor.write_text(f"{status_mtime}\n", encoding="utf-8")
                except OSError:
                    pass
                continue
        try:
            cursor.write_text(f"{status_mtime}\n", encoding="utf-8")
        except OSError:
            continue  # a cursor that cannot be written would re-wake every poll
        return f"signal: {seat_id} {last}"
    return ""


# ── the errands: dead, falsely done, stalled ────────────────────────────────


def _read_kv(path: Path) -> dict[str, str]:
    """A `key=value` record (the seat meta); last value wins, as the shell readers do."""
    values: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return values
    for raw in text.splitlines():
        key, sep, value = raw.partition("=")
        if sep:
            values[key.strip()] = value.strip()
    return values


def _mtime(path: Path) -> float:
    try:
        return path.stat().st_mtime
    except OSError:
        return 0.0


def _short(line: str, limit: int = 160) -> str:
    line = " ".join(line.split())
    return line if len(line) <= limit else line[: limit - 1] + "…"


def herdr_agents(runner: proc.Runner = proc.run) -> dict[str, str] | None:
    """pane id → agent state, from `herdr agent list`; None when herdr cannot answer.

    None is not "no agents": a door that did not answer proves nothing, so no
    worker is ever called dead on a silent herdr.
    """
    done = runner(["herdr", "agent", "list"], timeout=10)
    if done.returncode != 0 or not (done.stdout or "").strip():
        return None
    try:
        data = json.loads(done.stdout)
    except ValueError:
        return None
    result = data.get("result", data) if isinstance(data, dict) else {}
    agents = result.get("agents") if isinstance(result, dict) else None
    if not isinstance(agents, list):
        return None
    panes: dict[str, str] = {}
    for agent in agents:
        if isinstance(agent, dict) and agent.get("pane_id"):
            panes[str(agent["pane_id"])] = str(agent.get("agent_status") or "unknown")
    return panes


def _git(runner: proc.Runner, repo: str, *args: str) -> tuple[int, str]:
    done = runner(["git", "-C", repo, *args], timeout=15)
    return done.returncode, (done.stdout or "").strip()


def _count(runner: proc.Runner, repo: str, span: str) -> int | None:
    rc, text = _git(runner, repo, "rev-list", "--count", span)
    return int(text) if rc == 0 and text.isdigit() else None


def parse_record(text: str) -> dict[str, str]:
    """The record a report carries (plan 339.2): commit · branch · repo · machine · where.

    The terminal act writes a `## Record` block of `key: value` lines; a hand-written
    report that only pastes `git log --oneline -1` still yields its sha. `nothing` is set
    when the report says, in words, that nothing was committed and names no commit.
    """
    record: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip().strip("`").lstrip("-*> ").strip()
        key, sep, value = line.partition(":")
        if not sep:
            continue
        key = key.strip().strip("*`").lower()
        value = value.strip().strip("`").strip()
        if key in ("commit", "branch", "repo", "machine", "where") and value and key not in record:
            record[key] = value
    commit = record.get("commit", "")
    found = _SHA.search(commit) if commit else None
    if not found:
        for raw in text.splitlines():
            found = _ONELINE.match(raw)
            if found:
                break
    if found:
        record["sha"] = found.group(1)
    where = record.get("where", "").lower()
    if "park" in where:
        record["where"] = "parked"
    elif "push" in where and "not" not in where:
        record["where"] = "pushed"
    elif where:
        record["where"] = "local"
    if "sha" not in record and "nothing committed" in text.lower():
        record["nothing"] = "1"
    return record


def _this_machine() -> str:
    return socket.gethostname().split(".")[0].lower()


def _base_ref(git: Callable[..., tuple[int, str]]) -> str:
    rc, text = git("symbolic-ref", "-q", "--short", "refs/remotes/origin/HEAD")
    if rc == 0 and text:
        return text
    for candidate in ("origin/main", "origin/master"):
        if git("rev-parse", "--verify", "-q", f"refs/remotes/{candidate}")[0] == 0:
            return candidate
    return ""


def verify_record(
    seat_id: str,
    meta: Mapping[str, str],
    record: Mapping[str, str],
    runner: proc.Runner = proc.run,
    *,
    here: str | None = None,
) -> str | None:
    """Does git bear out the claim? "" (it does), a fault phrase, or None (cannot judge).

    The sha must exist in the named repo, on the named machine; it must be on the named
    branch and not already the base's; and where the record says `pushed` (or `parked`),
    origin must hold it under `refs/heads/<branch>` (or `refs/parked/<id>`). A machine
    other than this one is asked over ssh; a machine that does not answer proves nothing.
    """
    sha = record.get("sha", "")
    if not sha:
        return None
    local_host = (here or _this_machine()).lower()
    machine = record.get("machine", "").strip()
    short = machine.split(".")[0].lower()
    remote = bool(machine) and short not in (local_host, "localhost", "this", "this-machine", "local")
    repo = record.get("repo", "").strip()
    if not remote and not (repo and os.path.isdir(repo)):
        worktree, project = meta.get("worktree", ""), meta.get("project", "")
        repo = worktree if worktree and os.path.isdir(worktree) else project if project and os.path.isdir(project) else ""
    if not repo:
        return None
    where_text = f"{repo} on {machine}" if remote else repo

    unreachable = False

    def git(*args: str) -> tuple[int, str]:
        nonlocal unreachable
        if remote:
            done = runner(
                ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", machine, "git", "-C", repo, *args],
                timeout=25,
            )
            if done.returncode == 255:
                unreachable = True
            return done.returncode, (done.stdout or "").strip()
        return _git(runner, repo, *args)

    if git("cat-file", "-e", f"{sha}^{{commit}}")[0] != 0:
        if unreachable:
            return None
        return f"commit {sha}, which {where_text} does not hold"
    branch = record.get("branch", "").strip() or f"eindri/{seat_id}"
    ref = ""
    for candidate in (f"refs/heads/{branch}", f"refs/remotes/origin/{branch}"):
        if git("rev-parse", "--verify", "-q", candidate)[0] == 0:
            ref = candidate
            break
    if not ref:
        return f"commit {sha} on {branch}, a branch {where_text} does not have"
    if git("merge-base", "--is-ancestor", sha, ref)[0] != 0:
        return f"commit {sha}, which is not on {branch}"
    base = _base_ref(git)
    if base and git("merge-base", "--is-ancestor", sha, base)[0] == 0:
        return f"nothing committed (commit {sha} is already on {base})"
    where = record.get("where", "")
    if where in ("pushed", "parked"):
        remote_ref = f"refs/heads/{branch}" if where == "pushed" else f"refs/parked/{seat_id}"
        rc, text = git("ls-remote", "origin", remote_ref)
        if rc != 0:
            return None  # origin did not answer: no verdict on silence
        tip = text.split()[0] if text.split() else ""
        if not tip:
            return f"a claim of {where}, but origin holds no {remote_ref}"
        if not tip.startswith(sha) and git("merge-base", "--is-ancestor", sha, tip)[0] != 0:
            return f"a claim of {where}, but origin's {remote_ref} is at {tip[:9]}, not {sha}"
    elif where == "local" and meta.get("mode", "") in PUSHING_MODES:
        return "no branch pushed (the record says local only)"
    return ""


def done_verdict(
    seat_id: str,
    meta: Mapping[str, str],
    runner: proc.Runner = proc.run,
    *,
    report: str = "",
    here: str | None = None,
) -> str | None:
    """What a `done:` stands on: "" (a record), a fault phrase, or None (cannot judge).

    With a report whose record names a commit, the claim itself is verified
    (`verify_record`). Without one, the branch is `eindri/<id>`, else the worktree's own
    branch: it must carry at least one commit ahead of the remote's default branch, and —
    unless the errand was briefed `mode=batch`, whose contract is commit-and-never-push —
    that branch must be on the remote with nothing left unpushed. A report is not a record.
    """
    record = parse_record(report) if report else {}
    if record.get("sha"):
        return verify_record(seat_id, meta, record, runner, here=here)
    mode = meta.get("mode", "")
    worktree = meta.get("worktree", "")
    project = meta.get("project", "")
    repo = worktree if worktree and os.path.isdir(worktree) else project if project and os.path.isdir(project) else ""
    if not repo:
        return None
    base = _base_ref(lambda *a: _git(runner, repo, *a))
    if not base:
        return None
    branch = f"eindri/{seat_id}"
    if _git(runner, repo, "rev-parse", "--verify", "-q", f"refs/heads/{branch}")[0] != 0:
        branch = ""
        if worktree and os.path.isdir(worktree):
            rc, text = _git(runner, worktree, "branch", "--show-current")
            branch = text if rc == 0 else ""
        if not branch:
            return "" if mode in NO_COMMIT_MODES or record.get("nothing") else "nothing committed"
    ahead = _count(runner, repo, f"{base}..{branch}")
    if ahead is None:
        return None
    if ahead == 0:
        # Honest when the report says so, or when the errand owed a report, not a commit.
        return "" if mode in NO_COMMIT_MODES or record.get("nothing") else "nothing committed"
    if mode == "batch":
        return ""
    if _git(runner, repo, "rev-parse", "--verify", "-q", f"refs/remotes/origin/{branch}")[0] != 0:
        return "no branch pushed"
    unpushed = _count(runner, repo, f"origin/{branch}..{branch}")
    if unpushed:
        return f"{unpushed} commit(s) not pushed"
    return ""


def mark_false_done(paths: ArmPaths, seat_id: str, verdict: str) -> None:
    """Turn the errand's status to `false-done:` — the claim stands corrected on its own shelf."""
    stamp = time.strftime("%Y-%m-%d %H:%M %Z")
    try:
        with (paths.state / f"{seat_id}.status").open("a", encoding="utf-8") as handle:
            handle.write(f"{FALSE_DONE_PREFIX} {stamp} — the arm checked the record: reported done with {verdict}\n")
    except OSError:
        pass


def _errand_epoch(paths: ArmPaths) -> float:
    """When this house first judged `done:` lines against git (`.arm.errand-epoch`).

    A `done:` older than the check was carried by the old roads, and its branch may
    since have been gathered and merged (and so read as empty); it is never judged.
    """
    marker = paths.state / ".arm.errand-epoch"
    value = _cursor(marker)
    if value > 0:
        return value
    stamp = time.time()
    try:
        marker.write_text(f"{stamp}\n", encoding="utf-8")
    except OSError:
        pass
    return stamp


def errand_wake(paths: ArmPaths, *, runner: proc.Runner = proc.run, now: float | None = None) -> str:
    """One `stale:`/`check:` line about a dispatched errand, or "" when all is well.

    For every `state/<id>.meta` touched inside the horizon:

      · DEAD     — the meta names a pane, herdr shows no agent in it, and the status
                   has not ended: `stale: errand <id> has no agent in <pane> (status: …)`
      · FALSE DONE — the status says `done:` and git shows nothing committed (or, off
                   the batch road, nothing pushed): `check: errand <id> reported done with …`
      · STALLED  — the status says `working:`, neither record has moved for the stall
                   window, and the pane's agent sits idle:
                   `stale: errand <id> has said nothing for <n> minutes`

    Each finding is keyed by (errand, kind) in `.arm.errand-woke` with the fact it saw,
    written BEFORE the line is returned, so the same fact never wakes twice and a new
    fact (a new status line, another pane) is news once more.
    """
    moment = time.time() if now is None else now
    try:
        metas = sorted(
            (entry for entry in paths.state.iterdir() if entry.name.endswith(".meta")),
            key=lambda entry: entry.name,
        )
    except OSError:
        return ""
    try:
        woke = json.loads(paths.errand_woke.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        woke = {}
    if not isinstance(woke, dict):
        woke = {}

    agents: dict[str, str] | None = None
    asked = False
    epoch = _errand_epoch(paths)  # eager, for the reason `terminal_status_wake` gives

    def mark(key: str, fact: str) -> bool:
        woke[key] = fact
        try:
            temporary = paths.errand_woke.with_name(f"{paths.errand_woke.name}.tmp.{os.getpid()}")
            temporary.write_text(json.dumps(woke, sort_keys=True), encoding="utf-8")
            temporary.replace(paths.errand_woke)
        except OSError:
            return False  # a ledger that cannot be written would re-wake every poll
        return True

    for meta_file in metas:
        seat_id = meta_file.name[: -len(".meta")]
        if not seat_id or seat_id.startswith("."):
            continue
        status = paths.state / f"{seat_id}.status"
        status_mtime = _mtime(status)
        meta_mtime = _mtime(meta_file)
        if not status_mtime:
            continue
        if moment - max(status_mtime, meta_mtime) > paths.errand_horizon_seconds:
            continue  # an old record is the ledger's business, not the arm's
        try:
            lines = status.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue
        last = next((line.strip() for line in reversed(lines) if line.strip()), "")
        if not last:
            continue
        head = last.lower()
        meta = _read_kv(meta_file)

        if head.startswith("done:"):
            if status_mtime < epoch:
                continue
            key, fact = f"{seat_id}|done", f"{int(status_mtime)}|{last}"
            if woke.get(key) == fact:
                continue
            try:
                report = (paths.reports / f"{seat_id}.md").read_text(encoding="utf-8", errors="replace")
            except OSError:
                report = ""
            verdict = done_verdict(seat_id, meta, runner, report=report)
            if not mark(key, fact) or not verdict:
                continue  # judged once: a record, or a repo the arm cannot read
            mark_false_done(paths, seat_id, verdict)
            return f"check: errand {seat_id} false-done — reported done with {verdict}"

        if head.startswith(ERRAND_ENDED_PREFIXES):
            continue
        pane = meta.get("seat_pane", "") or (meta.get("window", "") if meta.get("backend", "") == "herdr" else "")
        if not pane:
            continue
        if not asked:
            agents, asked = herdr_agents(runner), True
        if agents is None:
            continue  # herdr did not answer: no worker is judged dead or idle on silence
        if pane not in agents:
            key, fact = f"{seat_id}|dead", f"{pane}|{last}"
            if woke.get(key) == fact or not mark(key, fact):
                continue
            return f"stale: errand {seat_id} has no agent in {pane} (status: {_short(last)})"
        if head.startswith("working:") and agents.get(pane, "") in IDLE_AGENT_STATES:
            quiet = moment - max(status_mtime, meta_mtime)
            if quiet <= paths.errand_stall_seconds:
                continue
            key, fact = f"{seat_id}|stall", f"{int(status_mtime)}|{int(meta_mtime)}"
            if woke.get(key) == fact or not mark(key, fact):
                continue
            return f"stale: errand {seat_id} has said nothing for {int(quiet // 60)} minutes"
    return ""


# ── the fourth eye: the unanswered question ─────────────────────────────────


def _spoken_to_since(paths: ArmPaths, targets: set[str], since: float) -> bool:
    """Did anyone speak into one of `targets` after `since`? (the fleet message log)

    `bin/agents/eindri-send.sh` records every send in `fleet/messages.jsonl`; a line to the
    worker's pane after its question was filed is the helm's answer. Only the tail is read.
    """
    if not targets:
        return False
    try:
        with paths.message_log.open("rb") as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            handle.seek(max(0, size - 512 * 1024))
            tail = handle.read().decode("utf-8", errors="replace")
    except OSError:
        return False
    for raw in reversed(tail.splitlines()):
        try:
            row = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(row, dict):
            continue
        try:
            epoch = float(row.get("epoch") or 0)
        except (TypeError, ValueError):
            continue
        if epoch < since:
            break  # the log is appended in time order: nothing older can answer
        if str(row.get("to", "")) in targets or str(row.get("pane", "")) in targets:
            return True
    return False


def question_answered(paths: ArmPaths, seat_id: str, question: Path, asked_at: float) -> bool:
    """True when the question has an answer: in the file, in the pane, or in the worker's moving on."""
    try:
        text = question.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return True  # gone: moved to answered/ or withdrawn
    if any(_ANSWER_LINE.match(line) for line in text.splitlines()):
        return True
    meta = _read_kv(paths.state / f"{seat_id}.meta")
    targets = {seat_id}
    for key in ("seat_pane", "window", "pane"):
        if meta.get(key):
            targets.add(meta[key])
    if _spoken_to_since(paths, targets, asked_at):
        return True
    status = paths.state / f"{seat_id}.status"
    if _mtime(status) > asked_at + 5:
        try:
            lines = status.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            lines = []
        last = next((line.strip().lower() for line in reversed(lines) if line.strip()), "")
        if last and not last.startswith(WAITING_PREFIXES):
            return True  # the worker wrote on after the question: it is no longer waiting
    return False


def _first_line(path: Path) -> str:
    try:
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.strip().lstrip("#").strip()
            if line:
                return _short(line, 120)
    except OSError:
        pass
    return ""


def escalate_question(
    paths: ArmPaths, seat_id: str, question: Path, minutes: int, *, runner: proc.Runner = proc.run
) -> bool:
    """One line to the operator through the hotline, with the buttons that act on it."""
    door = paths.root / "bin" / "notify" / "send.sh"
    if not os.access(door, os.X_OK):
        return False
    gist = _first_line(question)
    message = f"Worker {seat_id} has waited {minutes} minutes for an answer: {gist}" if gist else (
        f"Worker {seat_id} has waited {minutes} minutes for an answer"
    )
    answer = f"bin/agents/eindri-answer.sh {seat_id} \"<the answer>\""
    done = runner(
        [
            str(door),
            "--source", "errand",
            "--severity", "HIGH",
            "--message", message,
            "--key", f"question:{seat_id}:{int(_mtime(question))}",
            "--target", f"file:{question}",
            "--button", f"✍️ Answer worker {seat_id}|Read {question} and answer it with {answer}",
            "--button", f"📄 Show the question from {seat_id}|Show me the text of {question}",
        ],
        timeout=60,
    )
    return done.returncode == 0


def question_wake(paths: ArmPaths, *, runner: proc.Runner = proc.run, now: float | None = None) -> str:
    """One `check:` line about a question an errand filed and nobody answered, or "".

    `eindri-questions/<id>.md` unanswered past the wake window (15 min) wakes the helm once;
    past the escalation window (1 h) it reaches the operator once, as one line with buttons,
    and the helm is told it went. Each step is keyed by (errand, step, the file's time) in
    `.arm.errand-woke`, so a new question from the same errand is news again, and an answer
    (`question_answered`) ends both steps before they fire.
    """
    moment = time.time() if now is None else now
    try:
        questions = sorted(entry for entry in paths.questions.iterdir() if entry.is_file() and entry.suffix == ".md")
    except OSError:
        return ""
    try:
        woke = json.loads(paths.errand_woke.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        woke = {}
    if not isinstance(woke, dict):
        woke = {}

    def mark(key: str, fact: str) -> bool:
        woke[key] = fact
        try:
            temporary = paths.errand_woke.with_name(f"{paths.errand_woke.name}.tmp.{os.getpid()}")
            temporary.write_text(json.dumps(woke, sort_keys=True), encoding="utf-8")
            temporary.replace(paths.errand_woke)
        except OSError:
            return False
        return True

    for question in questions:
        seat_id = question.stem
        if not seat_id or seat_id.startswith("."):
            continue
        asked_at = _mtime(question)
        age = moment - asked_at
        if not asked_at or age > paths.errand_horizon_seconds or age <= paths.question_wake_seconds:
            continue
        fact = str(int(asked_at))
        escalate = age > paths.question_escalate_seconds
        if woke.get(f"{seat_id}|ask") == fact and (not escalate or woke.get(f"{seat_id}|ask-operator") == fact):
            continue  # every step this question is owed has been taken
        if question_answered(paths, seat_id, question, asked_at):
            continue
        minutes = int(age // 60)
        if woke.get(f"{seat_id}|ask") != fact:
            if not mark(f"{seat_id}|ask", fact):
                continue
            gist = _first_line(question)
            tail = f": {gist}" if gist else ""
            return f"check: errand {seat_id} question unanswered for {minutes} minutes ({question}){tail}"
        if not mark(f"{seat_id}|ask-operator", fact):
            continue
        sent = escalate_question(paths, seat_id, question, minutes, runner=runner)
        road = "sent to the operator" if sent else "the hotline did not take it — tell the operator yourself"
        return f"check: errand {seat_id} question unanswered for {minutes} minutes — {road}"
    return ""


def read_raise_state(paths: ArmPaths) -> dict:
    """The cadence record: what was raised, when, and how many this hour."""
    try:
        data = json.loads(paths.raise_state.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        data = {}
    return data if isinstance(data, dict) else {}


def write_raise_state(paths: ArmPaths, state: Mapping) -> None:
    try:
        temporary = paths.raise_state.with_name(f"{paths.raise_state.name}.tmp.{os.getpid()}")
        temporary.write_text(json.dumps(dict(state), sort_keys=True), encoding="utf-8")
        temporary.replace(paths.raise_state)
    except OSError:
        pass


def brake_line(paths: ArmPaths, line: str, *, now: float | None = None) -> str:
    """The cadence law: the line to raise, or "" when the house is owed silence.

    The queue signal is never braked here — its content hash already makes it one
    line per DISTINCT content, and two different queues may share the same words.
    """
    if not line.startswith(BRAKED_PREFIXES) or line.startswith(ERRAND_PREFIXES):
        # the errand lines are deduped per (errand, kind, fact) at their source
        return line
    moment = time.time() if now is None else now
    hour = int(moment // 3600)
    state = read_raise_state(paths)
    count = state.get("count", 0)
    count = int(count) if str(count).isdigit() else 0
    if state.get("hour") != hour:
        count = 0
    signature = hashlib.md5(line.encode("utf-8")).hexdigest()  # noqa: S324 - a dedup key, not a security control
    try:
        last_at = float(state.get("at", 0))
    except (TypeError, ValueError):
        last_at = 0.0
    if signature == state.get("signature") and moment - last_at < RAISE_FLOOR_SECONDS:
        return ""
    if count >= RAISE_HOURLY_CEILING:
        rate_line = f"check: the arm has raised {count} lines in the last hour"
        rate_signature = hashlib.md5(rate_line.encode("utf-8")).hexdigest()  # noqa: S324
        if state.get("rate_signature") == rate_signature and state.get("rate_hour") == hour:
            return ""
        write_raise_state(
            paths, {**state, "hour": hour, "count": count, "rate_signature": rate_signature, "rate_hour": hour}
        )
        return rate_line
    write_raise_state(paths, {"hour": hour, "count": count + 1, "signature": signature, "at": moment})
    return line


def publish(paths: ArmPaths, line: str) -> None:
    """Fill the delivery slot (an undelivered line is never overwritten) and journal it."""
    if paths.event.exists() and paths.event.stat().st_size > 0:
        return
    try:
        temporary = paths.event.with_name(f"{paths.event.name}.tmp.{os.getpid()}")
        temporary.write_text(line + "\n", encoding="utf-8")
        temporary.replace(paths.event)
    except OSError:
        pass
    try:
        with paths.wake.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")
    except OSError:
        pass


# ── the cycle ───────────────────────────────────────────────────────────────


def cycle(
    paths: ArmPaths,
    *,
    env: Mapping[str, str],
    runner: proc.Runner = proc.run,
    probe=proc.which,
    mode: str = "daemon",
    pid: int | None = None,
    emit: bool = False,
    helm: identity_mod.Helm | None = None,
    now: float | None = None,
    stat_reader: Callable[[int], str] | None = None,
    pin: str = "",
    pin_behind: str = "",
) -> str:
    """One poll cycle: beat, lease, sweep the handoff, raise at most one line.

    In `emit` mode the raised line is journaled and RETURNED (the caller prints
    it and ends the cycle, exactly as the pre-service watch loop did); otherwise
    it is left in the delivery slot for the thin client to carry out.
    """
    mine = pid if pid is not None else os.getpid()
    heartbeat_touch(paths, now=now)
    if not paths.armed.exists():
        try:
            paths.armed.touch()
        except OSError:
            pass
    session = session_owner(paths, env=env, runner=runner, stat_reader=stat_reader)
    role = resolve_role(paths, env, session=session)
    if helm is None:
        helm = identity_mod.resolve(env, runner=runner)
    lease = read_lease(paths.lease)
    generation = int(lease["gen"]) if lease.get("gen", "").isdigit() else 0
    write_lease(
        paths,
        pid=mine,
        mode=mode,
        role=role,
        helm=helm,
        session=session,
        generation=generation,
        now=now,
        stat_reader=stat_reader,
        pin=pin,
        pin_behind=pin_behind,
    )
    sweep_handoff(paths, env=env, runner=runner)
    follow_telegram(paths, session, env=env, runner=runner, now=now)
    if not emit and paths.event.exists() and paths.event.stat().st_size > 0:
        # The slot still holds an undelivered line. Raising now would consume a
        # trigger or mark an errand finding as woken while `publish` drops the line
        # — so the next raise waits for the client to carry the slot out.
        return ""
    line = raise_line(paths, runner=runner, now=now)
    if not line:
        return ""
    line = brake_line(paths, line, now=now)
    if not line:
        return ""
    if emit:
        try:
            with paths.wake.open("a", encoding="utf-8") as handle:
                handle.write(line + "\n")
        except OSError:
            pass
        return line
    publish(paths, line)
    say_err(f"raised: {line}")
    return ""


TELEGRAM_RESYNC_SECONDS = 15
_telegram_synced: dict[str, tuple[str, float]] = {}


def follow_telegram(
    paths: ArmPaths, session: str, *, env: Mapping[str, str], runner: proc.Runner = proc.run, now: float | None = None
) -> None:
    """The machine's Telegram reader follows the arm: at once when the holder changes, then on a slow beat.

    This covers what `rodd-arm.sh hold` cannot see: a helm taken by an arm client, and a stray
    second reader started after the hand-over. The door is a no-op unless the home opts in.
    """
    door = paths.root / "bin" / "notify" / "telegram-reader.sh"
    if session in ("", "none") or not os.access(door, os.X_OK):
        return
    moment = time.time() if now is None else now
    last = _telegram_synced.get(str(paths.state))
    if last and last[0] == session and moment - last[1] < TELEGRAM_RESYNC_SECONDS:
        return
    _telegram_synced[str(paths.state)] = (session, moment)
    child_env = dict(env)
    child_env["BROKK_STATE_OVERRIDE"] = str(paths.state)
    runner([str(door), "sync", "--quiet"], env=child_env)


def sweep_handoff(paths: ArmPaths, *, env: Mapping[str, str], runner: proc.Runner = proc.run) -> None:
    """The mid-session sweep: a filed report becomes a wake within seconds.

    `bin/agents/eindri-handoff.sh` owns the shelf scan and its ledger; this only points
    it at the SAME state dir the arm watches.
    """
    # The door moved to bin/agents/ with the folder split; the old flat path is kept as a
    # fallback for an older pin. Before 2026-11-20 only the flat path was asked, so the
    # mid-session sweep had silently stopped running.
    door = paths.root / "bin" / "agents" / "eindri-handoff.sh"
    if not os.access(door, os.X_OK):
        door = paths.root / "bin" / "eindri-handoff.sh"
    if not os.access(door, os.X_OK):
        return
    child_env = dict(env)
    child_env["BROKK_STATE_OVERRIDE"] = str(paths.state)
    runner([str(door), "sweep"], env=child_env)


# ── status ──────────────────────────────────────────────────────────────────


def have_systemd(runner: proc.Runner = proc.run) -> bool:
    return proc.ok(runner(["systemctl", "--user", "show", "--property=Version"]))


def unit_state(paths: ArmPaths, *, runner: proc.Runner = proc.run) -> str:
    """The unit's ActiveState, `absent` when no such unit, `nosystemd` when none."""
    if not have_systemd(runner):
        return "nosystemd"
    load = proc.out(runner(["systemctl", "--user", "show", "-p", "LoadState", "--value", paths.unit]))
    if load in ("not-found", ""):
        return "absent"
    active = proc.out(runner(["systemctl", "--user", "show", "-p", "ActiveState", "--value", paths.unit]))
    return active or "absent"


def status_state(
    paths: ArmPaths,
    *,
    stat_reader: Callable[[int], str] | None = None,
    signal_zero: Callable[[int], None] | None = None,
    now: float | None = None,
) -> str:
    """up | idle | stale | down — the operator's truth, in that order of proof."""
    if not lease_alive(paths, stat_reader=stat_reader, signal_zero=signal_zero):
        return DOWN
    age = heartbeat_age(paths, now=now)
    if age >= 0 and age > paths.stale_seconds:
        return STALE
    if not paths.armed.exists():
        return STALE
    if read_lease(paths.lease).get("session", "none") == "none":
        return IDLE
    return UP


def status_row(
    paths: ArmPaths,
    *,
    env: Mapping[str, str],
    runner: proc.Runner = proc.run,
    stat_reader: Callable[[int], str] | None = None,
    now: float | None = None,
) -> str:
    """The TOON detail row, field for field as the bash door printed it."""
    state = status_state(paths, stat_reader=stat_reader, now=now)
    alive = lease_alive(paths, stat_reader=stat_reader)
    lease = read_lease(paths.lease)
    if alive:
        mode = lease.get("mode", "unknown")
        role = lease.get("role", "unknown")
        pid = lease.get("pid", "")
        session = lease.get("session", "none")
    else:
        mode = "none"
        role = "unknown"
        pid = ""
        session = session_owner(paths, env=env, runner=runner, stat_reader=stat_reader)
    armed = "yes" if paths.armed.exists() else "no"
    cells = [
        state,
        mode,
        role,
        unit_state(paths, runner=runner),
        pid or "none",
        str(heartbeat_age(paths, now=now)),
        str(paths.stale_seconds),
        session,
        armed,
        str(paths.state),
    ]
    return "  " + ",".join(f'"{cell}"' for cell in cells) + "\n"


def status_lines(
    paths: ArmPaths,
    *,
    env: Mapping[str, str],
    runner: proc.Runner = proc.run,
    stat_reader: Callable[[int], str] | None = None,
    now: float | None = None,
) -> tuple[str, int]:
    """The `status` output and its exit code — a live, idle, or absent arm is rc 0."""
    state = status_state(paths, stat_reader=stat_reader, now=now)
    healthy = state in (UP, IDLE)
    body = (
        "syn-watch[1]{state,mode,role,unit,pid,heartbeat_age,stale_seconds,session,armed,state_dir}:\n"
        + status_row(paths, env=env, runner=runner, stat_reader=stat_reader, now=now)
    )
    return body, 0 if healthy else 1


def status_detail(
    paths: ArmPaths,
    *,
    env: Mapping[str, str],
    runner: proc.Runner = proc.run,
    stat_reader: Callable[[int], str] | None = None,
    now: float | None = None,
) -> tuple[str, int]:
    state = status_state(paths, stat_reader=stat_reader, now=now)
    alive = lease_alive(paths, stat_reader=stat_reader)
    lease = read_lease(paths.lease)
    line = (
        f"arm={state} mode={lease.get('mode', 'unknown') if alive else 'none'} "
        f"role={lease.get('role', 'unknown') if alive else 'unknown'} "
        f"unit={unit_state(paths, runner=runner)} pid={lease.get('pid', 'none') if alive else 'none'} "
        f"heartbeat={heartbeat_age(paths, now=now)}s "
        f"session={session_owner(paths, env=env, runner=runner, stat_reader=stat_reader)}"
    )
    return line + "\n", 0 if state in (UP, IDLE) else 1


# ── starting / stopping ─────────────────────────────────────────────────────


def wait_lease(
    paths: ArmPaths,
    limit: int,
    *,
    sleep: Callable[[float], None] = time.sleep,
    stat_reader: Callable[[int], str] | None = None,
) -> bool:
    """Wait (in half seconds) until a live arm holds OUR state."""
    waited = 0
    while waited < limit:
        if lease_alive(paths, stat_reader=stat_reader):
            return True
        sleep(0.5)
        waited += 1
    return False


def start_detached(
    paths: ArmPaths,
    *,
    env: Mapping[str, str],
    runner: proc.Runner = proc.run,
    spawn: Callable[..., int] = proc.spawn_detached,
) -> None:
    """Seat the arm as a detached daemon — a SERVICE, not a child of this shell.

    This is the shape for a state the one unit does not serve: an Eindri-home's
    private state, or a proof's scratch state.
    """
    paths.state.mkdir(parents=True, exist_ok=True)
    child_env = dict(env)
    child_env["BROKK_STATE_OVERRIDE"] = str(paths.state)
    child_env["SYN_WATCH_MODE"] = "daemon"
    door = paths.root.joinpath(*WATCH_DOOR)
    spawn(
        ["bash", str(door), "run"],
        env=child_env,
        cwd=str(paths.root),
        log_path=str(paths.state / ".arm.log"),
    )
    say_err(f"arm seated as a detached daemon for {paths.state}")


def start_service(
    paths: ArmPaths,
    *,
    env: Mapping[str, str],
    runner: proc.Runner = proc.run,
    sleep: Callable[[float], None] = time.sleep,
    spawn: Callable[..., int] = proc.spawn_detached,
    stat_reader: Callable[[int], str] | None = None,
) -> int:
    """Seat the arm — the machine's ONE unit first, a detached daemon after.

    A state the caller named explicitly is never handed to the unit: one seat's
    state is not the machine's, and two seats would fight over the unit.
    """
    state_given = bool(env.get("BROKK_STATE_OVERRIDE"))
    if have_systemd(runner) and not state_given:
        fleet_ensure = paths.root / "bin" / "fleet-ensure.sh"
        if os.access(fleet_ensure, os.X_OK):
            if not proc.ok(runner([str(fleet_ensure), "unit", "syn-watch"])):
                say_err(f"could not materialize {paths.unit} (bin/fleet/fleet-ensure.sh unit syn-watch)")
        runner(["systemctl", "--user", "daemon-reload"])
        seated = proc.ok(runner(["systemctl", "--user", "enable", "--now", paths.unit]))
        if seated:
            if wait_lease(paths, 6, sleep=sleep, stat_reader=stat_reader):
                return 0
            say_err(f"{paths.unit} is up but took no lease for {paths.state} — seating a detached arm")
        else:
            say_err(f"{paths.unit} could not be started (systemctl --user enable --now {paths.unit})")
    start_detached(paths, env=env, runner=runner, spawn=spawn)
    if not wait_lease(paths, 20, sleep=sleep, stat_reader=stat_reader):
        say_err(f"the arm took no lease for {paths.state} within 10s")
        return 1
    return 0


def stop_service(
    paths: ArmPaths,
    *,
    runner: proc.Runner = proc.run,
    sleep: Callable[[float], None] = time.sleep,
    stat_reader: Callable[[int], str] | None = None,
    signal_zero: Callable[[int], None] | None = None,
) -> int:
    """Bring the arm down, in both shapes, and prove it actually let go."""
    stopped = False
    if have_systemd(runner):
        if proc.ok(runner(["systemctl", "--user", "is-active", "--quiet", paths.unit])):
            if proc.ok(runner(["systemctl", "--user", "stop", paths.unit])):
                stopped = True
    if lease_alive(paths, stat_reader=stat_reader, signal_zero=signal_zero):
        pid = read_lease(paths.lease).get("pid", "")
        if pid.isdigit():
            try:
                os.kill(int(pid), signal.SIGTERM)
            except OSError:
                pass
        stopped = True
    waited = 0
    while waited < 20:
        if not lease_alive(paths, stat_reader=stat_reader, signal_zero=signal_zero):
            break
        sleep(0.5)
        waited += 1
    if lease_alive(paths, stat_reader=stat_reader, signal_zero=signal_zero):
        say_err("the arm still holds its lease after the stop")
        return 1
    if stopped:
        say_err("arm stopped")
    return 0


# ── the daemon ──────────────────────────────────────────────────────────────


def run_daemon(
    paths: ArmPaths,
    *,
    env: Mapping[str, str],
    runner: proc.Runner = proc.run,
    sleep: Callable[[float], None] = time.sleep,
    emit: bool = False,
    stat_reader: Callable[[int], str] | None = None,
    signal_zero: Callable[[int], None] | None = None,
    signal_installer: Callable[[Callable[[], None]], None] | None = None,
) -> int:
    """The one loop, in the foreground — the unit's ExecStart.

    IDLE-NOT-DEAD: a dead or absent session owner is RECORDED, never a reason to
    exit. The arm stands for the next session; the durable queue holds whatever
    was raised while none was seated.
    """
    mode = env.get("SYN_WATCH_MODE", "") or "daemon"
    mine = os.getpid()
    paths.state.mkdir(parents=True, exist_ok=True)

    if lease_alive(paths, stat_reader=stat_reader, signal_zero=signal_zero) and read_lease(paths.lease).get(
        "pid", ""
    ) != str(mine):
        say_err(f"refusing — an arm for {paths.state} is already up (pid {read_lease(paths.lease).get('pid', '')})")
        return 0

    generation = next_generation(paths)
    helm = identity_mod.resolve(env, runner=runner)
    if helm.missing:
        say_err(
            f"the helm stands READ-ONLY — {helm.readonly_reason()} could not be resolved; "
            "no errand may be seated under it"
        )
    install = signal_installer or _install_traps
    install(lambda: release_lease(paths, pid=mine))
    # H6/H8 (plan 257): the pin's currency is computed ONCE per daemon run — two git
    # reads per 5 s poll would be noise — and carried into every lease write.
    pin, pin_behind = pin_facts(env, runner)
    if not write_lease(
        paths,
        pid=mine,
        mode=mode,
        role=resolve_role(paths, env, session="none"),
        helm=helm,
        session="none",
        generation=generation,
        stat_reader=stat_reader,
        pin=pin,
        pin_behind=pin_behind,
    ):
        say_err(f"cannot write lease {paths.lease}")
        return 1
    for marker in (paths.armed, paths.heartbeat):
        try:
            marker.touch()
        except OSError:
            pass
    say_err(
        f"arm up pid={mine} gen={generation} mode={mode} state={paths.state} "
        f"seat={helm.seat} role={helm.fleetrole or 'unknown'} pin={helm.pin} "
        f"identity={helm.identity}"
    )

    while True:
        try:
            line = cycle(
                paths,
                env=env,
                runner=runner,
                mode=mode,
                pid=mine,
                emit=emit,
                helm=helm,
                stat_reader=stat_reader,
                pin=pin,
                pin_behind=pin_behind,
            )
        except Exception as exc:  # noqa: BLE001 — the arm outlives any one bad cycle; it says so and keeps watching
            say_err(f"arm cycle failed and was survived: {exc.__class__.__name__}: {str(exc)[:200]}")
            line = ""
        if line:
            print(line)
            release_lease(paths, pid=mine)
            return 0
        sleep(paths.poll_seconds)


def _install_traps(release: Callable[[], None]) -> None:
    """The shell's `trap 'release_lease; exit 0' TERM INT`, exactly."""

    def handler(signum, frame):  # noqa: ANN001 - the signal protocol
        release()
        raise SystemExit(0)

    for number in (signal.SIGTERM, signal.SIGINT):
        try:
            signal.signal(number, handler)
        except (ValueError, OSError):  # pragma: no cover - not the main thread
            pass


# ── the door ────────────────────────────────────────────────────────────────


USAGE = "usage: syn-watch.sh status [--detail] | start | stop | restart | run [--emit]"


def main(
    argv: Sequence[str],
    *,
    env: Mapping[str, str] | None = None,
    runner: proc.Runner = proc.run,
    probe=proc.which,
    sleep: Callable[[float], None] = time.sleep,
    spawn: Callable[..., int] = proc.spawn_detached,
    stat_reader: Callable[[int], str] | None = None,
    signal_installer: Callable[[Callable[[], None]], None] | None = None,
    out=None,
) -> int:
    """`python3 -m ymir_runtime watch <verb>` — the arm's door face."""
    environ = dict(os.environ) if env is None else dict(env)
    arguments = list(argv)
    verb = arguments[0] if arguments else "status"
    flags = arguments[1:]

    if verb in ("-v", "-V", "--version"):
        print(VERSION)
        return 0
    if verb in ("-h", "--help"):
        print(USAGE)
        return 0

    paths = arm_paths(environ)
    writer = out if out is not None else sys.stdout
    stat = stat_reader or proc._proc_stat

    if verb == "status":
        if "--detail" in flags:
            text, code = status_detail(paths, env=environ, runner=runner, stat_reader=stat, now=None)
        else:
            text, code = status_lines(paths, env=environ, runner=runner, stat_reader=stat, now=None)
        writer.write(text)
        writer.flush()
        if code != 0:
            for line in _remedy(paths):
                print(line, file=sys.stderr)
        return code

    if verb == "start":
        return start_service(
            paths, env=environ, runner=runner, sleep=sleep, spawn=spawn, stat_reader=stat
        )

    if verb == "stop":
        return stop_service(paths, runner=runner, sleep=sleep, stat_reader=stat)

    if verb == "restart":
        stop_service(paths, runner=runner, sleep=sleep, stat_reader=stat)
        return start_service(
            paths, env=environ, runner=runner, sleep=sleep, spawn=spawn, stat_reader=stat
        )

    if verb == "run":
        for flag in flags:
            if flag not in ("--emit", "--foreground"):
                say_err(f"unknown flag {flag} to run")
                return 2
        return run_daemon(
            paths,
            env=environ,
            runner=runner,
            sleep=sleep,
            emit="--emit" in flags,
            stat_reader=stat,
            signal_installer=signal_installer,
        )

    say_err(f"unknown command {verb} (status|start|stop|restart|run)")
    return 2


def _remedy(paths: ArmPaths) -> list[str]:
    state = status_state(paths)
    if state == DOWN:
        return [
            f"syn-watch: the arm is DOWN — no live lease for {paths.state}",
            "remedy: bin/pi/syn-watch.sh start",
        ]
    if state == STALE:
        return [
            "syn-watch: the arm is STALE — heartbeat age "
            f"{heartbeat_age(paths)}s exceeds {paths.stale_seconds}s",
            "remedy: bin/pi/syn-watch.sh restart",
        ]
    return []
