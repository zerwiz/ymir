#!/usr/bin/env python3
"""channel_todo — the todo channel for the action router.

WHY: Actions from meetings may need to become todo items in Ymir's todo system
or an external todo tool. This channel adapter creates todo items from meeting
actions.

WHAT IT DOES: Given a meeting action, create a todo item with the deliverable,
owner, and due date.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T  # noqa: E402


def todo_for_action(act: dict, rec: dict, dry: bool = False) -> str:
    """Create a todo item for an action."""
    aid = act.get("action_id", "?")
    deliverable = act.get("deliverable", "")
    owner = act.get("owner", "unowned")
    due = act.get("due_at", "unresolved")
    if dry:
        return f"dry-run:{aid}"
    # Ymir todo system: write to the todo file or call the todo tool
    # For now, log the todo item
    print(f"  todo: {deliverable} — {owner}, due {due} ({aid})", flush=True)
    return f"todo:{aid}"


def todo_for_decision(dec: dict, rec: dict, dry: bool = False) -> str:
    """Create a todo item for a decision (follow-up)."""
    did = dec.get("decision_id", "?")
    statement = dec.get("statement", "")
    if dry:
        return f"dry-run:{did}"
    print(f"  todo: Follow up on decision — {statement[:60]} ({did})", flush=True)
    return f"todo:{did}"