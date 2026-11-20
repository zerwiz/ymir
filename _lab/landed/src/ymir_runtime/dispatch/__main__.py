"""`python3 -m ymir_runtime.dispatch` — the door face of the decision table.

The dispatch layer is a LAYER beside the four verbs, as the config layer is, so
it keeps its own module CLI and adds no verb to `seat · status · send · stop`.
The engine's own door (`bin/engine/ymir-engine.sh`) passes its verb straight through.

    python3 -m ymir_runtime.dispatch resolve --role developer [--brief FILE] [--toon]
    python3 -m ymir_runtime.dispatch resolve --task "fix the bug" --kind ship
    python3 -m ymir_runtime.dispatch roles
    python3 -m ymir_runtime.dispatch choose "<task text>"
    python3 -m ymir_runtime.dispatch request "<model request>"

Exit: 0 resolved · 1 a refusal (unknown role/figure, absent hoard config, an
unresolved model request) · 2 usage.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Sequence

from .registry import HoardModels, ModelUnavailable
from .resolve import Resolution, resolve
from .table import TableRefusal, read as read_table

EXIT_OK = 0
EXIT_REFUSED = 1
EXIT_USAGE = 2


def _row(header: str, cells: Sequence[str]) -> str:
    body = ",".join(f'"{cell}"' for cell in cells)
    return f"{header}:\n  {body}\n"


def _table(header: str, rows: list[Sequence[str]]) -> str:
    body = "\n".join("  " + ",".join(f'"{cell}"' for cell in row) for row in rows)
    return f"{header}:\n{body}\n"


def _print_resolution(resolution: Resolution, *, toon: bool) -> None:
    if toon:
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
                "dispatch[1]{role,figure,harness,model,seat,kind}",
                (
                    resolution.role,
                    resolution.figure,
                    resolution.harness,
                    resolution.model,
                    resolution.seat,
                    resolution.kind,
                ),
            ),
            end="",
        )


def _resolve(args: argparse.Namespace) -> int:
    brief = ""
    if args.brief:
        path = Path(args.brief).expanduser()
        if not path.is_file():
            print(f"error: brief not found: {path}", file=sys.stderr)
            return EXIT_REFUSED
        brief = path.read_text(encoding="utf-8", errors="replace")
    resolution = resolve(
        role=args.role,
        task=args.task,
        brief=brief,
        kind=args.kind,
        effort=args.effort,
        isolation=args.isolation,
        model_request=args.request,
        root=args.root or None,
    )
    _print_resolution(resolution, toon=args.toon)
    return EXIT_OK


def _roles(args: argparse.Namespace) -> int:
    table = read_table(args.root or None)
    rows = [
        (role.name, role.figure, role.craft, "yes" if role.dispatch else "no", " ".join(role.tools))
        for role in table.roles
    ]
    print(_table(f"dispatch-roles[{len(rows)}]{{role,figure,craft,dispatch,tools}}", rows), end="")
    return EXIT_OK


def _choose(args: argparse.Namespace) -> int:
    if not args.text:
        print("error: choose needs task text", file=sys.stderr)
        return EXIT_USAGE
    table = read_table(args.root or None)
    role, score = table.choose(" ".join(args.text))
    print(_row("dispatch-choice[1]{role,figure,score}", (role.name, role.figure, str(score))), end="")
    return EXIT_OK


def _request(args: argparse.Namespace) -> int:
    if not args.text:
        print("error: request needs model text", file=sys.stderr)
        return EXIT_USAGE
    answer = HoardModels(root=args.root or None).request(" ".join(args.text))
    if not answer.resolved:
        print(_row("dispatch-request[1]{request,resolution}", (answer.request, "unresolved")), end="")
        return EXIT_REFUSED
    print(
        _row(
            "dispatch-request[1]{request,locality,harness,provider,model,confidence}",
            (answer.request, answer.locality, answer.harness, answer.provider, answer.model, answer.confidence),
        ),
        end="",
    )
    return EXIT_OK


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ymir_runtime.dispatch",
        description="resolve an errand to its role, figure, tools, model and seat (plan 58)",
    )
    parser.add_argument("--version", action="version", version="1.0.0")
    parser.add_argument("mode", nargs="?", default="resolve", choices=("resolve", "roles", "choose", "request"))
    parser.add_argument("text", nargs="*", help="task text (choose) or model request (request)")
    parser.add_argument("--role", default="", help="a role key or a figure name")
    parser.add_argument("--task", default="", help="errand text; the table chooses the smith")
    parser.add_argument("--brief", default="", help="a brief file whose Isolation: line names the seat")
    parser.add_argument("--kind", default="ship", choices=("ship", "scout"))
    parser.add_argument("--effort", default="")
    parser.add_argument("--isolation", default="", choices=("", "herdr", "utgard"))
    parser.add_argument("--request", default="", help="a model request resolved by bin/model/model-resolve.sh")
    parser.add_argument("--root", default="", help="the code tree holding .agents/roles.yaml (tests)")
    parser.add_argument("--toon", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(list(argv) if argv is not None else None)
    handlers = {"resolve": _resolve, "roles": _roles, "choose": _choose, "request": _request}
    try:
        return handlers[args.mode](args)
    except (TableRefusal, ModelUnavailable) as exc:
        print(f"refused: {exc}", file=sys.stderr)
        return EXIT_REFUSED


if __name__ == "__main__":  # pragma: no cover - the door's entry
    raise SystemExit(main())
