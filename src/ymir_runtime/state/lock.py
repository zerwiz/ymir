"""locks (Gleipnir) — the session lock, in Python, as the ONE implementation.

Gleipnir is the impossible chain that bound Fenrir: here it binds ONE live
Brokk primary per MACHINE. `bin/vault/gleipnir-lock-lib.sh` is now a THIN SHIM over
this module — every function there resolves its answer here, so the lock has
exactly one implementation and two readers (the shell doors and the harness
extensions, which read the `.lock-path` pointer this module writes).

The contract, preserved to the byte from the shell library it replaces:

  state dir     `$BROKK_STATE_OVERRIDE` → an Eindri-home's `<home>/state` →
                the hoard's `<YMIR_HOME>/state` (never the code tree)
  lock path     machine-global `${XDG_STATE_HOME:-$HOME/.local/state}/ymir/brokk.lock`
                for the primary; `<home>/state/.lock` for an Eindri-home
  pointer       `<state>/.lock-path` — the path the non-bash readers consult
  owner         the OLDEST live harness process above the caller, or the pid
                handed in by the harness (`BROKK_SESSION_PID`)
  liveness      /proc/<pid>/stat field 22 (starttime) beside the lock, so a
                recycled pid reads as death; a zombie is not a lock
  reap          a lock whose owner is verifiably gone is removed and reported
                loud on stderr; a lock whose owner lives is REFUSED

A parity mismatch is a refusal, never a rewrite: the harness readers read the
same pointer, the same owner file, and the same starttime beside it.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

from ..paths import DEFAULT_HOME

HARNESS_COMMS = (
    "pi",
    "opencode",
    "claude",
    "cursor",
    "codex",
    "grok",
    "kimi",
    "muse",
    "hermes",
)
ANCESTRY_LIMIT = 8
PROC_ROOT = "/proc"


def _env(env: Mapping[str, str] | None) -> dict[str, str]:
    return dict(os.environ) if env is None else dict(env)


def _nonempty(*values: object) -> str:
    for value in values:
        if value:
            return str(value)
    return ""


# --- the home law (mirrors bin/vault/hoard-lib.sh) --------------------------------


def config_dir(env: Mapping[str, str] | None = None) -> Path:
    e = _env(env)
    explicit = e.get("YMIR_CONFIG_DIR")
    if explicit:
        return Path(explicit).expanduser()
    xdg = e.get("XDG_CONFIG_HOME") or "~/.config"
    return Path(xdg).expanduser() / "ymir"


def recorded_home(env: Mapping[str, str] | None = None) -> str:
    try:
        return (config_dir(env) / "home").read_text(encoding="utf-8").splitlines()[0].strip()
    except (OSError, IndexError):
        return ""


def ymir_home(env: Mapping[str, str] | None = None) -> Path:
    explicit = _env(env).get("YMIR_HOME")
    if explicit:
        return Path(explicit).expanduser()
    return Path(recorded_home(env) or DEFAULT_HOME).expanduser()


def repo_root(env: Mapping[str, str] | None = None) -> Path:
    """The CODE tree — where `bin/` and `src/` live (the shim's own root)."""
    e = _env(env)
    for key in ("BROKK_ROOT_OVERRIDE", "BROKK_HOME"):
        if e.get(key):
            return Path(e[key]).expanduser()
    return Path(__file__).resolve().parents[3]


def brokk_home(env: Mapping[str, str] | None = None) -> Path:
    """The home whose `.yggdrasil/` holds this machine's task worktrees.

    The shell library read `BROKK_HOME` first, then `BROKK_ROOT_OVERRIDE`, then
    fell back to the library's own root; the order is preserved.
    """
    e = _env(env)
    for key in ("BROKK_HOME", "BROKK_ROOT_OVERRIDE"):
        if e.get(key):
            return Path(e[key]).expanduser()
    return repo_root(e)


# --- the state dirs ---------------------------------------------------------


def is_eindri_home(env: Mapping[str, str] | None = None) -> bool:
    e = _env(env)
    if e.get("BROKK_HOME_KIND") == "eindri":
        return True
    return (brokk_home(e) / "data" / "eindri-home").is_file()


def hoard_state_dir(env: Mapping[str, str] | None = None) -> Path:
    e = _env(env)
    return Path(e.get("YMIR_STATE_DIR") or (ymir_home(e) / "state")).expanduser()


def state_dir(env: Mapping[str, str] | None = None) -> Path:
    e = _env(env)
    if e.get("BROKK_STATE_OVERRIDE"):
        return Path(e["BROKK_STATE_OVERRIDE"]).expanduser()
    if is_eindri_home(e):
        return brokk_home(e) / "state"
    return hoard_state_dir(e)


def machine_state_dir(env: Mapping[str, str] | None = None) -> Path:
    e = _env(env)
    base = e.get("BROKK_MACHINE_STATE_DIR")
    if base:
        return Path(base).expanduser()
    xdg = e.get("XDG_STATE_HOME") or "~/.local/state"
    return Path(xdg).expanduser() / "ymir"


def legacy_lock_path(env: Mapping[str, str] | None = None) -> Path:
    return state_dir(env) / ".lock"


def lock_path(env: Mapping[str, str] | None = None) -> Path:
    if is_eindri_home(env):
        return legacy_lock_path(env)
    return machine_state_dir(env) / "brokk.lock"


def pointer_path(env: Mapping[str, str] | None = None) -> Path:
    return state_dir(env) / ".lock-path"


# --- process truth ----------------------------------------------------------


def _read(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def proc_stat_rest(pid: int | str) -> str | None:
    """Everything after the final `)` of /proc/<pid>/stat, or None."""
    text = _read(f"{PROC_ROOT}/{pid}/stat")
    if not text or ")" not in text:
        return None
    return text.rsplit(")", 1)[1]


def proc_starttime(pid: int | str) -> str | None:
    rest = proc_stat_rest(pid)
    if rest is None:
        return None
    fields = rest.split()
    if len(fields) >= 20:
        return fields[19]
    return None


def _ps(field: str, pid: int | str) -> str:
    try:
        out = subprocess.run(
            ["ps", f"-o{field}=", "-p", str(pid)],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return ""
    return re.sub(r"\s+", "", out.stdout)


def _ppid(pid: int) -> int | None:
    rest = proc_stat_rest(pid)
    if rest is not None:
        fields = rest.split()
        if len(fields) >= 2 and fields[1].isdigit():
            return int(fields[1])
    value = _ps("ppid", pid)
    return int(value) if value.isdigit() else None


def _comm(pid: int) -> str:
    text = _read(f"{PROC_ROOT}/{pid}/comm")
    if text:
        return text.strip()
    return _ps("comm", pid)


def pid_alive(pid: int | str, expected: str = "") -> bool:
    """A pid is alive only when the process genuinely exists.

    `kill -0` alone is blind: it also succeeds for a zombie and for a pid the
    kernel has recycled. /proc/<pid>/stat resolves both — the state character
    (Z/X = zombie/dead) and the starttime recorded beside the lock.
    """
    text = str(pid)
    if not text.isdigit():
        return False
    rest = proc_stat_rest(text)
    if rest is not None:
        fields = rest.split()
        if fields and fields[0][:1] in ("Z", "X"):
            return False
        if expected:
            current = proc_starttime(text)
            if current and current != expected:
                return False
    try:
        os.kill(int(text), 0)
    except OSError:
        return False
    return True


def _read_pid(path: Path) -> str:
    try:
        return re.sub(r"\s+", "", path.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        return ""


def session_pid(env: Mapping[str, str] | None = None, *, shell_pid: int | str | None = None) -> str:
    """The pid the lock binds to: the live HARNESS, never the short-lived helper.

    A harness passes `BROKK_SESSION_PID`; otherwise the ancestry is walked for
    the harness itself (pi / opencode / claude / …). Only a run with no harness
    ancestor falls back to the calling shell.
    """
    e = _env(env)
    explicit = e.get("BROKK_SESSION_PID")
    if explicit:
        return explicit
    start = str(shell_pid if shell_pid is not None else os.getppid())
    pid_text = start
    for _ in range(ANCESTRY_LIMIT):
        if not pid_text.isdigit():
            break
        parent = _ppid(int(pid_text))
        if not parent or parent == 1:
            break
        if _comm(parent) in HARNESS_COMMS and pid_alive(parent):
            return str(parent)
        pid_text = str(parent)
    return start


# --- the lock itself --------------------------------------------------------


def lock_owner(env: Mapping[str, str] | None = None) -> str:
    lock = lock_path(env)
    value = _read_pid(lock)
    if not value:
        legacy = legacy_lock_path(env)
        if legacy != lock:
            value = _read_pid(legacy)
    return value


def lock_owned(env: Mapping[str, str] | None = None, *, shell_pid: int | str | None = None) -> bool:
    owner = lock_owner(env)
    start = str(shell_pid if shell_pid is not None else os.getppid())
    if owner and owner == start:
        return True
    pid_text = start
    for _ in range(ANCESTRY_LIMIT):
        if not pid_text.isdigit():
            return False
        parent = _ppid(int(pid_text))
        if not parent or parent == 1:
            return False
        if str(parent) == owner:
            return True
        pid_text = str(parent)
    return False


def write_pointer(lock: Path, env: Mapping[str, str] | None = None) -> None:
    pointer = pointer_path(env)
    try:
        pointer.parent.mkdir(parents=True, exist_ok=True)
        pointer.write_text(f"{lock}\n", encoding="utf-8")
    except OSError:
        pass


def drop_legacy(want: str, env: Mapping[str, str] | None = None) -> None:
    legacy = legacy_lock_path(env)
    lock = lock_path(env)
    if legacy == lock or not legacy.exists():
        return
    if _read_pid(legacy) == want:
        _remove(legacy)
        _remove(Path(str(legacy) + ".starttime"))


def _remove(path: Path) -> None:
    try:
        path.unlink()
    except OSError:
        pass


def _write(path: Path, text: str) -> bool:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return True
    except OSError:
        return False


def reap(env: Mapping[str, str] | None = None) -> list[str]:
    """Remove any lock whose owner is verifiably gone; report it loud.

    Resolved and legacy paths are both swept, so an abnormal close (crash,
    kill, closing the terminal) can never leave a stale lock holding supervision.
    """
    reaped: list[str] = []
    for path in (lock_path(env), legacy_lock_path(env)):
        if not path or not path.exists():
            continue
        owner = _read_pid(path)
        if not owner:
            continue
        expect = _read_pid(Path(str(path) + ".starttime"))
        if not pid_alive(owner, expect):
            _remove(path)
            _remove(Path(str(path) + ".starttime"))
            print(f"gleipnir: reaped stale lock (dead pid {owner})", file=sys.stderr)
            reaped.append(owner)
    return reaped


def acquire(env: Mapping[str, str] | None = None, *, shell_pid: int | str | None = None) -> bool:
    state = state_dir(env)
    try:
        state.mkdir(parents=True, exist_ok=True)
    except OSError:
        return False
    reap(env)
    lock = lock_path(env)
    want = session_pid(env, shell_pid=shell_pid)
    owner = lock_owner(env)
    expect = _read_pid(Path(str(lock) + ".starttime")) if owner else ""
    if owner and owner != want and pid_alive(owner, expect):
        return False
    if not _write(lock, f"{want}\n"):
        return False
    starttime = proc_starttime(want)
    if starttime:
        _write(Path(str(lock) + ".starttime"), f"{starttime}\n")
    else:
        _remove(Path(str(lock) + ".starttime"))
    write_pointer(lock, env)
    drop_legacy(want, env)
    return True


def release(env: Mapping[str, str] | None = None, *, shell_pid: int | str | None = None) -> bool:
    lock = lock_path(env)
    legacy = legacy_lock_path(env)
    want = session_pid(env, shell_pid=shell_pid)
    owner = lock_owner(env)
    if owner != want:
        return False
    _remove(lock)
    _remove(Path(str(lock) + ".starttime"))
    if legacy != lock:
        _remove(legacy)
        _remove(Path(str(legacy) + ".starttime"))
    _remove(pointer_path(env))
    return True


@dataclass(frozen=True)
class LockState:
    """The resolved lock as one record — the shape a caller prints."""

    state_dir: Path
    lock_path: Path
    legacy_lock_path: Path
    pointer_path: Path
    machine_state_dir: Path
    eindri_home: bool


def inspect(env: Mapping[str, str] | None = None) -> LockState:
    return LockState(
        state_dir=state_dir(env),
        lock_path=lock_path(env),
        legacy_lock_path=legacy_lock_path(env),
        pointer_path=pointer_path(env),
        machine_state_dir=machine_state_dir(env),
        eindri_home=is_eindri_home(env),
    )
