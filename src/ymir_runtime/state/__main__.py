"""`python3 -m ymir_runtime.state` — the door the shims call.

The bash libraries (`bin/gleipnir-lock-lib.sh`, `bin/records/runes-append.sh`,
`bin/time/brokk-wake-lib.sh`) never re-implement a rule; they resolve the interpreter
and hand the verb here. Exit codes are part of the shim contract:

  0  the verb ran (for `pid-alive` / `is-eindri-home`: the condition is TRUE)
  1  the verb ran and the condition is FALSE, or the state file could not be
     written
  2  usage

The shell's `$$` is passed in with `--shell-pid`, so the session pid is resolved
exactly as the shell library resolved it, never as this short-lived Python.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Sequence

from . import envelope as envelope_mod
from . import lock as lock_mod
from . import queue as queue_mod
from . import runes as runes_mod

EXIT_OK = 0
EXIT_NO = 1
EXIT_USAGE = 2


def _shell_pid(args: argparse.Namespace) -> int | None:
    return getattr(args, "shell_pid", None)


def _lock_parser(sub: argparse._SubParsersAction) -> None:
    lock = sub.add_parser("lock", help="the session lock (Gleipnir)")
    verbs = lock.add_subparsers(dest="lock_verb", required=True)
    for name in (
        "state-dir",
        "lock-path",
        "machine-state-dir",
        "legacy-lock-path",
        "pointer-path",
        "hoard-state-dir",
        "owner",
    ):
        verbs.add_parser(name)
    alive = verbs.add_parser("pid-alive")
    alive.add_argument("pid")
    alive.add_argument("expect", nargs="?", default="")
    starttime = verbs.add_parser("proc-starttime")
    starttime.add_argument("pid")
    rest = verbs.add_parser("proc-stat-rest")
    rest.add_argument("pid")
    for name in ("session-pid", "owned", "acquire", "release"):
        parser = verbs.add_parser(name)
        parser.add_argument("--shell-pid", type=int, default=None)
    verbs.add_parser("reap")
    verbs.add_parser("is-eindri-home")
    inspect = verbs.add_parser("inspect")
    inspect.add_argument("--toon", action="store_true")
    pointer = verbs.add_parser("write-pointer")
    pointer.add_argument("path")
    legacy = verbs.add_parser("drop-legacy")
    legacy.add_argument("want_pid")


def _runes_parser(sub: argparse._SubParsersAction) -> None:
    runes = sub.add_parser("runes", help="the append-only chained ledger")
    verbs = runes.add_subparsers(dest="runes_verb", required=True)
    append = verbs.add_parser("append")
    append.add_argument("actor")
    append.add_argument("event")
    append.add_argument("--order", default="")
    append.add_argument("--realm", default="")
    append.add_argument("--message", required=True)
    append.add_argument("--timestamp", default="")
    append.add_argument("--ledger", default="")
    append.add_argument("--lock", default="")
    verbs.add_parser("path")
    verbs.add_parser("lock-path")
    checksum = verbs.add_parser("last-checksum")
    checksum.add_argument("--ledger", default="")
    verify = verbs.add_parser("verify")
    verify.add_argument("--ledger", default="")


def _queue_parser(sub: argparse._SubParsersAction) -> None:
    queue = sub.add_parser("queue", help="the durable wake queue")
    verbs = queue.add_subparsers(dest="queue_verb", required=True)
    append = verbs.add_parser("append")
    append.add_argument("kind")
    append.add_argument("key")
    append.add_argument("payload")
    append.add_argument("--queue", default="")
    append.add_argument("--epoch", type=int, default=None)
    append.add_argument("--assume-locked", action="store_true")
    for name in ("keys", "read", "pending"):
        parser = verbs.add_parser(name)
        parser.add_argument("--queue", default="")
        if name == "keys":
            parser.add_argument("kind")
    ack = verbs.add_parser("ack")
    ack.add_argument("--queue", default="")


def _envelope_parser(sub: argparse._SubParsersAction) -> None:
    envelope = sub.add_parser("envelope", help="the durable wrapper state files travel in")
    verbs = envelope.add_subparsers(dest="envelope_verb", required=True)
    read = verbs.add_parser("read")
    read.add_argument("path")
    read.add_argument("--kind", default="")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="python3 -m ymir_runtime.state")
    parser.add_argument("--version", action="store_true")
    sub = parser.add_subparsers(dest="group")
    _lock_parser(sub)
    _runes_parser(sub)
    _queue_parser(sub)
    _envelope_parser(sub)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)

    if getattr(args, "version", False):
        from .. import __version__

        print(__version__)
        return EXIT_OK
    if not args.group:
        parser.print_help(sys.stderr)
        return EXIT_USAGE

    handler = {
        "lock": _lock,
        "runes": _runes,
        "queue": _queue,
        "envelope": _envelope,
    }[args.group]
    return handler(args)


def _lock(args: argparse.Namespace) -> int:
    verb = args.lock_verb
    shell = _shell_pid(args)
    path_verbs = {
        "state-dir": lock_mod.state_dir,
        "lock-path": lock_mod.lock_path,
        "machine-state-dir": lock_mod.machine_state_dir,
        "legacy-lock-path": lock_mod.legacy_lock_path,
        "pointer-path": lock_mod.pointer_path,
        "hoard-state-dir": lock_mod.hoard_state_dir,
    }
    if verb in path_verbs:
        print(path_verbs[verb]())
        return EXIT_OK
    if verb == "owner":
        print(lock_mod.lock_owner())
        return EXIT_OK
    if verb == "pid-alive":
        return EXIT_OK if lock_mod.pid_alive(args.pid, args.expect) else EXIT_NO
    if verb == "proc-starttime":
        value = lock_mod.proc_starttime(args.pid)
        if value is None:
            return EXIT_NO
        print(value)
        return EXIT_OK
    if verb == "proc-stat-rest":
        value = lock_mod.proc_stat_rest(args.pid)
        if value is None:
            return EXIT_NO
        print(value.strip())
        return EXIT_OK
    if verb == "session-pid":
        print(lock_mod.session_pid(shell_pid=shell))
        return EXIT_OK
    if verb == "owned":
        return EXIT_OK if lock_mod.lock_owned(shell_pid=shell) else EXIT_NO
    if verb == "acquire":
        return EXIT_OK if lock_mod.acquire(shell_pid=shell) else EXIT_NO
    if verb == "release":
        lock_mod.release(shell_pid=shell)
        return EXIT_OK
    if verb == "reap":
        lock_mod.reap()
        return EXIT_OK
    if verb == "is-eindri-home":
        return EXIT_OK if lock_mod.is_eindri_home() else EXIT_NO
    if verb == "inspect":
        state = lock_mod.inspect()
        if args.toon:
            print(
                "lock[1]{state,lock,legacy,pointer,machine,eindri}:\n"
                f'  "{state.state_dir}","{state.lock_path}","{state.legacy_lock_path}",'
                f'"{state.pointer_path}","{state.machine_state_dir}","{str(state.eindri_home).lower()}"'
            )
        else:
            print(state.lock_path)
        return EXIT_OK
    if verb == "write-pointer":
        lock_mod.write_pointer(Path(args.path))
        return EXIT_OK
    if verb == "drop-legacy":
        lock_mod.drop_legacy(args.want_pid)
        return EXIT_OK
    return EXIT_USAGE


def _runes(args: argparse.Namespace) -> int:
    verb = args.runes_verb
    if verb == "path":
        print(runes_mod.file_path())
        return EXIT_OK
    if verb == "lock-path":
        print(runes_mod.lock_path())
        return EXIT_OK
    ledger = Path(args.ledger) if args.ledger else None
    if verb == "last-checksum":
        print(runes_mod.last_checksum(ledger or runes_mod.file_path()))
        return EXIT_OK
    if verb == "verify":
        ok, detail = runes_mod.verify(ledger or runes_mod.file_path())
        print(detail)
        return EXIT_OK if ok else EXIT_NO
    if verb == "append":
        try:
            rune = runes_mod.append(
                args.actor,
                args.event,
                args.message,
                order=args.order,
                realm=args.realm,
                ledger=ledger,
                lock=Path(args.lock) if args.lock else None,
                timestamp=args.timestamp or None,
            )
        except OSError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return EXIT_NO
        print(
            f"runes: appended actor={args.actor} event={args.event} "
            f"order={args.order or 'none'} checksum={rune.checksum}"
        )
        return EXIT_OK
    return EXIT_USAGE


def _queue(args: argparse.Namespace) -> int:
    verb = args.queue_verb
    path = Path(args.queue) if getattr(args, "queue", "") else None
    q = queue_mod.WakeQueue.resolve(path=path)
    if verb == "append":
        try:
            q.append(
                args.kind,
                args.key,
                args.payload,
                epoch=args.epoch,
                assume_locked=args.assume_locked,
            )
        except (ValueError, OSError) as exc:
            print(f"error: {exc}", file=sys.stderr)
            return EXIT_NO
        return EXIT_OK
    if verb == "keys":
        try:
            for key in q.queued_keys(args.kind):
                print(key)
        except ValueError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return EXIT_NO
        return EXIT_OK
    if verb == "read":
        for wake in q.read():
            print(wake.to_line())
        return EXIT_OK
    if verb == "pending":
        print(q.pending())
        return EXIT_OK
    if verb == "ack":
        q.acknowledge()
        return EXIT_OK
    return EXIT_USAGE


def _envelope(args: argparse.Namespace) -> int:
    if args.envelope_verb == "read":
        try:
            record = envelope_mod.Envelope.read_meta(Path(args.path), kind=args.kind)
        except OSError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return EXIT_NO
        for key, value in record.payload.items():
            print(f"{key}={value}")
        return EXIT_OK
    return EXIT_USAGE


if __name__ == "__main__":  # pragma: no cover - the door's entry
    raise SystemExit(main())
