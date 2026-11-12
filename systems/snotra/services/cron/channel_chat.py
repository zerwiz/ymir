#!/usr/bin/env python3
"""channel_chat — the chat channel for the action router.

WHY: Decisions, actions, and open questions may need to be posted to chat
(Slack, Teams, Discord) for real-time notification.

WHAT IT DOES: Given a meeting item, post a message to the configured chat
channel. Supports Slack, Teams, and Discord (future — stubs for now).
"""
from __future__ import annotations
import json, os, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T


def chat_for_item(item_type: str, item: dict, rec: dict, dry: bool = False) -> str:
    item_id = item.get(f"{item_type}_id" if item_type != "action" else "action_id", "?")
    if item_type == "decision":
        text = f"Decision: {item.get('statement', '')[:80]}"
    elif item_type == "action":
        text = f"Action: {item.get('deliverable', '')[:80]} — {item.get('owner', 'unowned')}, due {item.get('due_at', 'unresolved')}"
    elif item_type == "question":
        text = f"Question: {item.get('question', '')[:80]} — decider: {item.get('decider', 'unassigned')}"
    else:
        text = str(item)[:80]
    if dry:
        return f"dry-run:{item_id}"
    # Slack/Teams/Discord integration — stub for now
    print(f"  chat: {text} ({item_id})", flush=True)
    return f"chat:{item_id}"


def chat_for_signoff(rec: dict, dry: bool = False) -> str:
    mid = (rec.get("meeting") or {}).get("meeting_id", "?")
    title = (rec.get("meeting") or {}).get("title", mid)
    if dry:
        return f"dry-run:signoff-{mid}"
    print(f"  chat: Sign-off requested for {title} ({mid})", flush=True)
    return f"chat:signoff-{mid}"
