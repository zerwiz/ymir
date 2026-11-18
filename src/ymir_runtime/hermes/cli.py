"""`python3 -m ymir_runtime.hermes <verb>` — the one entry the launchers, the cron script and `ymir` call.

Exit codes: 0 done · 1 failed, drift or red · 2 usage. A refusal prints `error: <why>` and
`help: <remedy>` on stderr — never a success line.
"""

from __future__ import annotations

import argparse
import os
import sys
from typing import Sequence

from . import VERSION
from . import common as C


def _parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="ymir hermes", description="Ymir's Hermes surfaces (plan 317).")
    ap.add_argument("--version", action="version", version=VERSION)
    sub = ap.add_subparsers(dest="verb", required=True)

    s = sub.add_parser("seat", help="seat Ymir's doors, skills shelf and worker script in Hermes")
    g = s.add_mutually_exclusive_group()
    g.add_argument("--check", action="store_true", help="compare VALUES; exit 1 naming each drifted entry")
    g.add_argument("--dry-run", action="store_true", help="print the diff; write nothing")
    g.add_argument("--apply", action="store_true", help=argparse.SUPPRESS)   # the old launcher's word

    sub.add_parser("doctor", help="one row per surface, four states per door; exit 0 only when all answer")

    w = sub.add_parser("wait-worker", help="a finished herdr worker wakes the session that asked")
    w.add_argument("--session", default="", help="the Hermes session to wake (default: $HERMES_SESSION_ID)")
    w.add_argument("--worker", action="append", default=[], help="a herdr agent name to wait for (repeatable)")
    w.add_argument("--handoff", action="append", default=[], help="NAME=PATH, when the handoff is not in the pane's tree")
    w.add_argument("--prefix", default=os.environ.get("YMIR_WAIT_PREFIX", "w-"),
                   help="which herdr agents are workers when none is named (default w-)")
    w.add_argument("--poll", type=float, default=60.0)
    w.add_argument("--limit", type=float, default=6 * 3600.0)
    w.add_argument("--include-finished", action="store_true",
                   help="a worker already finished when the wait starts also counts")
    mode = w.add_mutually_exclusive_group()
    mode.add_argument("--once", action="store_true", help="check now, print, never wait (the cron's note)")
    mode.add_argument("--foreground", action="store_true", help="be the waiter (what the supervised unit runs)")
    w.add_argument("--cron", action="store_true", help="with --once: print nothing when nothing finished")
    w.add_argument("--scope", default="cron", help="with --once: whose seen-set to use (default cron)")

    sub.add_parser("session-hook", help="Hermes' shell-hook wire (JSON on stdin, JSON on stdout)")
    return ap


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(list(sys.argv[1:] if argv is None else argv))
    env = C.environ(None)
    try:
        if args.verb == "seat":
            from .seat import seat
            return seat(env, check=args.check, dry_run=args.dry_run)
        if args.verb == "doctor":
            from .doctor import doctor
            return doctor(env)
        if args.verb == "session-hook":
            from .session_hook import main as hook_main
            return hook_main(env)
        if args.verb == "wait-worker":
            from . import wait_worker as W
            if args.once:
                return W.once(env, scope=args.scope, cron=args.cron, prefix=args.prefix, names=args.worker)
            session = W.resolve_session(env, args.session)
            handoffs = W.parse_handoffs(args.handoff)
            kw = dict(session=session, prefix=args.prefix, names=args.worker, poll=args.poll,
                      limit=args.limit, include_finished=args.include_finished, handoffs=handoffs)
            if args.foreground:
                return W.foreground(env, **kw)
            return W.supervise(env, **kw)
    except C.HermesError as exc:
        print(f"error: {exc.reason}", file=sys.stderr)
        if exc.remedy:
            print(f"help: {exc.remedy}", file=sys.stderr)
        return 1
    return 2
