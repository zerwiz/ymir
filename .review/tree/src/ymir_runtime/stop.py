"""stop(seat_id) — reap the seat cleanly, leaving no orphan.

The reap is the backend's own close, then a second liveness read to prove it
actually happened (a close that silently failed is not a reap). The worktree is
NOT removed by default: unlanded work is never discarded by a lifecycle verb —
the caller must ask (`remove_worktree=True`) and the Allfather's rule about
discarded work still stands above that.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

from . import backend as backend_mod
from . import heartbeat, landed as landed_mod, paths, proc, worktree as worktree_mod
from .errors import EngineError, SeatNotFound


@dataclass(frozen=True)
class StopResult:
    seat_id: str
    backend: str
    target: str
    reaped: bool
    worktree_removed: bool
    detail: str


def stop(
    seat_id: str,
    *,
    env: Mapping[str, str] | None = None,
    runner: proc.Runner = proc.run,
    probe=proc.which,
    remove_worktree: bool = False,
    force: bool = False,
    require_landed: bool = False,
    now: float | None = None,
) -> StopResult:
    """Reap a seat: close the pane, prove it is gone, record the terminal line.

    `require_landed` puts the teardown gate in front of a worktree removal: a
    seat whose work has not landed is REFUSED by name, because the removal is
    what destroys it. `force` is the approved-discard path and is passed
    straight to the gate, exactly as a shell door's `--force` is.
    """
    environ = dict(env) if env is not None else None
    roots = paths.resolve(environ)
    state = roots.state

    meta = heartbeat.read_meta(state, seat_id)
    if not meta:
        raise SeatNotFound(seat_id, str(heartbeat.meta_path(state, seat_id)))

    name = meta.get("backend", "")
    target = meta.get("window", "")
    seat = backend_mod.Seat(name, target, meta.get("seat_workspace", "")) if name and target else None

    was_alive = bool(seat) and backend_mod.alive(seat, env=environ, runner=runner, probe=probe)
    killed = bool(seat) and backend_mod.kill(seat, env=environ, runner=runner, probe=probe)
    still_alive = bool(seat) and backend_mod.alive(seat, env=environ, runner=runner, probe=probe)
    reaped = (not seat) or (not still_alive)

    detail = f"{name}:{target}" if seat else "no live target recorded"
    if seat and not reaped:
        detail += " — the close did not take; the pane still answers"

    heartbeat.append(state, seat_id, f"done: stopped {heartbeat.iso(now)} (engine stop)")

    removed = False
    if remove_worktree and meta.get("worktree"):
        if require_landed:
            verdict = landed_mod.gate(
                meta["worktree"],
                pr_url=meta.get("pr", "") or meta.get("pr_url", ""),
                mode=meta.get("mode", ""),
                force=force,
                runner=runner,
                env=environ,
            )
            if not verdict.landed:
                raise EngineError(
                    f"refusing to remove {meta['worktree']}: the work has not landed "
                    f"({verdict.how}: {verdict.detail})"
                )
        removed = worktree_mod.remove(
            seat_id, meta.get("project", ""), Path(meta["worktree"]).parent, force=force, runner=runner
        )
    return StopResult(
        seat_id=seat_id,
        backend=name,
        target=target,
        reaped=reaped,
        worktree_removed=removed,
        detail=detail + (f" (was alive: {'yes' if was_alive else 'no'}; killed: {'yes' if killed else 'no'})"),
    )
