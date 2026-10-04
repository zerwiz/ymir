"""Sýn — the standing arm's behaviour, owned once by the engine.

The arm is a SERVICE (plan 58, Phase 2): it keeps its own lease, beats a
heartbeat every cycle, IDLES when no session is seated instead of retiring, and
raises exactly one `signal:` / `stale:` / `check:` / `heartbeat:` line when the
primary is needed. Until now that judgement lived in bash (`bin/syn-watch.sh`,
409 lines), while the vendored watcher (`.agents/backend/fm-watch.sh`, 1962
lines) carried a second, drifting copy of the same questions over the same
record: is the arm live, is the beat fresh, what is due to be raised.

Plan 58, Phase 5 folds that seam HERE. This module is the ONE owner of "where is
the arm, is it live, what does it raise"; `bin/syn-watch.sh` becomes a thin door
over it, and every caller that reads the state — Eir's `arm` surface, the thin
client `bin/syn-watch-arm.sh`, the harness adapters — gets the same answer, in
the same grammar, with the same exit codes.

The state, all under the resolved state dir (Rule 04: the home, never the tree):

    .watch.heartbeat    epoch seconds, touched every cycle (the liveness door)
    .supervision-armed  the armed marker the turn-end guard reads
    .arm.lease          pid=… starttime=… gen=… mode=… session=… heartbeat=… state=…
    .arm.event          the raised-but-undelivered line (the delivery slot)
    .arm.wake           append-only journal of every line this arm has raised
    .arm.gen            the recovery-generation counter
    .wake-queue         the durable wake queue the raise reads (owned elsewhere)
    .wake-last-hash     the flood brake: one signal per DISTINCT queue content
    *.signal / *.check  one-shot raise triggers, consumed as they are raised
    .watcher-stop       the operator's stop request, raised as `stale:`
"""

from __future__ import annotations

import hashlib
import os
import signal
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Mapping, Sequence

from . import paths as paths_mod
from . import proc

VERSION = "1.0.0"

DEFAULT_POLL_SECONDS = 5
DEFAULT_HEARTBEAT_STALE_SECONDS = 60
DEFAULT_UNIT = "ymir-syn-watch.service"
DEFAULT_DAEMON_GRACE_SECONDS = 15

UP = "up"
IDLE = "idle"
STALE = "stale"
DOWN = "down"

WATCH_DOOR = ("bin", "syn-watch.sh")


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

    @property
    def lease(self) -> Path:
        return self.state / ".arm.lease"

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


def write_lease(
    paths: ArmPaths,
    *,
    pid: int,
    mode: str,
    session: str,
    generation: int,
    now: float | None = None,
    stat_reader: Callable[[int], str] | None = None,
) -> bool:
    """Write the lease atomically; a torn lease is a lying one."""
    starttime = proc.proc_starttime(pid, stat_reader=stat_reader or proc._proc_stat) or "0"
    stamp = int(now if now is not None else time.time())
    body = (
        f"pid={pid} starttime={starttime} gen={generation} mode={mode} "
        f"session={session} heartbeat={stamp} state={paths.state}\n"
    )
    paths.state.mkdir(parents=True, exist_ok=True)
    temporary = paths.lease.with_name(f"{paths.lease.name}.{pid}")
    try:
        temporary.write_text(body, encoding="utf-8")
        temporary.replace(paths.lease)
    except OSError:
        return False
    return True


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

    The lock law is Gleipnir's (`bin/gleipnir-lock-lib.sh`): the machine-global
    lock for the primary, the per-home lock for an Eindri-home, the legacy path
    honoured for a session that started before the contract. This module does not
    re-derive it — it asks the library, exactly as the bash arm did.
    """
    library = paths.root / "bin" / "gleipnir-lock-lib.sh"
    if not library.is_file():
        return "none"
    script = "\n".join(
        [
            f'. "{library}" 2>/dev/null || exit 1',
            "gleipnir_lock_owner _ymir_owner 2>/dev/null || true",
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


def raise_line(paths: ArmPaths) -> str:
    """The ONE actionable line the arm owes, or "" when nothing is due.

    Order is the contract the harvest calls rely on: the durable wake queue
    first (one signal per DISTINCT content — an unconsumed queue must never
    re-inject on every poll), then the one-shot triggers, then the operator's
    stop request.
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
    now: float | None = None,
    stat_reader: Callable[[int], str] | None = None,
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
    lease = read_lease(paths.lease)
    generation = int(lease["gen"]) if lease.get("gen", "").isdigit() else 0
    write_lease(
        paths, pid=mine, mode=mode, session=session, generation=generation, now=now, stat_reader=stat_reader
    )
    sweep_handoff(paths, env=env, runner=runner)
    line = raise_line(paths)
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


def sweep_handoff(paths: ArmPaths, *, env: Mapping[str, str], runner: proc.Runner = proc.run) -> None:
    """The mid-session sweep: a filed report becomes a wake within seconds.

    `bin/agents/eindri-handoff.sh` owns the shelf scan and its ledger; this only points
    it at the SAME state dir the arm watches.
    """
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
        pid = lease.get("pid", "")
        session = lease.get("session", "none")
    else:
        mode = "none"
        pid = ""
        session = session_owner(paths, env=env, runner=runner, stat_reader=stat_reader)
    armed = "yes" if paths.armed.exists() else "no"
    cells = [
        state,
        mode,
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
        "syn-watch[1]{state,mode,unit,pid,heartbeat_age,stale_seconds,session,armed,state_dir}:\n"
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
                say_err(f"could not materialize {paths.unit} (bin/fleet-ensure.sh unit syn-watch)")
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
    install = signal_installer or _install_traps
    install(lambda: release_lease(paths, pid=mine))
    if not write_lease(paths, pid=mine, mode=mode, session="none", generation=generation, stat_reader=stat_reader):
        say_err(f"cannot write lease {paths.lease}")
        return 1
    for marker in (paths.armed, paths.heartbeat):
        try:
            marker.touch()
        except OSError:
            pass
    say_err(f"arm up pid={mine} gen={generation} mode={mode} state={paths.state}")

    while True:
        line = cycle(
            paths,
            env=env,
            runner=runner,
            mode=mode,
            pid=mine,
            emit=emit,
            stat_reader=stat_reader,
        )
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
            "remedy: bin/syn-watch.sh start",
        ]
    if state == STALE:
        return [
            "syn-watch: the arm is STALE — heartbeat age "
            f"{heartbeat_age(paths)}s exceeds {paths.stale_seconds}s",
            "remedy: bin/syn-watch.sh restart",
        ]
    return []
