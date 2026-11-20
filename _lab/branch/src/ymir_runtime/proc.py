"""One place that runs a process, so every module is testable without a spawn.

The engine's modules take a `Runner` — a callable shaped exactly like `run()`
below. Production passes nothing (the default runs the real argv); a unit test
passes a recorder, so the module's *decision* is asserted without a pane, a
worktree, or a model ever being touched.
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import Callable, Mapping, Sequence

Completed = subprocess.CompletedProcess
Runner = Callable[..., Completed]


def run(
    argv: Sequence[str],
    *,
    cwd: str | None = None,
    env: Mapping[str, str] | None = None,
    timeout: float | None = None,
    input_text: str | None = None,
) -> Completed:
    """Run argv and capture it. Never raises on a non-zero exit.

    `input_text` exists for the one pipeline the engine needs (`git show | git
    patch-id --stable`, the patch-identity proof); everything else passes argv.
    """
    try:
        return subprocess.run(
            list(argv),
            cwd=cwd,
            env=dict(env) if env is not None else None,
            capture_output=True,
            text=True,
            timeout=timeout,
            input=input_text,
        )
    except FileNotFoundError:
        # A missing binary is a FAILED command, not a crash: every caller of this
        # module reads a non-zero exit and decides (the landed gate refuses), so
        # an absent `gh` must never take the process down with it.
        return Completed(args=list(argv), returncode=127, stdout="", stderr=f"not found: {argv[0]}")


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


def _proc_stat(pid: int) -> str:
    """Everything after the comm field of `/proc/<pid>/stat`, or "" when absent.

    `comm` may itself contain spaces and parentheses, so the split is on the LAST
    `)` — the reader returns the RAW line and `stat_rest` does the strip, exactly
    where the shell's `gleipnir_proc_stat_rest` does it.
    """
    try:
        return Path(f"/proc/{pid}/stat").read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def stat_rest(line: str) -> str:
    """Everything after the comm field — the shell's `tr ')' '\n' | tail -n 1`."""
    return line.rsplit(")", 1)[-1] if ")" in line else line


def proc_state(pid: int, *, stat_reader: Callable[[int], str] = _proc_stat) -> str:
    """The process state character (`R`, `S`, `Z`, …), or "" when unreadable."""
    fields = stat_rest(stat_reader(pid)).split()
    return fields[0][:1] if fields else ""


def proc_starttime(pid: int, *, stat_reader: Callable[[int], str] = _proc_stat) -> str:
    """Field 22 of `/proc/<pid>/stat` — clock ticks since boot, stable per pid.

    The shell's `gleipnir_proc_starttime` reads the same field: a mismatch with
    the value recorded when a lease was taken means the kernel recycled the pid.
    """
    fields = stat_rest(stat_reader(pid)).split()
    return fields[19] if len(fields) >= 20 else ""


def pid_alive(
    pid: int | str,
    starttime: str = "",
    *,
    stat_reader: Callable[[int], str] = _proc_stat,
    signal_zero: Callable[[int], None] | None = None,
) -> bool:
    """Is `pid` genuinely alive? — the Python twin of `gleipnir_pid_alive`.

    `kill -0` alone is blind: it also reports a zombie (dead but unreaped) and a
    pid the kernel has since handed to an unrelated process. Where `/proc` is
    readable the state character (Z/X = dead) and the recorded starttime settle
    both; where it is not (macOS, a container without /proc) the signal probe is
    the only evidence, exactly as in the shell.
    """
    try:
        number = int(str(pid))
    except (TypeError, ValueError):
        return False
    if number <= 0:
        return False
    state = proc_state(number, stat_reader=stat_reader)
    if state in ("Z", "X"):
        return False
    if starttime:
        current = proc_starttime(number, stat_reader=stat_reader)
        if current and current != starttime:
            return False
    probe = signal_zero or (lambda target: os.kill(target, 0))
    try:
        probe(number)
    except OSError:
        return False
    return True


def spawn_detached(
    argv: Sequence[str],
    *,
    env: Mapping[str, str] | None = None,
    cwd: str | None = None,
    log_path: str | Path | None = None,
) -> int:
    """Start argv in its own session, outliving this process. Returns its pid.

    The `setsid … &` shape the bash door used, with one difference worth having:
    the log handle is opened here, so a detached arm's output lands in the file
    rather than on a closed descriptor.
    """
    sink: object = subprocess.DEVNULL
    handle = None
    if log_path is not None:
        handle = open(log_path, "a", encoding="utf-8", errors="replace")  # noqa: SIM115 - handed to the child
        sink = handle
    try:
        child = subprocess.Popen(  # noqa: S603 - argv is built by the engine, never a shell string
            [str(part) for part in argv],
            cwd=cwd,
            env=dict(env) if env is not None else None,
            stdin=subprocess.DEVNULL,
            stdout=sink,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            close_fds=True,
        )
    finally:
        if handle is not None:
            handle.close()
    return child.pid
