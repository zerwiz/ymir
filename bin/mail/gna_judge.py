"""Gná's judge: rules first, and every verdict carries the rule that gave it.

Six classes and six actions, no more. The judge never calls a model. A message
it cannot judge honestly leaves with low confidence and lands in the Unsure
queue, which is a decision for a human, not a guess.
"""

from __future__ import annotations

import re

CLASSES = ("notice", "invoice", "meeting", "request", "question", "other")
ACTIONS = ("record_notice", "file_invoice", "schedule_meeting", "create_card", "reply_needed", "archive")

_TOKENS = {
    "invoice": r"\b(faktura|fakturan|invoice|receipt|kvitto|betalning|betalningsbekräftelse|orderbekräftelse|reminder|påminnelse)\b",
    "meeting": r"\b(möte|mote|meeting|calendar|kalender|invitation|invite|zoom|teams|meet\.google|schedule|boka|when can we|när kan vi)\b",
    "request": r"\b(can you|could you|please|would you|need you|behöver|kan du|skulle du|request|förfrågan|offer|offert|proposal|avtal)\b",
    "question": r"\b(question|fråga|undrar|wondering|do you know|vet du|how|hur|what|vad|when|när)\b",
}

_PRIORITY = ("invoice", "meeting", "request", "question")

_ACTION_OF = {
    "invoice": "file_invoice",
    "meeting": "schedule_meeting",
    "request": "create_card",
    "question": "reply_needed",
    "notice": "record_notice",
    "other": "reply_needed",
}

_NOREPLY = re.compile(r"^(no-?reply|do-?not-?reply|notifications?|bounce|mailer-daemon)@", re.IGNORECASE)


def first_hit(text: str) -> tuple[str, str] | None:
    """The earliest match in this text, by class priority — with the word that fired."""
    best = None
    for kind in _PRIORITY:
        m = re.search(_TOKENS[kind], text or "", re.IGNORECASE)
        if m and (best is None or m.start() < best[0]):
            best = (m.start(), kind, m.group(0))
    return (best[1], best[2]) if best else None


def _tokens(record: dict) -> tuple[str, str, str] | None:
    """Subject first, then body. Returns (class, where, the matched word)."""
    subject = record.get("subject") or ""
    hit = first_hit(subject)
    if hit:
        return hit[0], "subject", hit[1]
    hit = first_hit(record.get("body_text") or "")
    if hit:
        return hit[0], "body", hit[1]
    return None


def _bulk(record: dict) -> str:
    """A deterministic marker that says: no human is being asked anything."""
    labels = set(record.get("labels") or [])
    for label, marker in (
        ("CATEGORY_PROMOTIONS", "label CATEGORY_PROMOTIONS"),
        ("CATEGORY_UPDATES", "label CATEGORY_UPDATES"),
        ("CATEGORY_FORUMS", "label CATEGORY_FORUMS"),
        ("SPAM", "label SPAM"),
    ):
        if label in labels:
            return marker
    if record.get("list_unsubscribe"):
        return "List-Unsubscribe header"
    if (record.get("precedence") or "").lower() in ("bulk", "list", "junk"):
        return f"Precedence: {record['precedence']}"
    if (record.get("auto_submitted") or "").lower() in ("auto-replied", "auto-generated"):
        return f"Auto-Submitted: {record['auto_submitted']}"
    sender = (record.get("from") or {}).get("email", "")
    if _NOREPLY.search(sender):
        return f"no-reply sender: {sender}"
    return ""


def judge(record: dict, people: dict[str, dict], thread: dict | None = None,
          house: set[str] | None = None) -> dict:
    """Return classification, confidence, proposed action, matched_by and evidence."""
    text = f"{record.get('subject') or ''} {record.get('body_text') or ''}"
    sender = (record.get("from") or {}).get("email", "").lower()
    account = (record.get("account") or "").lower()

    if record.get("direction") == "out" or sender == account:
        return {
            "classification": "other",
            "confidence": 0.9,
            "proposed_action": "archive",
            "matched_by": "direction",
            "evidence": "outbound: the account itself is the sender",
        }

    if sender in (house or set()):
        return {
            "classification": "notice",
            "confidence": 0.8,
            "proposed_action": "archive",
            "matched_by": "house",
            "evidence": f"house address {sender}: Ymir wrote to its own mailbox, no human asked",
        }

    person = people.get(sender)
    hit = _tokens(record)
    if thread and thread.get("classification") and thread.get("person_id") == (person or {}).get("id"):
        return {
            "classification": thread["classification"],
            "confidence": min(0.9, float(thread.get("confidence") or 0.7)),
            "proposed_action": thread.get("proposed_action") or _ACTION_OF.get(thread["classification"], "reply_needed"),
            "matched_by": "thread",
            "evidence": f"thread {record.get('thread_key')} inherits {thread['classification']} from message {thread.get('id')}",
        }

    if person:
        person_id = person.get("id")
        project = person.get("project") or None
        if hit:
            kind, where, word = hit
            return {
                "classification": kind,
                "confidence": 0.85,
                "proposed_action": _ACTION_OF[kind],
                "matched_by": "sender_email",
                "evidence": f"known sender {person_id} ({sender}); {where} carried \u201c{word}\u201d \u2192 {kind}",
                "person_id": person_id,
                "project_id": project,
            }
        return {
            "classification": "notice",
            "confidence": 0.7,
            "proposed_action": "record_notice",
            "matched_by": "sender_email",
            "evidence": f"known sender {person_id} ({sender}); no token fired, so it is a notice",
            "person_id": person_id,
            "project_id": project,
        }

    bulk = _bulk(record)
    if bulk:
        return {
            "classification": "notice",
            "confidence": 0.82,
            "proposed_action": "archive",
            "matched_by": "bulk",
            "evidence": f"unknown sender {sender or '(none)'}; bulk marker: {bulk} — nothing here asks a human",
        }

    hit = _tokens(record)
    if hit:
        kind, where, word = hit
        return {
            "classification": kind,
            "confidence": 0.5,
            "proposed_action": _ACTION_OF[kind],
            "matched_by": where,
            "evidence": f"unknown sender {sender or '(none)'}; {where} carried \u201c{word}\u201d \u2192 {kind}",
        }

    return {
        "classification": "other",
        "confidence": 0.2,
        "proposed_action": "reply_needed",
        "matched_by": "none",
        "evidence": f"unknown sender {sender or '(none)'} and no rule fired: a human decides",
    }
