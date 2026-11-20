"""`python3 -m ymir_runtime.fleet` — the door face of the living rail resolver.

    python3 -m ymir_runtime.fleet resolve [alias] [--json]
    python3 -m ymir_runtime.fleet status  [--json]

`resolve` answers WHERE the models come from right now — the first alive strong
box in the registry's rank order, its OpenAI-compatible URL, and the shared key
as a REFERENCE. `status` prints the whole ranked live set (so a dropped box is
visible, not hidden). Both read the private registry at runtime; a registry that
names no strong box, or a fleet with every rail down, is a DECLINED answer — exit
1, never a fake URL.

Exit: 0 answered · 1 declined · 2 usage.
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Sequence

from .rail import KEY_REF, Resolution, resolve, status

EXIT_OK = 0
EXIT_DECLINED = 1
EXIT_USAGE = 2


def _cell(value: object) -> str:
    return json.dumps(str(value), ensure_ascii=False)


def _row(header: str, cells: Sequence[object]) -> str:
    return f"{header}:\n  {','.join(_cell(cell) for cell in cells)}\n"


def _table(header: str, rows: list[Sequence[object]]) -> str:
    body = "\n".join("  " + ",".join(_cell(cell) for cell in row) for row in rows)
    return f"{header}:\n{body}\n"


def _serving_row(resolution: Resolution, alias: str = "") -> str:
    serving = resolution.serving
    if serving is None:
        return _row(
            "rail_serving[1]{host,url,key_ref,alias,alias_verified}",
            ("", "", KEY_REF, alias, "declined"),
        )
    return _row(
        "rail_serving[1]{host,url,key_ref,alias,alias_verified}",
        (
            serving.host,
            serving.url,
            serving.key_ref,
            serving.alias,
            "yes" if serving.alias_verified else "no",
        ),
    )


def _key_row(resolution: Resolution) -> str:
    return _row("rail_key[1]{reference,source}", (KEY_REF, resolution.key_source))


def _declined_row(resolution: Resolution) -> str:
    return _row(
        "rail_declined[1]{reason,help}",
        (
            resolution.reason,
            "check the tailnet and the rail (:8080); the registry's strong boxes are the only answers",
        ),
    )


def _live_rows(resolution: Resolution) -> str:
    live = resolution.live
    if not live:
        return ""
    return _table(
        f"rail_live[{len(live)}]{{host,url,order,reason}}",
        [(rail.host, rail.url, rail.order, rail.reason) for rail in live],
    )


def _status_rows(resolution: Resolution) -> str:
    rails = resolution.rails
    if not rails:
        return ""
    return _table(
        f"rail_status[{len(rails)}]{{host,address,url,live,order,reason}}",
        [
            (rail.host, rail.address, rail.url, "yes" if rail.live else "no", rail.order, rail.reason)
            for rail in rails
        ],
    )


def _json_view(resolution: Resolution) -> str:
    serving = resolution.serving
    return json.dumps(
        {
            "serving": None
            if serving is None
            else {
                "host": serving.host,
                "url": serving.url,
                "key_ref": serving.key_ref,
                "alias": serving.alias,
                "alias_verified": serving.alias_verified,
                "models": list(serving.models),
            },
            "rails": [
                {
                    "host": rail.host,
                    "address": rail.address,
                    "base": rail.base,
                    "url": rail.url,
                    "live": rail.live,
                    "order": rail.order,
                    "reason": rail.reason,
                    "models": list(rail.models),
                    "key_gated": rail.key_gated,
                    "roles": list(rail.roles),
                }
                for rail in resolution.rails
            ],
            "key_ref": KEY_REF,
            "key_source": resolution.key_source,
            "reason": resolution.reason,
        },
        indent=2,
    )


def _common(args: argparse.Namespace) -> dict:
    return {
        "registry": args.registry or None,
        "self_host": args.host or None,
        "port": args.port if args.port and args.port > 0 else None,
        "timeout": args.timeout if args.timeout and args.timeout > 0 else None,
    }


def _run_resolve(args: argparse.Namespace) -> int:
    resolution = resolve(args.alias or "", **_common(args))
    if args.json:
        print(_json_view(resolution))
    else:
        print(_serving_row(resolution, args.alias or ""), end="")
        print(_live_rows(resolution), end="")
        print(_key_row(resolution), end="")
        if resolution.declined:
            print(_declined_row(resolution), end="")
    return EXIT_DECLINED if resolution.declined else EXIT_OK


def _run_status(args: argparse.Namespace) -> int:
    resolution = status(**_common(args))
    if args.json:
        print(_json_view(resolution))
        return EXIT_OK
    print(_status_rows(resolution), end="")
    print(_serving_row(resolution), end="")
    print(_key_row(resolution), end="")
    if resolution.declined:
        print(_declined_row(resolution), end="")
    return EXIT_OK


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="ymir_runtime.fleet",
        description="resolve the fleet's living rail — where the models come from now (plan 51 Parts 9a/9b/9c)",
    )
    parser.add_argument("--version", action="version", version="1.0.0")
    parser.add_argument("mode", nargs="?", default="resolve", choices=("resolve", "status"))
    parser.add_argument("alias", nargs="?", default="", help="a model alias to verify on the serving rail")
    parser.add_argument("--registry", default="", help="the fleet registry (default $YMIR_HOME/hodd/data/fleet.json)")
    parser.add_argument("--host", default="", help="this box's fleet name (default YMIR_HOST / hostname)")
    parser.add_argument("--port", type=int, default=0, help="the rail port (default 8080)")
    parser.add_argument("--timeout", type=float, default=0.0, help="per-probe seconds (default 2)")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(list(argv) if argv is not None else None)
    handlers = {"resolve": _run_resolve, "status": _run_status}
    try:
        return handlers[args.mode](args)
    except KeyboardInterrupt:  # pragma: no cover - a door's interrupt
        return EXIT_USAGE


if __name__ == "__main__":  # pragma: no cover - the door's entry
    raise SystemExit(main())
