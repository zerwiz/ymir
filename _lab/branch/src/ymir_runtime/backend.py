"""The backend — where a seat's pane actually lives (herdr first, tmux fallback).

herdr is the fleet's backend; tmux is the verified sibling that keeps a seat
possible when no herdr server answers. The engine owns the choice, the launch,
the steer, and the reap — and it keeps the shell road's own reasons so the meta
record reads identically whichever door was used.

The seat's OWN machine-state dir is set on the launched process, never on ours:
without it every worker raised by this road takes the primary's helm. That
lesson is kept here as law (see `bin/agents/einherjar-spawn.sh`'s header).
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

from . import proc

BACKENDS = ("herdr", "tmux")

_PANE_ID = re.compile(r'"pane_id"\s*:\s*"([^"]+)"')
_WORKSPACE_ID = re.compile(r'"workspace_id"\s*:\s*"([^"]+)"')
_ANY_ID = re.compile(r'"id"\s*:\s*"([^"]+)"')


@dataclass(frozen=True)
class Backend:
    name: str
    reason: str


@dataclass(frozen=True)
class Seat:
    backend: str
    target: str
    workspace: str = ""


def herdr_bin(*, env: Mapping[str, str] | None = None, probe=proc.which) -> str:
    environ = env or {}
    explicit = environ.get("HDR")
    if explicit:
        return explicit
    return probe("herdr") or probe("hdr")


def herdr_server_present(*, runner: proc.Runner = proc.run, probe=proc.which) -> bool:
    """The gate is the SERVER's existence, never a session's HERDR_ENV."""
    status = runner(["pgrep", "-f", "herdr server"])
    if proc.ok(status):
        return True
    binary = probe("herdr")
    if not binary:
        return False
    api = runner([binary, "status", "--json"])
    if not proc.ok(api):
        return False
    body = api.stdout or ""
    if re.search(r'"running"\s*:\s*true', body):
        return True
    try:
        return bool(json.loads(body).get("running"))
    except (ValueError, AttributeError):
        return False


def choose(
    *,
    requested: str = "",
    env: Mapping[str, str] | None = None,
    config_dir: str | Path | None = None,
    runner: proc.Runner = proc.run,
    probe=proc.which,
) -> Backend:
    """Resolve the backend: explicit → env/config → the herdr server → tmux."""
    if requested:
        if requested not in BACKENDS:
            raise ValueError(f"unsupported backend '{requested}' (supported: {', '.join(BACKENDS)})")
        return Backend(requested, "explicit --backend")

    environ = dict(env or {})
    declared = environ.get("BROKK_BACKEND", "")
    if not declared and config_dir:
        pointer = Path(config_dir) / "backend"
        try:
            declared = pointer.read_text(encoding="utf-8").splitlines()[0].strip()
        except (OSError, IndexError):
            declared = ""
    if declared:
        if declared not in BACKENDS:
            raise ValueError(f"unsupported backend '{declared}' (supported: {', '.join(BACKENDS)})")
        return Backend(declared, "explicit (BROKK_BACKEND/config/backend)")

    if herdr_server_present(runner=runner, probe=probe):
        return Backend(
            "herdr",
            "the herdr server answers (pgrep/API) — herdr is the fleet backend; tmux is only the fallback",
        )
    if probe("tmux"):
        return Backend("tmux", "no herdr server answering — tmux is the fallback")
    raise RuntimeError("no backend available — herdr server is not running and tmux is not on PATH")


def _pane_cmd(pane_cmd: str, seat_state_dir: str) -> str:
    if not seat_state_dir:
        return pane_cmd
    quoted = proc.shell_quote(seat_state_dir)
    # TMPDIR is the third isolation axis, and it was missing (2026-09-30). A
    # worktree isolates the CODE and the seat state dir isolates the STATE, but
    # two errands launched in parallel both inherited the machine's /tmp — so
    # opencode, `mktemp -d` and every headless Chrome `--user-data-dir`
    # converged on ONE shared namespace (/tmp/opencode, 282 MB of browser
    # profiles and fixture files by the time it was noticed). Parallel errands
    # then share scratch by accident, which is the collision the isolation law
    # exists to prevent. Each seat now gets its own scratch, reaped with the seat.
    seat_tmp = Path(seat_state_dir) / "tmp"
    try:
        seat_tmp.mkdir(parents=True, exist_ok=True)
        seat_tmp.chmod(0o700)
    except OSError:
        pass
    tmp_quoted = proc.shell_quote(str(seat_tmp))
    return (
        f"BROKK_MACHINE_STATE_DIR={quoted} BROKK_STATE_OVERRIDE={quoted} "
        f"TMPDIR={tmp_quoted} {pane_cmd}"
    )


def launch(
    backend: Backend,
    *,
    seat_id: str,
    pane_cmd: str,
    cwd: str | Path,
    seat_state_dir: str | Path = "",
    session: str = "",
    env: Mapping[str, str] | None = None,
    runner: proc.Runner = proc.run,
    probe=proc.which,
) -> Seat:
    """Seat the errand and return where it landed."""
    command = _pane_cmd(pane_cmd, str(seat_state_dir))
    if backend.name == "tmux":
        return _launch_tmux(seat_id, command, cwd, session=session, env=env, runner=runner, probe=probe)
    if backend.name == "herdr":
        return _launch_herdr(seat_id, command, cwd, seat_state_dir=seat_state_dir, env=env, runner=runner, probe=probe)
    raise ValueError(f"unsupported backend '{backend.name}'")


def _launch_tmux(
    seat_id: str,
    command: str,
    cwd: str | Path,
    *,
    session: str,
    env: Mapping[str, str] | None,
    runner: proc.Runner,
    probe,
) -> Seat:
    if not probe("tmux"):
        raise RuntimeError("backend tmux selected but tmux is not on PATH")
    environ = dict(env or {})
    if environ.get("TMUX"):
        shown = runner(["tmux", "display-message", "-p", "#S"])
        session = proc.out(shown) or session
    session = session or environ.get("BROKK_TMUX_SESSION") or "brokk"
    has = runner(["tmux", "has-session", "-t", session])
    if not proc.ok(has):
        created = runner(["tmux", "new-session", "-d", "-s", session])
        if not proc.ok(created):
            raise RuntimeError(f"could not create tmux session '{session}'")

    window_name = f"eindri-{seat_id}"
    listed = runner(["tmux", "list-windows", "-t", session, "-F", "#{window_name}"])
    if proc.ok(listed) and window_name in (listed.stdout or "").split():
        raise RuntimeError(f"tmux window {session}:{window_name} already exists; tear it down or relaunch")

    made = runner(["tmux", "new-window", "-dP", "-F", "#{window_id}", "-t", f"{session}:", "-n", window_name, "-c", str(cwd)])
    if not proc.ok(made) or not proc.out(made):
        raise RuntimeError(f"tmux failed to create window {session}:{window_name}")
    window = proc.out(made)
    runner(["tmux", "set-window-option", "-t", window, "automatic-rename", "off"])
    runner(["tmux", "set-window-option", "-t", window, "allow-rename", "off"])
    runner(["tmux", "send-keys", "-t", window, "-l", command])
    runner(["tmux", "send-keys", "-t", window, "Enter"])
    return Seat("tmux", window)


def _launch_herdr(
    seat_id: str,
    command: str,
    cwd: str | Path,
    *,
    seat_state_dir: str | Path,
    env: Mapping[str, str] | None,
    runner: proc.Runner,
    probe,
) -> Seat:
    binary = herdr_bin(env=env, probe=probe)
    if not binary:
        raise RuntimeError("backend herdr selected but herdr is not on PATH")
    argv = [binary, "workspace", "create", "--cwd", str(cwd), "--label", f"eindri-{seat_id}", "--no-focus"]
    if seat_state_dir:
        argv += [
            "--env",
            f"BROKK_MACHINE_STATE_DIR={seat_state_dir}",
            "--env",
            f"BROKK_STATE_OVERRIDE={seat_state_dir}",
        ]
    made = runner(argv)
    if not proc.ok(made):
        raise RuntimeError("herdr workspace create failed (is a herdr server running?)")
    body = made.stdout or ""
    workspace = ""
    for pattern in (_WORKSPACE_ID, _ANY_ID):
        match = pattern.search(body)
        if match:
            workspace = match.group(1)
            break
    if not workspace:
        workspace = body.strip().splitlines()[0].strip() if body.strip() else ""
    if not workspace:
        raise RuntimeError(f"could not resolve a herdr workspace id from: {body.strip()}")

    panes = runner([binary, "pane", "list", "--workspace", workspace])
    match = _PANE_ID.search(panes.stdout or "")
    if not match:
        raise RuntimeError(f"no pane found in herdr workspace {workspace}")
    pane = match.group(1)
    runner([binary, "pane", "send-text", pane, command])
    runner([binary, "pane", "send-keys", pane, "Enter"])
    return Seat("herdr", pane, workspace)


def send_text(
    seat: Seat,
    text: str,
    *,
    env: Mapping[str, str] | None = None,
    runner: proc.Runner = proc.run,
    probe=proc.which,
) -> bool:
    """Steer a running seat. The conversational road when the backend has one."""
    if seat.backend == "herdr":
        binary = herdr_bin(env=env, probe=probe)
        if not binary:
            return False
        prompted = runner([binary, "agent", "prompt", seat.target, text])
        if proc.ok(prompted):
            return True
        return proc.ok(runner([binary, "pane", "send-text", seat.target, text]))
    if seat.backend == "tmux":
        for line in text.splitlines() or [""]:
            sent = runner(["tmux", "send-keys", "-t", seat.target, "-l", line])
            if not proc.ok(sent):
                return False
            runner(["tmux", "send-keys", "-t", seat.target, "Enter"])
        return True
    return False


def alive(
    seat: Seat,
    *,
    env: Mapping[str, str] | None = None,
    runner: proc.Runner = proc.run,
    probe=proc.which,
) -> bool:
    if seat.backend == "tmux":
        listed = runner(["tmux", "list-windows", "-a", "-F", "#{window_id}"])
        return proc.ok(listed) and seat.target in (listed.stdout or "").split()
    if seat.backend == "herdr":
        binary = herdr_bin(env=env, probe=probe)
        if not binary:
            return False
        got = runner([binary, "pane", "get", seat.target])
        if proc.ok(got):
            return True
        listed = runner([binary, "pane", "list"])
        return seat.target in (listed.stdout or "")
    return False


def kill(
    seat: Seat,
    *,
    env: Mapping[str, str] | None = None,
    runner: proc.Runner = proc.run,
    probe=proc.which,
) -> bool:
    """Reap the seat. Prefer the whole workspace when the backend has one."""
    if seat.backend == "tmux":
        killed = runner(["tmux", "kill-window", "-t", seat.target])
        return proc.ok(killed) or not alive(seat, env=env, runner=runner, probe=probe)
    if seat.backend == "herdr":
        binary = herdr_bin(env=env, probe=probe)
        if not binary:
            return False
        if seat.workspace:
            if proc.ok(runner([binary, "workspace", "close", "--workspace", seat.workspace])):
                return True
        closed = runner([binary, "pane", "close", seat.target])
        return proc.ok(closed) or not alive(seat, env=env, runner=runner, probe=probe)
    return False
