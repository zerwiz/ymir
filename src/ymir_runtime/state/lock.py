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

The arm that is never lost (2026-11-20). A live helm keeps the arm until it
releases it or dies, and EVERY change of hands is on the record: `append_journal`
writes one append-only line to `<state>/.lock-journal` (who, from whom, why) and
mirrors the last one into `<state>/.arm.handover`, which `bin/seat/arm-handover.sh`
reads to announce the hand-over into the panes. What was measured before this:
the lock changed hands four times in ninety minutes with no line anywhere saying
the helm had moved.

ONE WRITER. Only this module writes the lock. The lock and its starttime are
written as a PAIR under an advisory guard (`<lock>.guard`), because a reader that
caught the new pid beside the old starttime declared a live owner dead and took
the helm from it; and because a second writer (a harness extension) left exactly
that pair behind.

A parity mismatch is a refusal, never a rewrite: the harness readers read the
same pointer, the same owner file, and the same starttime beside it.
"""

from __future__ import annotations

import contextlib
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, Mapping

try:  # the guard is an optimisation on a seat without fcntl; it is never a failure
    import fcntl
    _HAVE_FCNTL = True
except ImportError:  # pragma: no cover — macOS/Linux both ship it
    fcntl = None  # type: ignore[assignment]
    _HAVE_FCNTL = False

# A POSIX record lock (`fcntl.lockf`), not `flock(1)`'s syscall by name: it is the
# portable call in the standard library, and it keeps the house's GNU-name ratchet
# honest — that ward counts a shell's GNU spelling, and this is not one.

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
JOURNAL_NAME = ".lock-journal"
HANDOVER_NAME = ".arm.handover"
GUARD_SUFFIX = ".guard"


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
    _write(pointer_path(env), f"{lock}\n")


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
    """Write one file atomically — a reader never sees it torn.

    A torn lock is a lying lock: an empty `brokk.lock` mid-write reads as "no
    owner" in every reader, and a reaper that catches it hands the helm away.
    """
    temporary = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_text(text, encoding="utf-8")
        os.replace(temporary, path)
        return True
    except OSError:
        _remove(temporary)
        return False


# --- one writer, one record (2026-11-20) -----------------------------------


def guard_path(env: Mapping[str, str] | None = None) -> Path:
    return Path(str(lock_path(env)) + GUARD_SUFFIX)


@contextlib.contextmanager
def _guard(env: Mapping[str, str] | None = None) -> Iterator[None]:
    """Serialise every decide-and-write on the lock.

    The lock and its starttime are two files, and the decision reads both. A
    reader that catches the new pid beside the OLD starttime declares a live
    owner dead (`pid_alive` sees a recycled pid) and takes the arm from a live
    hand — measured: four changes of hands in ninety minutes, none recorded.
    Everything that decides about the lock holds this guard, so the pair is
    always observed as one fact.
    """
    fd = -1
    try:
        path = guard_path(env)
        path.parent.mkdir(parents=True, exist_ok=True)
        fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o644)
        if _HAVE_FCNTL:
            fcntl.lockf(fd, fcntl.LOCK_EX)
    except OSError:
        fd = -1
    try:
        yield
    finally:
        if fd >= 0:
            try:
                if _HAVE_FCNTL:
                    fcntl.lockf(fd, fcntl.LOCK_UN)
            except OSError:
                pass
            try:
                os.close(fd)
            except OSError:
                pass


def journal_path(env: Mapping[str, str] | None = None) -> Path:
    return state_dir(env) / JOURNAL_NAME


def handover_path(env: Mapping[str, str] | None = None) -> Path:
    return state_dir(env) / HANDOVER_NAME


def _flat(value: object) -> str:
    return re.sub(r"\s+", "_", str(value)).strip("_")


def append_journal(env: Mapping[str, str] | None = None, event: str = "", **fields: object) -> str:
    """Record one change of the arm — append-only, never rewritten.

    `<state>/.lock-journal` is the history; `<state>/.arm.handover` is the same
    line when it moved the helm, so a door can read the last hand-over whole
    without parsing a log. A write that cannot land is reported and swallowed:
    losing the record must never lose the lock.
    """
    values = [(key, value) for key, value in fields.items() if value not in (None, "")]
    line = " ".join([time.strftime("%Y-%m-%dT%H:%M:%S%z"), f"event={_flat(event)}"]
                    + [f"{key}={_flat(value)}" for key, value in values])
    try:
        path = journal_path(env)
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")
    except OSError as exc:
        print(f"gleipnir: the hand-over record could not be written ({exc})", file=sys.stderr)
        return line
    if event in ("acquire", "release", "reap"):
        _write(handover_path(env), line + "\n")
    return line


def last_handover(env: Mapping[str, str] | None = None) -> dict[str, str]:
    """The last recorded change of the arm as a mapping (`{}` when none)."""
    try:
        text = handover_path(env).read_text(encoding="utf-8").splitlines()[0].strip()
    except (OSError, IndexError):
        return {}
    record: dict[str, str] = {}
    for index, token in enumerate(text.split()):
        key, _, value = token.partition("=")
        if index == 0 and not value:
            record["at"] = token          # the Sol-style stamp opens every line
            continue
        if key and value and key not in record:
            record[key] = value
    return record


def _role_of(pid: str) -> str:
    comm = _comm(int(pid)) if str(pid).isdigit() else ""
    if comm == "pi":
        return "counsellor"
    return comm or "unknown"


def announce(env: Mapping[str, str] | None = None) -> bool:
    """Speak a hand-over into the panes — a detached best-effort courtesy.

    The RECORD above is the durable fact; the announcement is the courtesy that
    stops the room going quiet. It is never waited on (a session start must not
    block on herdr) and never fatal. `YMIR_LOCK_ANNOUNCE=0` silences it, which
    is what a test that owns a temp state does.
    """
    e = _env(env)
    if e.get("YMIR_LOCK_ANNOUNCE", "1").strip().lower() in ("0", "no", "off", "false"):
        return False
    script = repo_root(e) / "bin" / "seat" / "arm-handover.sh"
    if not script.is_file() or not os.access(script, os.X_OK):
        return False
    child = dict(os.environ)
    child.update(e)
    child["YMIR_STATE_DIR"] = str(state_dir(e))
    try:
        subprocess.Popen(  # noqa: S603 — a fixed path in this tree, no shell
            [str(script), "--announce"],
            env=child,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        return True
    except OSError:
        return False


def _read_pair(env: Mapping[str, str] | None = None) -> tuple[str, str]:
    """The lock as ONE fact: owner pid and the starttime recorded beside it."""
    lock = lock_path(env)
    owner = _read_pid(lock)
    if not owner:
        legacy = legacy_lock_path(env)
        if legacy != lock:
            return _read_pid(legacy), _read_pid(Path(str(legacy) + ".starttime"))
        return "", ""
    return owner, _read_pid(Path(str(lock) + ".starttime"))


def _write_pair(env: Mapping[str, str] | None = None, want: str = "") -> bool:
    """Write the lock and its starttime as one fact, under the guard."""
    lock = lock_path(env)
    side = Path(str(lock) + ".starttime")
    if not _write(lock, f"{want}\n"):
        return False
    starttime = proc_starttime(want)
    if starttime:
        _write(side, f"{starttime}\n")
    else:
        _remove(side)
    return True


def _reap_locked(env: Mapping[str, str] | None = None) -> list[tuple[str, str]]:
    """Reap every lock whose owner is verifiably gone; keep the reason."""
    reaped: list[tuple[str, str]] = []
    for path in (lock_path(env), legacy_lock_path(env)):
        if not path or not path.exists():
            continue
        owner = _read_pid(path)
        if not owner:
            continue
        expect = _read_pid(Path(str(path) + ".starttime"))
        if pid_alive(owner, expect):
            continue
        why = "dead" if not pid_alive(owner) else "starttime-mismatch"
        _remove(path)
        _remove(Path(str(path) + ".starttime"))
        print(
            f"gleipnir: reaped stale lock (pid {owner}, {why}) — recorded in {journal_path(env)}",
            file=sys.stderr,
        )
        reaped.append((owner, why))
    return reaped


def reap(env: Mapping[str, str] | None = None) -> list[str]:
    """Remove any lock whose owner is verifiably gone; report it loud, and record it.

    Resolved and legacy paths are both swept, so an abnormal close (crash,
    kill, closing the terminal) can never leave a stale lock holding supervision.
    A reap is a change of hands and goes on the record like any other.
    """
    with _guard(env):
        reaped = _reap_locked(env)
    for owner, why in reaped:
        append_journal(env, "reap", pid=owner, reason=why, role=_role_of(owner),
                       from_pid="none", to_pid="none")
    if reaped:
        announce(env)
    return [owner for owner, _ in reaped]


def acquire(env: Mapping[str, str] | None = None, *, shell_pid: int | str | None = None) -> bool:
    e = _env(env)
    state = state_dir(e)
    try:
        state.mkdir(parents=True, exist_ok=True)
    except OSError:
        return False
    want = session_pid(e, shell_pid=shell_pid)
    reaped: list[tuple[str, str]] = []
    with _guard(e):
        reaped = _reap_locked(e)
        owner, expect = _read_pair(e)
        if owner and owner != want and pid_alive(owner, expect):
            return False
        if not _write_pair(e, want):
            return False
        write_pointer(lock_path(e), e)
        drop_legacy(want, e)
    if owner == want and not reaped:
        return True
    # EVERY change of hands is recorded, including the reap that cleared the way:
    # a lock that quietly stood aside is the silence this record exists to end.
    for gone, reason in reaped:
        append_journal(e, "reap", pid=gone, reason=reason, role=_role_of(gone),
                       from_pid="none", to_pid="none")
    if owner == want:
        announce(e)
        return True
    why = reaped[0][1] if reaped else ("vacant" if not owner else "reaped")
    came_from = owner or (reaped[0][0] if reaped else "none")
    starttime = proc_starttime(want) or ""
    append_journal(e, "acquire", pid=want, starttime=starttime, from_pid=came_from,
                   to_pid=want, why=why, role=_role_of(want),
                   harness="yes" if _role_of(want) in ("counsellor",) + HARNESS_COMMS else "no")
    announce(e)
    return True


def release(env: Mapping[str, str] | None = None, *, shell_pid: int | str | None = None) -> bool:
    e = _env(env)
    lock = lock_path(e)
    legacy = legacy_lock_path(e)
    want = session_pid(e, shell_pid=shell_pid)
    with _guard(e):
        owner, _expect = _read_pair(e)
        if owner != want:
            return False
        _remove(lock)
        _remove(Path(str(lock) + ".starttime"))
        if legacy != lock:
            _remove(legacy)
            _remove(Path(str(legacy) + ".starttime"))
        _remove(pointer_path(e))
    append_journal(e, "release", pid=want, from_pid=want, to_pid="none", why="released",
                   role=_role_of(want))
    announce(e)
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
