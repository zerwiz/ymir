#!/usr/bin/env python3
"""channel_email — the email channel for the action router.

WHY: Decisions, actions, open questions, and sign-offs may need to be emailed
to participants. This channel adapter wraps the Gná mail desk (mail-send.sh)
to draft and send emails from meeting records.

WHAT IT DOES: Given a meeting record and an item (decision/action/question/signoff),
draft an email to the relevant person(s) using the Gná mail desk.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T  # noqa: E402


def home_dir() -> Path:
    return T.home_dir()


def draft_email(to: str, subject: str, body: str, dry: bool = False) -> str:
    """Draft an email via the Gná mail desk. Returns the draft id or 'dry-run'."""
    if dry:
        return "dry-run"
    root = Path(__file__).resolve().parents[3]
    mail_script = root / "bin" / "time" / "snotra" / "mail-send.sh"
    if not mail_script.is_file():
        print(f"  note: mail-send.sh not found at {mail_script}", file=sys.stderr)
        return "skipped"
    body_file = Path("/tmp") / f"email-{to.replace('@', '_')}.md"
    body_file.write_text(body, encoding="utf-8")
    try:
        result = subprocess.run(
            ["bash", str(mail_script), "draft", "--to", to, "--subject", subject, "--body", str(body_file)],
            capture_output=True, text=True, timeout=30,
        )
        return result.stdout.strip() or "drafted"
    except Exception as e:
        print(f"  note: email draft failed — {e}", file=sys.stderr)
        return "failed"


def email_for_decision(dec: dict, rec: dict, dry: bool = False) -> str:
    """Draft an email for a decision."""
    mid = (rec.get("meeting") or {}).get("meeting_id", "?")
    decided_by = dec.get("decided_by", "")
    # Find email from participants
    email = None
    for p in rec.get("participants", []):
        if p.get("name", "").lower() == decided_by.lower():
            email = p.get("email")
            break
    if not email:
        return "no-email"
    subject = f"Decision: {dec.get('statement', '')[:60]}"
    body = (
        f"**Decision:** {dec.get('statement', '')}\n\n"
        f"**Grade:** {dec.get('grade', 'C')}\n"
        f"**Rationale:** {dec.get('rationale', '—')}\n"
        f"**Decided by:** {decided_by}\n\n"
        f"Meeting: {mid}\n"
    )
    return draft_email(email, subject, body, dry)


def email_for_action(act: dict, rec: dict, dry: bool = False) -> str:
    """Draft an email for an action."""
    mid = (rec.get("meeting") or {}).get("meeting_id", "?")
    owner = act.get("owner", "")
    email = None
    for p in rec.get("participants", []):
        if p.get("name", "").lower() == owner.lower():
            email = p.get("email")
            break
    if not email:
        return "no-email"
    subject = f"Action: {act.get('deliverable', '')[:60]}"
    body = (
        f"**Action:** {act.get('deliverable', '')}\n\n"
        f"**Owner:** {owner}\n"
        f"**Due:** {act.get('due_at', 'unresolved')}\n"
        f"**Done when:** {act.get('definition_of_done', '—')}\n\n"
        f"Meeting: {mid}\n"
    )
    return draft_email(email, subject, body, dry)


def email_for_question(q: dict, rec: dict, dry: bool = False) -> str:
    """Draft an email for an open question."""
    mid = (rec.get("meeting") or {}).get("meeting_id", "?")
    decider = q.get("decider", "")
    email = None
    for p in rec.get("participants", []):
        if p.get("name", "").lower() == decider.lower():
            email = p.get("email")
            break
    if not email:
        return "no-email"
    subject = f"Question: {q.get('question', '')[:60]}"
    body = (
        f"**Question:** {q.get('question', '')}\n\n"
        f"**Decider:** {decider}\n"
        f"**Needed by:** {q.get('needed_by', 'next meeting')}\n"
        f"**Blocking:** {'yes' if q.get('blocking') else 'no'}\n\n"
        f"Meeting: {mid}\n"
    )
    return draft_email(email, subject, body, dry)


def email_for_signoff(rec: dict, dry: bool = False) -> str:
    """Draft sign-off request emails to all participants."""
    mid = (rec.get("meeting") or {}).get("meeting_id", "?")
    title = (rec.get("meeting") or {}).get("title", mid)
    results = []
    for p in rec.get("participants", []):
        email = p.get("email")
        if not email:
            continue
        subject = f"Sign-off: {title}"
        body = (
            f"The record of \"{title}\" is ready for your review.\n\n"
            f"Please reply with:\n  confirm\n  objection: <what is wrong or missing>\n\n"
            f"Meeting: {mid}\n"
        )
        results.append(draft_email(email, subject, body, dry))
    return ", ".join(results) if results else "no-emails"
