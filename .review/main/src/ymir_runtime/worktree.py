"""Yggdrasil — the worktree. One errand, one checkout, zero collision.

The engine owns this step so `bin/einherjar-spawn.sh` does not have to. The
behaviour is deliberately the *same* as the shell road it replaces:

  · the path is the same  (`<root>/.yggdrasil/<seat-id>`)
  · a worktree that already stands is REUSED, not refused
  · a directory that is not a worktree is a LOUD refusal, never an overwrite
  · the checkout is DETACHED at the default branch's remote head (the worker's
    brief tells it which branch to cut; the seat does not choose one)

Anything else here would be drift, and drift is what the parity check exists to
catch.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from . import proc
from .errors import EngineError


@dataclass(frozen=True)
class Worktree:
    seat_id: str
    path: Path
    base: str
    created: bool
    head: str


def default_base(project_dir: Path, *, runner: proc.Runner = proc.run) -> str:
    """The remote head of the project's default branch, else HEAD."""
    remote = runner(
        ["git", "-C", str(project_dir), "symbolic-ref", "--quiet", "refs/remotes/origin/HEAD"]
    )
    if proc.ok(remote) and proc.out(remote):
        ref = proc.out(remote).replace("refs/remotes/", "")
        verify = runner(["git", "-C", str(project_dir), "rev-parse", "--verify", "-q", f"refs/remotes/{ref}"])
        if proc.ok(verify):
            return f"refs/remotes/{ref}"
    return "HEAD"


def head_of(path: Path, *, runner: proc.Runner = proc.run) -> str:
    result = runner(["git", "-C", str(path), "rev-parse", "HEAD"])
    return proc.out(result) if proc.ok(result) else ""


def ensure(
    seat_id: str,
    project_dir: str | Path,
    wt_root: str | Path,
    *,
    base: str | None = None,
    runner: proc.Runner = proc.run,
) -> Worktree:
    """Create or reuse `<wt_root>/<seat_id>`, or refuse loudly."""
    project = Path(project_dir)
    if not project.is_dir():
        raise EngineError(f"project directory not found: {project}")

    inside = runner(["git", "-C", str(project), "rev-parse", "--is-inside-work-tree"])
    if not proc.ok(inside):
        raise EngineError(
            f"{project} is not a git working tree; Yggdrasil needs one to create the task worktree"
        )

    path = Path(wt_root) / seat_id

    if (path / ".git").exists():
        top = runner(["git", "-C", str(path), "rev-parse", "--show-toplevel"])
        if not proc.ok(top) or Path(proc.out(top)).resolve() != path.resolve():
            raise EngineError(f"{path} exists but is not the expected worktree root")
        return Worktree(seat_id, path, base or "", False, head_of(path, runner=runner))

    if path.exists():
        raise EngineError(
            f"{path} already exists and is not a Yggdrasil worktree; remove it or choose another task id"
        )

    chosen = base or default_base(project, runner=runner)
    path.parent.mkdir(parents=True, exist_ok=True)
    added = runner(["git", "-C", str(project), "worktree", "add", "--detach", str(path), chosen])
    if not proc.ok(added):
        raise EngineError(
            f"Yggdrasil could not create worktree {path} from {project}: {proc.out(added) or (added.stderr or '').strip()}"
        )
    if not path.is_dir():
        raise EngineError(f"Yggdrasil worktree missing after create: {path}")
    return Worktree(seat_id, path, chosen, True, head_of(path, runner=runner))


def remove(
    seat_id: str,
    project_dir: str | Path,
    wt_root: str | Path,
    *,
    force: bool = False,
    runner: proc.Runner = proc.run,
) -> bool:
    """Reap a worktree. Never called by `stop()` unless the caller asks for it."""
    path = Path(wt_root) / seat_id
    if not path.exists():
        runner(["git", "-C", str(project_dir), "worktree", "prune"])
        return False
    argv = ["git", "-C", str(project_dir), "worktree", "remove"]
    if force:
        argv.append("--force")
    argv.append(str(path))
    result = runner(argv)
    runner(["git", "-C", str(project_dir), "worktree", "prune"])
    return proc.ok(result)
