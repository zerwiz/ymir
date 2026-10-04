"""The engine's door face — `python3 -m ymir_runtime <verb>`.

The bash doors (`bin/engine/ymir-engine.sh`, and through it `bin/agents/eindri-start.sh` and
`bin/agents/einherjar-spawn.sh`) call THIS, never the modules directly. It exists so the
four verbs are reachable from a shell without a second interface — plus
`dispatch`, which resolves an errand to its role, figure, model and seat type
without adding a fifth verb to the interface.

Exit codes are part of the contract:
  0  the verb ran
  1  the engine tried and failed
  2  usage
  4  the engine will NOT own this errand — the caller keeps the old road

`--compat` prints the exact `spawned …` line the old door prints, so a caller
that only parses text sees no change.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Mapping, Sequence

from . import __version__, heartbeat, landed as landed_mod, paths, proc, watch
from .dispatch import ModelUnavailable, TableRefusal
from .dispatch import resolve as resolve_dispatch
from .errors import EngineError, EngineRefusal, SeatNotFound
from .seat import Errand, seat
from .send import send
from .status import SeatState, status
from .stop import stop

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_USAGE = 2
EXIT_CANNOT_OWN = 4

CANNOT_OWN = EXIT_CANNOT_OWN


def _row(header: str, cells: Sequence[str]) -> str:
    body = ",".join(f'"{cell}"' for cell in cells)
    return f"{header}:\n  {body}\n"


def _add_errand_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--project", default="", help="the git working tree the worktree is cut from")
    parser.add_argument("--request", default="", help="the errand text when no brief file exists")
    parser.add_argument("--brief", default="", help="an explicit brief file")
    parser.add_argument("--lock", default="", help="a local-model lock to wrap the launch in")
    parser.add_argument("--kind", default="ship", choices=("ship", "scout"))
    parser.add_argument("--mode", default="direct-PR", help="direct-PR | local-only | no-mistakes")
    parser.add_argument("--yolo", default="off")
    parser.add_argument("--harness", default="")
    parser.add_argument("--model", default="")
    parser.add_argument("--effort", default="")
    parser.add_argument("--backend", default="", choices=("", "tmux", "herdr"))
    parser.add_argument("--isolation", default="auto", choices=("auto", "herdr", "utgard", "on", "off"))
    parser.add_argument("--role", default="")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--worth-a-smith", default="unknown")
    parser.add_argument("--worth-why", default="not consulted by the engine")
    parser.add_argument("--compat", action="store_true", help="print the old door's `spawned …` line")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ymir_runtime", description="THE ENGINE — one interface, four verbs")
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="verb", required=True)

    sub.add_parser("version", help="print the engine version")

    sub.add_parser("watch", help="Sýn — the standing arm's own verbs (status|start|stop|restart|run)")

    ensure = sub.add_parser("ensure", help="report the interpreter and roots the engine will use")
    ensure.add_argument("--toon", action="store_true")

    seat_p = sub.add_parser("seat", help="seat an errand end to end")
    seat_p.add_argument("task_id")
    _add_errand_flags(seat_p)

    dispatch_p = sub.add_parser(
        "dispatch",
        help="resolve an errand to its role, figure, tools, model and seat",
    )
    dispatch_p.add_argument("target", nargs="?", default="", help="a role key or a figure name")
    dispatch_p.add_argument("--task", default="", help="errand text; the roles table chooses the smith")
    dispatch_p.add_argument("--brief", default="", help="a brief whose Isolation: line names the seat type")
    dispatch_p.add_argument("--kind", default="ship", choices=("ship", "scout"))
    dispatch_p.add_argument("--effort", default="")
    dispatch_p.add_argument("--isolation", default="", choices=("", "herdr", "utgard"))
    dispatch_p.add_argument("--toon", action="store_true")

    status_p = sub.add_parser("status", help="report a seat's state")
    status_p.add_argument("seat_id")
    status_p.add_argument("--window", type=int, default=heartbeat.WINDOW_SECONDS)
    status_p.add_argument("--toon", action="store_true")

    send_p = sub.add_parser("send", help="deliver text to a seat")
    send_p.add_argument("seat_id")
    send_p.add_argument("text")

    stop_p = sub.add_parser("stop", help="reap a seat")
    stop_p.add_argument("seat_id")
    stop_p.add_argument("--remove-worktree", action="store_true")
    stop_p.add_argument("--require-landed", action="store_true", help="refuse to remove a worktree whose work has not landed")
    stop_p.add_argument("--force", action="store_true")

    landed_p = sub.add_parser("landed", help="did this work LAND? — the teardown gate")
    landed_p.add_argument("worktree")
    landed_p.add_argument("--branch", default="")
    landed_p.add_argument("--pr", default="")
    landed_p.add_argument("--mode", default="")
    landed_p.add_argument("--force", action="store_true")
    return parser


def main(
    argv: Sequence[str] | None = None,
    *,
    runner: proc.Runner | None = None,
    probe=None,
    env: Mapping[str, str] | None = None,
) -> int:
    """The door's entry. The injections exist so the CLI's own contract is
    assertable without a pane, exactly as the modules' is."""
    arguments = list(argv) if argv is not None else sys.argv[1:]
    # The arm's own surface (`watch status|start|stop|restart|run`), dispatched
    # before argparse: the verb carries its own flags through to `bin/syn-watch.sh`
    # unchanged, and the shape of `run --emit` must not be re-spelled here.
    if arguments[:1] == ["watch"]:
        return watch.main(
            arguments[1:], env=env, runner=runner or proc.run, probe=probe or proc.which
        )
    args = build_parser().parse_args(arguments)
    run = runner or proc.run
    lookup = probe or proc.which

    if args.verb == "version":
        print(__version__)
        return EXIT_OK

    if args.verb == "ensure":
        roots = paths.resolve(env)
        print(_row("engine[1]{python,state,data,config,root,wt_root}", [
            sys.executable, str(roots.state), str(roots.data), str(roots.config),
            str(roots.root), str(roots.wt_root),
        ]), end="")
        return EXIT_OK

    if args.verb == "status":
        try:
            state = status(args.seat_id, window=args.window, env=env, runner=run, probe=lookup)
        except EngineError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return EXIT_FAILED
        if args.toon:
            print(_row(f"status[1]{{seat,state}}", [args.seat_id, state.value]), end="")
        else:
            print(state.value)
        return EXIT_OK if state is not SeatState.IDLE else EXIT_FAILED

    if args.verb == "send":
        try:
            result = send(args.seat_id, args.text, env=env, runner=run, probe=lookup)
        except EngineError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return EXIT_FAILED
        print(_row("send[1]{seat,message,poked,detail}", [
            result.seat_id, str(result.message), "yes" if result.poked else "no", result.detail,
        ]), end="")
        return EXIT_OK

    if args.verb == "landed":
        verdict = landed_mod.gate(
            args.worktree,
            branch=args.branch,
            pr_url=args.pr,
            mode=args.mode,
            force=args.force,
            runner=run,
            env=env,
        )
        print(_row("landed[1]{worktree,landed,how,detail}", [
            args.worktree, "yes" if verdict.landed else "no", verdict.how, verdict.detail,
        ]), end="")
        return EXIT_OK if verdict.landed else EXIT_FAILED

    if args.verb == "stop":
        try:
            result = stop(
                args.seat_id, remove_worktree=args.remove_worktree, force=args.force,
                require_landed=args.require_landed, env=env, runner=run, probe=lookup,
            )
        except SeatNotFound as exc:
            print(f"error: {exc}", file=sys.stderr)
            return EXIT_FAILED
        except EngineError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return EXIT_FAILED
        print(_row("stop[1]{seat,backend,target,reaped,worktree_removed,detail}", [
            result.seat_id, result.backend, result.target,
            "yes" if result.reaped else "no",
            "yes" if result.worktree_removed else "no",
            result.detail,
        ]), end="")
        return EXIT_OK if result.reaped else EXIT_FAILED

    if args.verb == "dispatch":
        brief_text = ""
        if args.brief:
            brief_path = Path(args.brief).expanduser()
            if not brief_path.is_file():
                print(f"error: brief not found: {brief_path}", file=sys.stderr)
                return EXIT_FAILED
            brief_text = brief_path.read_text(encoding="utf-8", errors="replace")
        try:
            resolution = resolve_dispatch(
                role=args.target,
                task=args.task,
                brief=brief_text,
                kind=args.kind,
                effort=args.effort,
                isolation=args.isolation,
                env=env,
            )
        except (TableRefusal, ModelUnavailable) as exc:
            print(f"refused: {exc}", file=sys.stderr)
            return EXIT_FAILED
        if args.toon:
            print(
                _row(
                    "dispatch[1]{role,figure,craft,tools,harness,model,seat,kind}",
                    resolution.as_row(),
                ),
                end="",
            )
        else:
            print(
                _row(
                    "dispatch[1]{role,figure,tools,harness,model,seat,kind}",
                    (
                        resolution.role,
                        resolution.figure,
                        resolution.tools_cell(),
                        resolution.harness,
                        resolution.model,
                        resolution.seat,
                        resolution.kind,
                    ),
                ),
                end="",
            )
        return EXIT_OK

    if args.verb == "seat":
        errand = Errand(
            task_id=args.task_id,
            project_dir=args.project,
            request=args.request,
            kind=args.kind,
            mode=args.mode,
            yolo=args.yolo,
            harness=args.harness,
            model=args.model,
            effort=args.effort,
            backend=args.backend,
            isolation=args.isolation,
            brief=args.brief,
            lock=args.lock,
            force=args.force,
            role=args.role,
            worth_a_smith=args.worth_a_smith,
            worth_why=args.worth_why,
        )
        try:
            seat_id = seat(errand, runner=run, env=env, probe=lookup)
        except EngineRefusal as exc:
            print(f"engine-cannot-own: {exc.reason}", file=sys.stderr)
            if exc.remedy:
                print(f"help: {exc.remedy}", file=sys.stderr)
            return EXIT_CANNOT_OWN
        except EngineError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return EXIT_FAILED

        roots = paths.resolve(env)
        meta = heartbeat.read_meta(roots.state, seat_id)
        if args.compat:
            kind = meta.get("kind", args.kind)
            if kind == "ship":
                print(
                    f"spawned {seat_id} harness={meta.get('harness', '')} kind={kind} "
                    f"mode={meta.get('mode', '')} yolo={meta.get('yolo', 'off')} "
                    f"backend={meta.get('backend', '')} target={meta.get('window', '')} "
                    f"worktree={meta.get('worktree', '')} isolation={meta.get('isolation', '')}"
                )
            else:
                print(
                    f"spawned {seat_id} harness={meta.get('harness', '')} kind={kind} "
                    f"backend={meta.get('backend', '')} target={meta.get('window', '')} "
                    f"worktree={meta.get('worktree', '')} isolation={meta.get('isolation', '')}"
                )
        else:
            print(_row("seat[1]{id,harness,model,backend,target,worktree,isolation,engine}", [
                seat_id, meta.get("harness", ""), meta.get("model", ""), meta.get("backend", ""),
                meta.get("window", ""), meta.get("worktree", ""), meta.get("isolation", ""),
                meta.get("engine", ""),
            ]), end="")
        return EXIT_OK

    print(f"error: unknown verb {args.verb}", file=sys.stderr)
    return EXIT_USAGE


if __name__ == "__main__":  # pragma: no cover - the door's entry
    raise SystemExit(main())
