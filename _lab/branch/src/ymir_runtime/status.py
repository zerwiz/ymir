"""status(seat_id) -> state — the four states, read from the record.

The answer is derived from what the SYSTEM already writes, never from a fresh
guess: the seat's meta, its status log, the silence window, and the backend's
own liveness. A seat read through the engine and a seat read through the old
door therefore agree.

    working   the pane answers and the status log moved inside the window
    blocked   the log says blocked/needs-decision, or the worker went SILENT
    done      the log says done, or a report was filed
    idle      no record, or the record stands but nothing is running
"""

from __future__ import annotations

from enum import Enum
from typing import Mapping

from . import backend as backend_mod
from . import heartbeat, paths, proc


class SeatState(str, Enum):
    WORKING = "working"
    BLOCKED = "blocked"
    DONE = "done"
    IDLE = "idle"

    def __str__(self) -> str:  # pragma: no cover - trivial
        return self.value


def _seat_of(meta: Mapping[str, str]) -> backend_mod.Seat | None:
    name = meta.get("backend", "")
    target = meta.get("window", "")
    if not name or not target:
        return None
    return backend_mod.Seat(name, target, meta.get("seat_workspace", ""))


def status(
    seat_id: str,
    *,
    env: Mapping[str, str] | None = None,
    window: int = heartbeat.WINDOW_SECONDS,
    now: float | None = None,
    runner: proc.Runner = proc.run,
    probe=proc.which,
    check_alive: bool = True,
) -> SeatState:
    """One of working | blocked | done | idle."""
    environ = dict(env) if env is not None else None
    roots = paths.resolve(environ)
    state = roots.state

    meta = heartbeat.read_meta(state, seat_id)
    if not meta:
        return SeatState.IDLE

    declared = heartbeat.classify(heartbeat.last_line(state, seat_id))
    if declared == "done":
        return SeatState.DONE
    if declared in ("failed", "blocked"):
        return SeatState.BLOCKED

    judgement = heartbeat.verdict(state, seat_id, window=window, now=now)
    if judgement == "terminal":
        return SeatState.DONE
    if judgement == "silent":
        return SeatState.BLOCKED
    if judgement == "absent":
        return SeatState.IDLE

    if check_alive:
        seat = _seat_of(meta)
        if seat is None or not backend_mod.alive(seat, env=environ, runner=runner, probe=probe):
            return SeatState.IDLE
    return SeatState.WORKING
