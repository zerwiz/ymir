"""One place that runs a process, so every module is testable without a spawn.

The engine's modules take a `Runner` — a callable shaped exactly like `run()`
below. Production passes nothing (the default runs the real argv); a unit test
passes a recorder, so the module's *decision* is asserted without a pane, a
worktree, or a model ever being touched.
"""

from __future__ import annotations

import shutil
import subprocess
from typing import Callable, Mapping, Sequence

Completed = subprocess.CompletedProcess
Runner = Callable[..., Completed]


def run(
    argv: Sequence[str],
    *,
    cwd: str | None = None,
    env: Mapping[str, str] | None = None,
    timeout: float | None = None,
) -> Completed:
    """Run argv and capture it. Never raises on a non-zero exit."""
    return subprocess.run(
        list(argv),
        cwd=cwd,
        env=dict(env) if env is not None else None,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def which(name: str) -> str:
    """The absolute path of an executable, or empty when it is absent."""
    return shutil.which(name) or ""


def ok(completed: Completed) -> bool:
    return completed.returncode == 0


def out(completed: Completed) -> str:
    return (completed.stdout or "").strip()


def shell_quote(value: str) -> str:
    """POSIX quoting for a launch line — the bash doors' `shell_quote` twin."""
    return "'" + value.replace("'", "'\\''") + "'"
