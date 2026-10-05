"""`python3 -m ymir_runtime.config` — the door face of the config layer.

Plan 58, Phase 7. This keeps the config check callable from a shell (via
`bin/gates/checks/ymir-config-check.sh`) without adding a verb to the engine's four-verb
interface.

    python3 -m ymir_runtime.config examples [--root DIR]
    python3 -m ymir_runtime.config validate <file>... [--kind K] [--root DIR] [--host H]
    python3 -m ymir_runtime.config kinds

Exit: 0 every config valid · 1 a config refused · 2 usage · 3 a dependency is
missing (run `bin/engine/ymir-engine-ensure.sh ensure`).
"""

from __future__ import annotations

import argparse
import os
import sys

from .load import KNOWN, load_config
from .schema import ConfigError, ConfigUnavailable, available

EXIT_OK = 0
EXIT_REFUSED = 1
EXIT_USAGE = 2
EXIT_UNAVAILABLE = 3

# The shipped shapes the schemas must validate — the examples are the truth.
EXAMPLES = ("agents.yaml.example", "cron.yaml.example", "fleet.json.example", "eindri-dispatch.json", "grants.yaml.example")


def _row(header: str, cells: tuple[str, ...]) -> str:
    body = ",".join(f'"{cell}"' for cell in cells)
    return f"{header}:\n  {body}\n"


def _table(header: str, rows: list[tuple[str, ...]]) -> str:
    body = "\n".join("  " + ",".join(f'"{cell}"' for cell in row) for row in rows)
    return f"{header}:\n{body}\n"


def _default_root() -> str:
    from .. import paths

    return str(paths.resolve().root)


def _judge(args: argparse.Namespace) -> int:
    root = args.root or _default_root()
    schema_dir = args.schema_dir or os.environ.get("YMIR_CONFIG_SCHEMA_DIR") or ""
    files: list[str]
    if args.kinds:
        print(_table(f"config-kinds[{len(KNOWN)}]{{kind,schema}}", [(k, KNOWN[k].schema) for k in sorted(KNOWN)]), end="")
        return EXIT_OK
    if args.examples:
        config_dir = os.path.join(root, "config")
        if not os.path.isdir(config_dir):
            config_dir = os.path.join(root, ".agents", "config")
        files = [os.path.join(config_dir, name) for name in EXAMPLES]
    else:
        files = list(args.files)
    if not files:
        print("error: nothing to validate", file=sys.stderr)
        return EXIT_USAGE

    rows: list[tuple[str, ...]] = []
    status = EXIT_OK
    for path in files:
        try:
            data = load_config(path, kind=args.kind or None, root=root, schema_dir=schema_dir or None, host=args.host or None)
        except ConfigUnavailable as exc:
            rows.append((path, "-", "unavailable", f"{exc.dependency} missing — {exc.remedy}"))
            status = EXIT_UNAVAILABLE
            continue
        except ConfigError as exc:
            rows.append((path, _kind_of(path, args.kind), "refuse", str(exc)))
            if status == EXIT_OK:
                status = EXIT_REFUSED
            continue
        kind = _kind_of(path, args.kind)
        rows.append((path, kind, "ok", _shape(data)))
    print(_table(f"config-check[{len(rows)}]{{file,kind,status,detail}}", rows), end="")
    return status


def _kind_of(path: str, kind: str | None) -> str:
    from .load import spec_for

    try:
        return spec_for(path, kind or None).kind
    except ConfigError:
        return "-"


def _shape(data) -> str:
    if isinstance(data, dict):
        if "jobs" in data:
            return f"{len(data['jobs'])} jobs"
        if "hosts" in data:
            return f"{len(data['hosts'])} hosts"
        if "agents" in data:
            return f"{len(data['agents'])} agents"
        if "rules" in data:
            return f"{len(data['rules'])} rules"
        if "grants" in data:
            return f"{len(data['grants'])} grants"
    return type(data).__name__


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="ymir_runtime.config", description="validate the hoard's configs against their JSON Schemas")
    parser.add_argument("--version", action="version", version="1.0.0")
    parser.add_argument("mode", nargs="?", default="examples", choices=("examples", "validate", "kinds"))
    parser.add_argument("files", nargs="*", help="config files (with `validate`)")
    parser.add_argument("--kind", default="", help="force one registered kind")
    parser.add_argument("--root", default="", help="the code tree holding config/*.schema.json")
    parser.add_argument("--schema-dir", default="", help="override the schema directory")
    parser.add_argument("--host", default="", help="this machine's name, for the fleet self-row check")
    parser.add_argument("--examples", action="store_true", help="validate the shipped *.example shapes")
    parser.add_argument("--kinds", action="store_true", help="list the registered kinds")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.mode == "validate" and not args.files:
        args.examples = True
    if args.mode == "kinds":
        args.kinds = True
    if args.mode == "examples":
        args.examples = True
    if args.kinds:
        return _judge(args)  # listing kinds needs no validator
    if not available():
        print(_row("config-check[1]{status,detail}", ("unavailable", "jsonschema missing — bin/engine/ymir-engine-ensure.sh ensure")), end="")
        return EXIT_UNAVAILABLE
    return _judge(args)


if __name__ == "__main__":  # pragma: no cover - the door's entry
    raise SystemExit(main())
