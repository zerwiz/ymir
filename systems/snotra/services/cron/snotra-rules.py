#!/usr/bin/env python3
"""snotra-rules — the rules engine for per-board, per-project, per-company handling.

WHY: The automation scripts (card-moves, friday-synch, grooming, agenda) need to
know what rules apply to each board. Without a rules engine, every board behaves
identically — Rule A fires on every board, grooming happens on every board, etc.
The Allfather wants per-board, per-project, per-company control.

WHAT IT DOES:
    load    <company> <board>   print the effective rules for a board (resolved
                                through inheritance: company → project → board)
    check   <company>            validate all rules files for a company
    defaults                    print the house defaults

THE INHERITANCE CHAIN:
    1. House defaults (hodd/identity/rules/_defaults.yaml)
    2. Company rules (hodd/identity/rules/<company>.yaml) — overrides defaults
    3. Project rules (hodd/identity/rules/<company>/<project>.yaml) — overrides company
    4. Board rules (the boards: section) — overrides project

A rule not specified at any level gets the default value.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T  # noqa: E402

# ── defaults ─────────────────────────────────────────────────────────────────
HOUSE_DEFAULTS = {
    "rule_a": True,
    "rule_b": True,
    "note_on_mis_move": True,
    "friday_synch": True,
    "grooming": "monthly",
    "auto_assign": True,
    "notify_on_assign": True,
    "escalation": {"overdue_days": 3, "escalate_to": "chair"},
    "transcript_sources": [],
    "routing": {
        "decision": ["board", "email"],
        "action": ["board", "email", "todo"],
        "question": ["board", "email"],
        "signoff": ["email", "board"],
    },
}


def home_dir() -> Path:
    return T.home_dir()


def rules_dir() -> Path:
    return home_dir() / "hodd" / "identity" / "rules"


def load_yaml(path: Path) -> dict:
    try:
        import yaml  # noqa: PLC0415
    except Exception:
        die("PyYAML is missing: pip install pyyaml")
    if not path.is_file():
        return {}
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def die(msg: str, code: int = 1):
    print(f"snotra-rules: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def deep_merge(base: dict, override: dict) -> dict:
    """Deep merge two dicts. Override wins on conflicts."""
    result = dict(base)
    for key, val in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(val, dict):
            result[key] = deep_merge(result[key], val)
        elif key in result and isinstance(result[key], list) and isinstance(val, list):
            result[key] = val  # lists are replaced, not merged
        else:
            result[key] = val
    return result


def resolve_rules(company: str, project: str | None = None, board: str | None = None) -> dict:
    """Resolve effective rules through inheritance: defaults → company → project → board."""
    # Start with house defaults
    rules = dict(HOUSE_DEFAULTS)

    # Company level
    company_file = rules_dir() / f"{company}.yaml"
    company_rules = load_yaml(company_file)
    if company_rules:
        # Merge top-level rules (excluding 'boards' key)
        company_top = {k: v for k, v in company_rules.items() if k != "boards"}
        rules = deep_merge(rules, company_top)

        # Board-level override from company file
        if board and "boards" in company_rules:
            board_rules = company_rules["boards"].get(board, {})
            if board_rules:
                # board_rules has a "rules" sub-dict and possibly "routing" and other keys
                if "rules" in board_rules:
                    rules = deep_merge(rules, board_rules["rules"])
                for k in ("transcript_sources", "routing", "grooming", "friday_synch"):
                    if k in board_rules:
                        rules[k] = board_rules[k]

    # Project level
    if project:
        project_file = rules_dir() / company / f"{project}.yaml"
        project_rules = load_yaml(project_file)
        if project_rules:
            project_top = {k: v for k, v in project_rules.items() if k != "boards"}
            rules = deep_merge(rules, project_top)
            if board and "boards" in project_rules:
                board_rules = project_rules["boards"].get(board, {})
                if board_rules:
                    if "rules" in board_rules:
                        rules = deep_merge(rules, board_rules["rules"])
                    for k in ("transcript_sources", "routing", "grooming", "friday_synch"):
                        if k in board_rules:
                            rules[k] = board_rules[k]

    return rules


def cmd_load(argv: list[str]) -> int:
    if len(argv) < 4:
        die("usage: snotra-rules.sh load <company> <board> [--project <project>]")
    company = argv[2]
    # Board name may contain spaces; collect until --project or end
    board_parts = []
    i = 3
    while i < len(argv) and argv[i] != "--project":
        board_parts.append(argv[i])
        i += 1
    board = " ".join(board_parts) if board_parts else None
    project = None
    if i < len(argv) and argv[i] == "--project" and i + 1 < len(argv):
        project = argv[i + 1]
    if not board:
        die("a board name is required")
    rules = resolve_rules(company, project, board)
    print(json.dumps(rules, indent=2, default=str))
    return 0


def cmd_check(argv: list[str]) -> int:
    if len(argv) < 3:
        die("usage: snotra-rules.sh check <company>")
    company = argv[2]
    cdir = rules_dir() / company
    errors = []
    # Check company file
    company_file = rules_dir() / f"{company}.yaml"
    if company_file.is_file():
        try:
            load_yaml(company_file)
        except Exception as e:
            errors.append(f"company file: {e}")
    # Check project files
    if cdir.is_dir():
        for pf in cdir.glob("*.yaml"):
            try:
                load_yaml(pf)
            except Exception as e:
                errors.append(f"{pf.name}: {e}")
    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        return 1
    print(f"check{{company:{company},files:{len(list(cdir.glob('*.yaml')) if cdir.is_dir() else []) + (1 if company_file.is_file() else 0)},errors:0}}")
    return 0


def cmd_defaults(argv: list[str]) -> int:
    print(json.dumps(HOUSE_DEFAULTS, indent=2, default=str))
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == "load":
        return cmd_load(argv)
    if cmd == "check":
        return cmd_check(argv)
    if cmd == "defaults":
        return cmd_defaults(argv)
    die(f"unknown command {cmd!r} — load | check | defaults", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
