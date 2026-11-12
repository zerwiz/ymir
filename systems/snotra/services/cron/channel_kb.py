#!/usr/bin/env python3
"""channel_kb — the knowledge base channel for the action router.

WHY: Decisions and meeting records may need to be filed in a knowledge base
(Notion, Confluence) for long-term reference.

WHAT IT DOES: Given a meeting item, file it in the configured knowledge base.
Supports Notion (via notion_adapter) and Confluence (future).
"""
from __future__ import annotations
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T


def kb_for_item(item_type: str, item: dict, rec: dict, dry: bool = False) -> str:
    item_id = item.get(f"{item_type}_id" if item_type != "action" else "action_id", "?")
    if item_type == "decision":
        text = f"Decision: {item.get('statement', '')}"
    elif item_type == "action":
        text = f"Action: {item.get('deliverable', '')}"
    elif item_type == "question":
        text = f"Question: {item.get('question', '')}"
    else:
        text = str(item)[:80]
    if dry:
        return f"dry-run:{item_id}"
    # Notion/Confluence integration — stub for now
    print(f"  kb: {text[:60]} ({item_id})", flush=True)
    return f"kb:{item_id}"


def kb_for_meeting(rec: dict, dry: bool = False) -> str:
    mid = (rec.get("meeting") or {}).get("meeting_id", "?")
    title = (rec.get("meeting") or {}).get("title", mid)
    if dry:
        return f"dry-run:meeting-{mid}"
    print(f"  kb: Meeting record — {title} ({mid})", flush=True)
    return f"kb:meeting-{mid}"
