#!/usr/bin/env python3
"""board_audit.py — a board write is recorded as a WRITE: what changed, not only who called (plan 324 F12).

`access.jsonl` answers *who read what*. A write needs more: the object, its id, and each field it
touched with the value before and after. One row per write, appended, never rewritten (RULES/06):

    {"at", "door", "subject", "action", "object", "id", "where", "changed": {field: [before, after]}}

The ledger is `$YMIR_BOARDS_AUDIT`, else `~/.local/state/ymir/boards-audit.jsonl` — machine state, not
the home: it names card ids and titles, which are the operator's, so it never lands in the public repo.
A refusal is recorded too (`action: refused`, `why`), because a write that was stopped is part of the story.
"""
from __future__ import annotations

import datetime
import getpass
import json
import os


def ledger() -> str:
    return os.environ.get("YMIR_BOARDS_AUDIT") or os.path.expanduser("~/.local/state/ymir/boards-audit.jsonl")


def diff(before: dict, after: dict, fields) -> dict:
    """{field: [before, after]} for each named field whose value moved (a create has before=None)."""
    out = {}
    for f in fields:
        b = (before or {}).get(f)
        a = (after or {}).get(f)
        if b != a:
            out[f] = [b, a]
    return out


def record(door: str, action: str, obj: str, oid: str, changed: dict | None = None, where: str = "",
           why: str = "", subject: str = "") -> dict:
    row = {"at": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
           "door": door, "subject": subject or os.environ.get("YMIR_BOARDS_SUBJECT") or getpass.getuser(),
           "action": action, "object": obj, "id": oid, "where": where, "changed": changed or {}}
    if why:
        row["why"] = why
    path = ledger()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    except OSError:
        pass
    return row
