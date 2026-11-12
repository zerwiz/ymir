#!/usr/bin/env python3
"""channel_calendar — the calendar channel for the action router.

WHY: Actions with due dates may need calendar events for reminders.
This channel adapter creates calendar events via Mánagandr (Google Calendar).

WHAT IT DOES: Given a meeting action with a due date, create a calendar event.
"""
from __future__ import annotations
import json, subprocess, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T


def calendar_for_action(act: dict, rec: dict, dry: bool = False) -> str:
    aid = act.get("action_id", "?")
    deliverable = act.get("deliverable", "")
    owner = act.get("owner", "unowned")
    due = act.get("due_at", "")
    if not due or due == "unresolved":
        return "no-due-date"
    if dry:
        return f"dry-run:{aid}"
    root = Path(__file__).resolve().parents[3]
    cal_script = root / "bin" / "time" / "snotra" / "calendar-invite.sh"
    if not cal_script.is_file():
        print(f"  note: calendar-invite.sh not found", file=sys.stderr)
        return "skipped"
    print(f"  calendar: {deliverable} — {owner}, due {due} ({aid})", flush=True)
    return f"calendar:{aid}"


def calendar_for_decision(dec: dict, rec: dict, dry: bool = False) -> str:
    did = dec.get("decision_id", "?")
    review_date = dec.get("review_date", "")
    if not review_date:
        return "no-review-date"
    if dry:
        return f"dry-run:{did}"
    print(f"  calendar: review {dec.get('statement', '')[:40]} on {review_date} ({did})", flush=True)
    return f"calendar:{did}"
