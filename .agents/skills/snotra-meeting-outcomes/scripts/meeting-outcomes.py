#!/usr/bin/env python3
"""meeting-outcomes.py — turn a meeting transcript into an accountable record.

The one engine behind the snotra-meeting-outcomes skill. It is deliberately
deterministic: every decision and action carries a timestamp and a verbatim
quote from the transcript, and nothing is invented. A model may be used
elsewhere to enrich prose; this tool will not fabricate an owner, a date or a
commitment to make a document look complete.

Subcommands
  parse     transcript (txt/md/docx) -> segments.json
  extract   segments.json -> candidates.json (decisions, actions)
  merge     candidates.json + review.json -> record.json
  validate  record.json -> exit 0 clean / 1 errors
  render    record.json -> minutes, registers, briefs, follow-up
  cards     record.json -> Trello card payloads (JSON, no network)
  pipeline  parse + extract + merge + validate + render + cards, one run

Usage
  meeting-outcomes.py pipeline transcript.docx \
      --date 2026-10-20 --title "Road map & Trello" \
      --review review.json --outdir ./out

Exit codes
  0 ok · 1 validation/IO error · 2 usage
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import unicodedata
import zipfile
from datetime import date, datetime, timedelta
from pathlib import Path

VERSION = "1.0.0"


def load_operator() -> dict:
    """Who everything is sent from. The home owns it; no document hardcodes a name."""
    import os
    path = os.environ.get("YMIR_OPERATOR", "")
    if not path:
        home = os.environ.get("YMIR_HOME", "")
        if home:
            path = str(Path(home) / "hodd" / "identity" / "operator.yaml")
    if not path or not Path(path).is_file():
        return {}
    try:
        import yaml
        return yaml.safe_load(Path(path).read_text()) or {}
    except Exception:
        return {}

TS_RE = re.compile(r"^\[(\d{1,3}:\d{2}(?::\d{2})?)\]\s*(.*)$")
MONTHS = {
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
    "july": 7, "august": 8, "september": 9, "october": 10, "november": 11,
    "december": 12, "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12,
}
WEEKDAYS = {
    "monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3,
    "friday": 4, "saturday": 5, "sunday": 6,
}
WORD_NUM = {
    "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
    "seven": 7, "eight": 8, "nine": 9, "ten": 10,
}

GREETING_RE = re.compile(
    r"^\s*(good (morning|afternoon|evening)|hi|hello|hey|okay|ok|yeah|yes|no|"
    r"thanks|thank you|sorry|right|so|well|um|uh)\b",
    re.I,
)
ACTION_CUE_RE = re.compile(
    r"\b(i|we)(?:'ll|'re| will| are going to| need to| have to| should| must)\b"
    r"|\b(you|he|she|they) (?:can|could|should|will|need to|must)\b"
    r"|\b(can|could|would) you\b"
    r"|\bplease\b"
    r"|\b(let's|let us)\b"
    r"|\baction item\b"
    r"|\b(?:send|share|schedule|set up|make sure|prepare|draft|review|confirm|"
    r"circulate|add|create|install|research|check|decide|sign|file|build|"
    r"upload|post|write|follow up)\b",
    re.I,
)
DECISION_CUE_RE = re.compile(
    r"\b(we|i) (?:decided|agreed|confirmed|approved|settled|chose)\b"
    r"|\bthe decision is\b"
    r"|\bwe(?:'re| are) going with\b"
    r"|\b(?:let's|let us) go with\b"
    r"|\bfinal answer\b"
    r"|\bit(?:'s| is) decided\b"
    r"|\bwe will go with\b",
    re.I,
)
VERB_RE = re.compile(
    r"\b(send|share|schedule|set up|prepare|draft|review|confirm|circulate|"
    r"add|create|install|research|check|decide|sign|file|build|upload|post|"
    r"write|follow up|provide|make|define|fill|run|produce|deliver|book|"
    r"call|email|ask|collect|compile)\b",
    re.I,
)
NEGATIVE_OWNER = {
    "we", "us", "team", "everyone", "someone", "somebody", "they", "you",
    "tbd", "unassigned", "all", "the team",
}
STOP_TAIL = re.compile(
    r"[\s,;:-]*(?:you know|right|okay|ok|yeah|i mean|kind of|sort of|"
    r"or whatever|and so on|etc)\.?\s*$",
    re.I,
)
NEGATIVE_RE = re.compile(
    r"\b(?:not|never|don't|doesn't|didn't|won't|wouldn't|shouldn't|can't|"
    r"couldn't|aren't|isn't|haven't|hasn't|hadn't|not gonna|don't have to|"
    r"should have|would have|could have)\b",
    re.I,
)
HEDGE_RE = re.compile(
    r"^\s*(i think i|i might|i hope|maybe|perhaps|i guess|what i want|think in|"
    r"no, i|i'm not sure|i don't)\b",
    re.I,
)
META_RE = re.compile(
    r"\b(?:talk about|stay the line|get started|round up|go through the|"
    r"let's get|off track|on the call)\b",
    re.I,
)


# --------------------------------------------------------------------------
# input
# --------------------------------------------------------------------------

def read_docx(path: Path) -> str:
    with zipfile.ZipFile(path) as z:
        xml = z.read("word/document.xml").decode("utf-8", "replace")
    xml = re.sub(r"</w:p>", "\n", xml)
    xml = re.sub(r"<w:tab[^>]*/>", "\t", xml)
    xml = re.sub(r"<[^>]+>", "", xml)
    return html.unescape(xml)


def read_transcript(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix == ".docx":
        return read_docx(path)
    if suffix == ".json":
        data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
        return json_to_text(data)
    return path.read_text(encoding="utf-8", errors="replace")


def json_to_text(data: object) -> str:
    """Accept the common recorder shapes: Read AI / Fathom style segment lists."""
    lines: list[str] = []
    segments = data
    if isinstance(data, dict):
        for key in ("transcript", "segments", "utterances", "items", "data"):
            if isinstance(data.get(key), list):
                segments = data[key]
                break
    if isinstance(segments, list):
        for seg in segments:
            if not isinstance(seg, dict):
                continue
            speaker = (seg.get("speaker") or seg.get("speaker_name")
                       or seg.get("participant") or seg.get("name") or "")
            text = (seg.get("text") or seg.get("transcript")
                    or seg.get("content") or seg.get("sentence") or "")
            ts = seg.get("timestamp") or seg.get("start_time") or seg.get("start")
            if isinstance(ts, (int, float)):
                total = int(ts)
                ts = f"{total // 3600}:{(total % 3600) // 60:02d}:{total % 60:02d}"
            if speaker:
                lines.append(str(speaker).strip())
            if ts:
                lines.append(f"[{ts}] {text}".strip())
            elif text:
                lines.append(str(text).strip())
    return "\n".join(lines)


def normalize_space(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def parse_segments(raw: str) -> list[dict]:
    lines = [normalize_space(ln) for ln in raw.splitlines()]
    lines = [ln for ln in lines if ln]

    # A speaker is a short line that repeats, is not a timestamp line, and does
    # not end like a sentence. Counted first, so a one-off phrase is not a name.
    counts: dict[str, int] = {}
    for ln in lines:
        if TS_RE.match(ln):
            continue
        if 2 <= len(ln) <= 60 and not re.search(r"[.!?]$", ln) and re.search(r"[A-Za-z]", ln):
            counts[ln] = counts.get(ln, 0) + 1
    speakers = {ln for ln, n in counts.items() if n >= 2 and len(ln.split()) <= 5}
    # Never treat an obvious sentence as a name.
    speakers = {s for s in speakers if not GREETING_RE.match(s)}

    segments: list[dict] = []
    current = None
    for i, ln in enumerate(lines):
        m = TS_RE.match(ln)
        if m:
            ts, text = m.group(1), m.group(2).strip()
            if text:
                segments.append({
                    "index": len(segments),
                    "speaker": current,
                    "timestamp": ts,
                    "text": text,
                })
            continue
        looks_like_name = (
            2 <= len(ln) <= 60
            and not re.search(r"[.!?]$", ln)
            and re.search(r"[A-Za-z]", ln)
            and len(ln.split()) <= 5
            and not GREETING_RE.match(ln)
            and i + 1 < len(lines)
            and TS_RE.match(lines[i + 1]) is not None
        )
        if ln in speakers or looks_like_name:
            current = ln
            continue
        if segments:
            segments[-1]["text"] = normalize_space(segments[-1]["text"] + " " + ln)
    return segments


def infer_participants(segments: list[dict]) -> list[str]:
    names: list[str] = []
    for seg in segments:
        name = seg.get("speaker")
        if not name:
            continue
        if re.search(r"notetaker|recorder|bot\b", name, re.I):
            continue
        if name not in names:
            names.append(name)
    return names


# --------------------------------------------------------------------------
# dates
# --------------------------------------------------------------------------

def next_weekday(base: date, weekday: int) -> date:
    delta = (weekday - base.weekday()) % 7
    return base + timedelta(days=delta or 7)


def resolve_date(text: str, base: date) -> tuple[str | None, str]:
    """Return (ISO date or None, reason). 'reason' is the matched phrase."""
    t = text.lower()
    if m := re.search(r"\b(\d{4}-\d{2}-\d{2})\b", t):
        return m.group(1), m.group(1)
    if re.search(r"\btomorrow\b", t):
        return (base + timedelta(days=1)).isoformat(), "tomorrow"
    if re.search(r"\b(today|tonight)\b", t):
        return base.isoformat(), "today"
    if re.search(r"\b(in\s+)?(one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+weeks?\b", t):
        m = re.search(r"\b(in\s+)?(one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+weeks?\b", t)
        n = WORD_NUM.get(m.group(2), None)
        if n is None:
            n = int(m.group(2))
        return (base + timedelta(weeks=n)).isoformat(), m.group(0).strip()
    if re.search(r"\bnext week\b", t):
        return next_weekday(base, 0).isoformat(), "next week"
    if re.search(r"\bthis week\b", t):
        friday = base + timedelta(days=(4 - base.weekday()) % 7)
        return friday.isoformat(), "this week"
    for name, wd in WEEKDAYS.items():
        if re.search(rf"\b{name}\b", t):
            return next_weekday(base, wd).isoformat(), name
    m = re.search(r"\b(?:by\s+)?(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?(?:\s+of)?\s+([a-z]{3,9})\b", t)
    if m and m.group(2) in MONTHS:
        day, month = int(m.group(1)), MONTHS[m.group(2)]
        year = base.year + (1 if (month, day) < (base.month, base.day) else 0)
        try:
            return date(year, month, day).isoformat(), m.group(0).strip()
        except ValueError:
            return None, m.group(0).strip()
    m = re.search(r"\b([a-z]{3,9})\s+(\d{1,2})(?:st|nd|rd|th)?\b", t)
    if m and m.group(1) in MONTHS:
        day, month = int(m.group(2)), MONTHS[m.group(1)]
        year = base.year + (1 if (month, day) < (base.month, base.day) else 0)
        try:
            return date(year, month, day).isoformat(), m.group(0).strip()
        except ValueError:
            return None, m.group(0).strip()
    return None, ""


# --------------------------------------------------------------------------
# extraction
# --------------------------------------------------------------------------

def sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[.!?])\s+", text)
    return [p.strip() for p in parts if p.strip()]


def clean_deliverable(sentence: str) -> str:
    s = unicodedata.normalize("NFKC", sentence).strip()
    s = s.lstrip("\u200b\ufeff")
    for _ in range(3):
        s2 = re.sub(r"^(so|and|but|yeah|okay|ok|right|well|um|uh)[,\s]+", "", s, flags=re.I)
        if s2 == s:
            break
        s = s2
    s = s.lstrip(" ,;:-")
    s = STOP_TAIL.sub("", s)
    s = re.sub(r"^[\-\u2013]\s*", "", s)
    s = s.strip(" \"'")
    if s and s[0].islower():
        s = s[0].upper() + s[1:]
    return s


def infer_owner(sentence: str, speaker: str | None, aliases: dict[str, str]) -> str | None:
    for alias, canonical in aliases.items():
        if re.search(rf"\b{re.escape(alias)}\b", sentence, re.I):
            return canonical
    if re.search(r"\bi\b", sentence, re.I) and speaker:
        return aliases.get(speaker, speaker)
    return None


def extract_candidates(segments: list[dict], base: date,
                       aliases: dict[str, str]) -> dict:
    actions: list[dict] = []
    decisions: list[dict] = []
    seen: set[str] = set()

    for seg in segments:
        text = seg.get("text", "")
        quote_source = text
        if not text:
            continue
        for sent in sentences(text):
            if len(sent.split()) < 5:
                continue
            if GREETING_RE.match(sent) and len(sent.split()) < 8:
                continue
            key = re.sub(r"[^a-z0-9 ]", "", sent.lower())[:160]
            if key in seen:
                continue
            is_question = sent.rstrip().endswith("?")
            if DECISION_CUE_RE.search(sent) and not is_question:
                seen.add(key)
                decisions.append({
                    "statement": clean_deliverable(sent),
                    "decided_by": infer_owner(sent, seg.get("speaker"), aliases)
                                  or aliases.get(seg.get("speaker") or "", "Unassigned"),
                    "evidence": {
                        "timestamp": seg["timestamp"],
                        "quote": sent[:600],
                        "segment_index": seg["index"],
                    },
                    "confidence": "medium",
                    "source": "machine",
                })
                continue
            if not ACTION_CUE_RE.search(sent):
                continue
            if is_question and not re.search(r"\b(can|could|would) you\b|\bplease\b", sent, re.I):
                continue
            if re.search(r"\bi (don't|do not) know\b|\bi mean\b", sent, re.I):
                continue
            if NEGATIVE_RE.search(sent):
                continue
            if META_RE.search(sent) or HEDGE_RE.match(sent):
                continue
            owner = infer_owner(sent, seg.get("speaker"), aliases)
            due, due_reason = resolve_date(sent, base)
            deliverable = clean_deliverable(sent)
            if len(deliverable.split()) < 3:
                continue
            if HEDGE_RE.match(deliverable) or META_RE.search(deliverable):
                continue
            seen.add(key)
            score = 0
            score += 2 if owner else 0
            score += 2 if due else 0
            score += 1 if re.match(
                r"^\s*(send|share|schedule|set up|prepare|draft|review|confirm|"
                r"circulate|add|create|install|research|check|decide|sign|file|"
                r"build|upload|post|write|provide|make|define|fill|run|produce|"
                r"deliver|book|call|email|ask|collect|compile)\b",
                deliverable, re.I) else 0
            score += 1 if re.search(
                r"\b(will|need to|have to|please|can you|could you|should)\b",
                sent, re.I) else 0
            if score < 3:
                continue
            confidence = "high" if (owner and due) else "medium" if (owner or due) else "low"
            actions.append({
                "verb": (VERB_RE.search(deliverable).group(1).lower()
                         if VERB_RE.search(deliverable) else "act"),
                "deliverable": deliverable,
                "owner": owner,
                "due_at": due,
                "date_unresolved": due is None,
                "due_reason": due_reason,
                "evidence": {
                    "timestamp": seg["timestamp"],
                    "quote": sent[:600],
                    "segment_index": seg["index"],
                },
                "confidence": confidence,
                "score": score,
                "source": "machine",
            })
        _ = quote_source

    actions.sort(key=lambda a: (-a.get("score", 0), a["evidence"]["timestamp"]))
    actions = actions[:40]
    decisions = decisions[:40]
    for i, a in enumerate(actions, 1):
        a["action_id"] = f"ACT-{base.strftime('%Y%m%d')}-{i:02d}"
    for i, d in enumerate(decisions, 1):
        d["decision_id"] = f"DEC-{base.strftime('%Y%m%d')}-{i:02d}"
    return {"decisions": decisions, "actions": actions}


# --------------------------------------------------------------------------
# merge
# --------------------------------------------------------------------------

def normalize_review(review: dict, base: date) -> dict:
    out = {
        "meeting": review.get("meeting", {}),
        "participants": review.get("participants", []),
        "agenda": review.get("agenda", []),
        "decisions": [],
        "actions": [],
        "questions": review.get("questions", []),
        "risks": review.get("risks", []),
        "sources": review.get("sources", {}),
    }
    for i, d in enumerate(review.get("decisions", []), 1):
        d = dict(d)
        d.setdefault("decision_id", f"DEC-{base.strftime('%Y%m%d')}-{i:02d}")
        d.setdefault("status", "decided")
        d.setdefault("source", "curated")
        out["decisions"].append(d)
    for i, a in enumerate(review.get("actions", []), 1):
        a = dict(a)
        a.setdefault("action_id", f"ACT-{base.strftime('%Y%m%d')}-{i:02d}")
        a.setdefault("status", "proposed")
        a.setdefault("confidence", "high")
        a.setdefault("source", "curated")
        a.setdefault("date_unresolved", a.get("due_at") is None)
        out["actions"].append(a)
    return out


def merge_record(candidates: dict, review: dict, base: date,
                 include_machine: bool = False) -> dict:
    rec = normalize_review(review, base)
    if include_machine:
        known = {re.sub(r"\W+", "", a.get("deliverable", "").lower())[:80]
                 for a in rec["actions"]}
        for a in candidates.get("actions", []):
            k = re.sub(r"\W+", "", a.get("deliverable", "").lower())[:80]
            if k not in known:
                rec["actions"].append(a)
                known.add(k)
        known_d = {re.sub(r"\W+", "", d.get("statement", "").lower())[:80]
                   for d in rec["decisions"]}
        for d in candidates.get("decisions", []):
            k = re.sub(r"\W+", "", d.get("statement", "").lower())[:80]
            if k not in known_d:
                rec["decisions"].append(d)
                known_d.add(k)
    op = load_operator()
    sig = op.get("signature") or {}
    meeting = rec["meeting"]
    if not meeting.get("sender"):
        meeting["sender"] = op.get("name") or meeting.get("organizer")
    if not meeting.get("sender_email"):
        meeting["sender_email"] = op.get("email")
    meeting.setdefault("sender_org", op.get("organization"))
    if (sig.get("style") == "team") and op.get("partners") and not meeting.get("partners_line"):
        meeting["partners_line"] = ", ".join(op["partners"])
    if sig.get("disclose_assistants") and not meeting.get("signature_note"):
        notes = [a.get("note") for a in (sig.get("assistants") or []) if a.get("note")]
        if notes:
            meeting["signature_note"] = " ".join(notes)
    rec["meeting"].setdefault("meeting_id", f"M-{base.strftime('%Y%m%d')}")
    rec["meeting"].setdefault("source", "manual")
    rec["meeting"].setdefault("classification", "internal")
    if not rec["participants"]:
        rec["participants"] = []
    return rec


# --------------------------------------------------------------------------
# validation
# --------------------------------------------------------------------------

def validate_record(rec: dict) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    meeting = rec.get("meeting", {})
    for key in ("meeting_id", "title", "started_at", "source", "classification"):
        if not meeting.get(key):
            errors.append(f"meeting.{key} is required")
    if meeting.get("classification") not in ("internal", "confidential", "restricted"):
        errors.append("meeting.classification must be internal|confidential|restricted")

    names = {p.get("name") for p in rec.get("participants", []) if p.get("name")}
    ids: set[str] = set()

    for d in rec.get("decisions", []):
        did = d.get("decision_id", "")
        if did in ids:
            errors.append(f"duplicate id {did}")
        ids.add(did)
        if not re.match(r"^DEC-\d{8}-\d{2}$", did):
            errors.append(f"{did}: invalid decision id")
        if not d.get("statement"):
            errors.append(f"{did}: statement required")
        if not d.get("decided_by") or str(d.get("decided_by")).lower() in NEGATIVE_OWNER:
            errors.append(f"{did}: decided_by must name one person")
        ev = d.get("evidence") or {}
        if not ev.get("quote") or not ev.get("timestamp"):
            errors.append(f"{did}: evidence (timestamp + quote) required")

    for a in rec.get("actions", []):
        aid = a.get("action_id", "")
        if aid in ids:
            errors.append(f"duplicate id {aid}")
        ids.add(aid)
        if not re.match(r"^ACT-\d{8}-\d{2}$", aid):
            errors.append(f"{aid}: invalid action id")
        owner = str(a.get("owner") or "").strip()
        if not owner or owner.lower() in NEGATIVE_OWNER:
            errors.append(f"{aid}: exactly one named owner is required")
        elif names and owner not in names:
            warnings.append(f"{aid}: owner '{owner}' is not in the participant list")
        if not a.get("deliverable"):
            errors.append(f"{aid}: deliverable required")
        due = a.get("due_at")
        if due:
            try:
                date.fromisoformat(due)
            except ValueError:
                errors.append(f"{aid}: due_at is not an ISO date")
        elif not (a.get("date_unresolved") and a.get("decide_by")):
            errors.append(f"{aid}: due_at is null; set date_unresolved and decide_by")
        ev = a.get("evidence") or {}
        if not ev.get("quote") or not ev.get("timestamp"):
            errors.append(f"{aid}: evidence (timestamp + quote) required")
        if a.get("status") == "done" and not a.get("definition_of_done"):
            errors.append(f"{aid}: cannot be done without a definition_of_done")

    for q in rec.get("questions", []):
        qid = q.get("question_id", "")
        if not re.match(r"^OQ-\d{8}-\d{2}$", qid):
            errors.append(f"{qid}: invalid question id")
        if not q.get("decider"):
            errors.append(f"{qid}: decider required")

    return errors, warnings


# --------------------------------------------------------------------------
# render
# --------------------------------------------------------------------------

def fmt_person(name: str) -> str:
    return name


def render_minutes(rec: dict) -> str:
    m = rec["meeting"]
    out: list[str] = []
    out.append(f"# Meeting Record — {m.get('title')}")
    out.append("")
    out.append(f"**Date:** {m.get('started_at')}  ")
    out.append(f"**Duration:** {m.get('duration_minutes') or '—'} minutes  ")
    out.append(f"**Organizer:** {m.get('organizer') or '—'}  ")
    out.append(f"**Classification:** {m.get('classification')}  ")
    out.append(f"**Source:** {m.get('source')}"
               + (f" (`{m.get('source_ref')}`)" if m.get("source_ref") else ""))
    out.append("")
    out.append("## Attendance")
    out.append("")
    present = [p["name"] for p in rec.get("participants", []) if p.get("present")]
    absent = [p["name"] for p in rec.get("participants", []) if not p.get("present")]
    out.append(f"**Present:** {', '.join(present) or '—'}")
    if absent:
        out.append(f"**Absent:** {', '.join(absent)}")
    out.append("")
    if m.get("purpose"):
        out.append("## Purpose")
        out.append("")
        out.append(m["purpose"])
        out.append("")
    if rec.get("agenda"):
        out.append("## Agenda and outcomes")
        out.append("")
        for item in rec["agenda"]:
            out.append(f"- **{item.get('item')}**"
                       + (f" — {item.get('outcome')}" if item.get("outcome") else ""))
        out.append("")
    out.append("## Decisions")
    out.append("")
    if not rec.get("decisions"):
        out.append("_No decisions recorded._")
    for d in rec.get("decisions", []):
        out.append(f"### {d['decision_id']} — {d['statement']}")
        out.append("")
        if d.get("rationale"):
            out.append(f"**Rationale:** {d['rationale']}")
        out.append(f"**Decided by:** {d.get('decided_by')}  ")
        out.append(f"**Reversibility:** {d.get('reversibility') or '—'}  ")
        out.append(f"**Evidence:** [{d['evidence']['timestamp']}] \"{d['evidence']['quote']}\"")
        out.append("")
    out.append("## Actions")
    out.append("")
    out.append("| ID | Action | Owner | Due | Status |")
    out.append("|---|---|---|---|---|")
    for a in rec.get("actions", []):
        due = a.get("due_at") or "date unresolved"
        out.append(f"| {a['action_id']} | {a.get('deliverable')} | {a.get('owner')} | {due} | {a.get('status')} |")
    out.append("")
    if rec.get("questions"):
        out.append("## Open questions")
        out.append("")
        for q in rec["questions"]:
            out.append(f"- **{q['question_id']}** {q['question']} — "
                       f"decider: {q.get('decider')}, needed by {q.get('needed_by') or '—'}")
        out.append("")
    if rec.get("risks"):
        out.append("## Risks")
        out.append("")
        for r in rec["risks"]:
            out.append(f"- **{r['risk_id']}** {r['description']} — owner: {r.get('owner')}")
        out.append("")
    if m.get("next_meeting"):
        out.append("## Next meeting")
        out.append("")
        out.append(m["next_meeting"])
        out.append("")
    out.append("## Evidence appendix")
    out.append("")
    out.append("Every entry above is traceable to the transcript. Machine transcripts")
    out.append("carry recognition errors; the quote is evidence of intent, not exact wording.")
    out.append("")
    for d in rec.get("decisions", []):
        out.append(f"- `{d['evidence']['timestamp']}` {d['decision_id']}: "
                   f"\"{d['evidence']['quote']}\"")
    for a in rec.get("actions", []):
        out.append(f"- `{a['evidence']['timestamp']}` {a['action_id']}: "
                   f"\"{a['evidence']['quote']}\"")
    out.append("")
    return "\n".join(out)


def render_actions(rec: dict) -> str:
    out = [f"# Action register — {rec['meeting'].get('title')}", ""]
    out.append("| ID | Verb | Deliverable | Owner | Due | Board | Status | Evidence |")
    out.append("|---|---|---|---|---|---|---|---|")
    out.append("**The action standard:** one owner, one verb, one deliverable, one date, a "
               "definition of done, and a source line. An action missing any of these is "
               "printed as unresolved, never guessed.")
    out.append("")
    for a in sorted(rec.get("actions", []), key=lambda x: (x.get("owner") or "", x.get("due_at") or "9999")):
        ev = a.get("evidence", {})
        out.append(f"| {a['action_id']} | {a.get('verb')} | {a.get('deliverable')} | "
                   f"{a.get('owner')} | {a.get('due_at') or 'date unresolved'} | "
                   f"{a.get('board') or '—'} | {a.get('status')} | "
                   f"`{ev.get('timestamp')}` |")
    out.append("")
    return "\n".join(out)


def render_decisions(rec: dict) -> str:
    out = [f"# Decision log — {rec['meeting'].get('title')}", ""]
    out.append("## The decision standard")
    out.append("")
    out.append("A decision enters this log only if it passes all six tests:")
    out.append("")
    out.append("1. **One sentence.** The decision is stated so it can be repeated without the discussion.")
    out.append("2. **One decider.** A named person, not \"the team\".")
    out.append("3. **A reason.** The rationale is written, not remembered.")
    out.append("4. **A reversal cost.** `easy`, `costly` or `one-way`; a one-way door needs a review date.")
    out.append("5. **A witness.** The timestamp and quote from the transcript.")
    out.append("6. **A next look.** A review date, or an explicit `—` meaning \"no review needed\".")
    out.append("")
    for d in rec.get("decisions", []):
        out.append(f"## {d['decision_id']}")
        out.append("")
        out.append(f"**Decision:** {d['statement']}")
        out.append("")
        out.append(f"**Decided by:** {d.get('decided_by')}  ")
        out.append(f"**Rationale:** {d.get('rationale') or 'not stated'}  ")
        out.append(f"**Reversibility:** {d.get('reversibility') or '—'}  ")
        out.append(f"**Review date:** {d.get('review_date') or '—'}  ")
        out.append(f"**Status:** {d.get('status') or 'decided'}  ")
        if d.get("impact"):
            out.append(f"**Impact:** {d['impact']}  ")
        alts = d.get("alternatives") or []
        if alts:
            out.append(f"**Alternatives considered:** {'; '.join(alts)}  ")
        out.append("")
        out.append(f"> [{d['evidence']['timestamp']}] \"{d['evidence']['quote']}\"")
        out.append("")
    return "\n".join(out)


def render_brief(rec: dict, person: str) -> str:
    mine = [a for a in rec.get("actions", []) if a.get("owner") == person]
    out = [f"# Your actions — {rec['meeting'].get('title')}", ""]
    out.append(f"{person}, below are the actions assigned to you in the meeting of "
               f"{rec['meeting'].get('started_at')}.")
    out.append("")
    if not mine:
        out.append("No actions were assigned to you in this meeting.")
    for a in sorted(mine, key=lambda x: x.get("due_at") or "9999"):
        out.append(f"## {a['action_id']} — {a.get('deliverable')}")
        out.append("")
        out.append(f"**Due:** {a.get('due_at') or 'date unresolved'}  ")
        if a.get("definition_of_done"):
            out.append(f"**Done when:** {a['definition_of_done']}  ")
        if a.get("dependency"):
            out.append(f"**Depends on:** {a['dependency']}  ")
        out.append(f"**Source:** [{a['evidence']['timestamp']}] \"{a['evidence']['quote']}\"")
        out.append("")
    out.append("## Decisions that affect the team")
    out.append("")
    for d in rec.get("decisions", []):
        out.append(f"- {d['statement']}")
    out.append("")
    out.append("If anything here is wrong, reply with the correction by the end of the "
               "next business day. Silence is recorded as provisional acceptance.")
    out.append("")
    return "\n".join(out)


def render_followup(rec: dict) -> str:
    m = rec["meeting"]
    present = [p["name"] for p in rec.get("participants", []) if p.get("present")]
    out = [f"Subject: {m.get('title')} — decisions and owners, {m.get('started_at', '')[:10]}", ""]
    out.append(f"Dear {', '.join(present) if present else 'all'},")
    out.append("")
    out.append(f"Thank you for the meeting on {m.get('started_at', '')[:10]}. "
               "Below is the record of what we decided and who owns what next.")
    out.append("")
    out.append("## Decisions")
    out.append("")
    for d in rec.get("decisions", []):
        out.append(f"- {d['statement']}")
    out.append("")
    out.append("## Actions")
    out.append("")
    out.append("| Action | Owner | Due |")
    out.append("|---|---|---|")
    for a in rec.get("actions", []):
        out.append(f"| {a.get('deliverable')} | {a.get('owner')} | {a.get('due_at') or 'to be agreed'} |")
    out.append("")
    if rec.get("questions"):
        out.append("## Open questions")
        out.append("")
        for q in rec["questions"]:
            out.append(f"- {q['question']} — {q.get('decider')} to decide by {q.get('needed_by') or 'the next meeting'}")
        out.append("")
    out.append("If any entry is inaccurate, please reply with the correction and it will be "
               "appended to the record. Otherwise these items stand as agreed.")
    out.append("")
    out.append("Kind regards,")
    out.append("")
    # Who SENDS the follow-up is not always who ORGANISED the meeting.
    out.append(m.get("sender") or m.get("organizer") or "")
    if m.get("sender_org"):
        out.append(m["sender_org"])
    if m.get("sender_email"):
        out.append(m["sender_email"])
    if m.get("partners_line"):
        out.append("")
        out.append(f"Partners: {m['partners_line']}")
    if m.get("signature_note"):
        out.append("")
        out.append(m["signature_note"])
    out.append("")
    return "\n".join(out)



def render_dependencies(rec: dict) -> str:
    """A Mermaid map of actions and what each one waits on."""
    actions = rec.get("actions", [])
    by_owner: dict[str, list[dict]] = {}
    for a in actions:
        by_owner.setdefault(a.get("owner") or "Unassigned", []).append(a)
    lines = [f"# Dependency map — {rec['meeting'].get('title')}", "",
             "```mermaid", "graph TD"]
    for owner, items in by_owner.items():
        safe = re.sub(r"[^A-Za-z0-9_]", "_", owner)
        lines.append(f'  subgraph {safe}["{owner}"]')
        for a in items:
            label = (a.get("deliverable") or a["action_id"])[:60].replace('"', "'")
            due = a.get("due_at") or "unresolved"
            lines.append(f'    {a["action_id"]}["{label}<br/><small>{due}</small>"]')
        lines.append("  end")
    ids = {a["action_id"] for a in actions}
    for a in actions:
        dep = a.get("dependency") or ""
        for ref in re.findall(r"ACT-\d{8}-\d{2}", dep):
            if ref in ids:
                lines.append(f'  {ref} --> {a["action_id"]}')
    lines += ["```", "", "| Action | Owner | Depends on | Due |", "|---|---|---|---|"]
    for a in actions:
        lines.append(f"| {a['action_id']} | {a.get('owner')} | {a.get('dependency') or '—'} | {a.get('due_at') or 'unresolved'} |")
    lines.append("")
    return "\n".join(lines)

def render_transcript(rec: dict, outdir: Path) -> str | None:
    """Raw transcript, one line per segment, exactly as the source gave it."""
    p = outdir / "segments.json"
    if not p.is_file():
        return None
    data = json.loads(p.read_text(encoding="utf-8"))
    segs = data.get("segments", data) if isinstance(data, dict) else data
    lines = [f"# Raw transcript — {rec['meeting'].get('title')}", ""]
    lines.append("Verbatim, in order, with the timestamps the source recorded. The record "
                 "above is the curated reading; this is the evidence it rests on.")
    lines.append("")
    for seg in segs:
        text = " ".join(str(seg.get("text", "")).split())
        if not text:
            continue
        lines.append(f"[{seg.get('timestamp') or '—'}] **{seg.get('speaker') or 'Unknown'}:** {text}")
    lines.append("")
    return "\n".join(lines)


def render_all(rec: dict, outdir: Path) -> list[Path]:
    outdir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    files = {
        "minutes.md": render_minutes(rec),
        "actions.md": render_actions(rec),
        "decisions.md": render_decisions(rec),
        "followup-email.md": render_followup(rec),
        "dependency-map.md": render_dependencies(rec),
    }
    transcript = render_transcript(rec, outdir)
    if transcript:
        files["transcript.md"] = transcript
    for name, text in files.items():
        p = outdir / name
        p.write_text(text, encoding="utf-8")
        written.append(p)
    briefs = outdir / "briefs"
    briefs.mkdir(exist_ok=True)
    for person in sorted({a.get("owner") for a in rec.get("actions", []) if a.get("owner")}):
        slug = re.sub(r"[^a-z0-9]+", "-", person.lower()).strip("-")
        p = briefs / f"{slug}.md"
        p.write_text(render_brief(rec, person), encoding="utf-8")
        written.append(p)
    return written


def render_cards(rec: dict) -> list[dict]:
    cards: list[dict] = []
    for a in rec.get("actions", []):
        desc = "\n".join([
            f"Source: {rec['meeting'].get('title')} — {rec['meeting'].get('started_at', '')[:10]} — {a['evidence']['timestamp']}",
            f"Decision: {a.get('decision_id') or 'none'}",
            f"Definition of done: {a.get('definition_of_done') or 'to be agreed'}",
            f"Dependency: {a.get('dependency') or 'none'}",
            f"Evidence: \"{a['evidence']['quote']}\"",
            "",
            f"Action ID: {a['action_id']}",
        ])
        cards.append({
            "board": a.get("board") or "Inbox",
            "list": a.get("list") or "Inbox",
            "name": a.get("deliverable"),
            "desc": desc,
            "due": a.get("due_at"),
            "members": [a.get("owner")],
            "labels": [],
            "action_id": a["action_id"],
        })
    return cards


# --------------------------------------------------------------------------
# cli
# --------------------------------------------------------------------------

def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, data: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def build_aliases(participants: list[dict], extra: dict | None = None) -> dict[str, str]:
    """Map every spoken form to one canonical name.

    Aliases come from the participant list and from the review's `aliases`
    block (full name -> list of spoken forms). The engine ships no names: a
    public repository may not carry a real person's name, and every home's
    roster differs.
    """
    aliases: dict[str, str] = {}
    extra = extra or {}
    for p in participants:
        name = p.get("name")
        if not name:
            continue
        aliases[name] = name
        aliases.setdefault(name.split()[0], name)
        for alias in extra.get(name, []):
            aliases[alias] = name
    return aliases


def cmd_parse(args) -> int:
    raw = read_transcript(Path(args.transcript))
    segments = parse_segments(raw)
    if not segments:
        print("error: no timestamped segments found", file=sys.stderr)
        return 1
    dump_json(Path(args.out), {"segments": segments,
                               "participants": infer_participants(segments)})
    print(f"parsed {len(segments)} segments, "
          f"{len(infer_participants(segments))} speakers -> {args.out}")
    return 0


def cmd_extract(args) -> int:
    data = load_json(Path(args.segments))
    base = date.fromisoformat(args.date)
    aliases = build_aliases([{"name": n} for n in data.get("participants", [])])
    cands = extract_candidates(data["segments"], base, aliases)
    dump_json(Path(args.out), cands)
    print(f"extracted {len(cands['decisions'])} decision candidates, "
          f"{len(cands['actions'])} action candidates -> {args.out}")
    return 0


def cmd_merge(args) -> int:
    base = date.fromisoformat(args.date)
    cands = load_json(Path(args.candidates)) if args.candidates else {"actions": [], "decisions": []}
    review = load_json(Path(args.review))
    rec = merge_record(cands, review, base, include_machine=args.include_machine)
    rec["meeting"]["started_at"] = rec["meeting"].get("started_at") or f"{base.isoformat()}T00:00:00"
    for a in rec["actions"]:
        a.setdefault("date_unresolved", a.get("due_at") is None)
    dump_json(Path(args.out), rec)
    print(f"merged {len(rec['decisions'])} decisions, {len(rec['actions'])} actions -> {args.out}")
    return 0


def cmd_validate(args) -> int:
    rec = load_json(Path(args.record))
    errors, warnings = validate_record(rec)
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    if errors:
        for e in errors:
            print(f"error: {e}", file=sys.stderr)
        print(f"INVALID — {len(errors)} error(s)", file=sys.stderr)
        return 1
    print(f"VALID — {len(rec.get('decisions', []))} decisions, "
          f"{len(rec.get('actions', []))} actions, {len(warnings)} warning(s)")
    return 0


def cmd_render(args) -> int:
    rec = load_json(Path(args.record))
    written = render_all(rec, Path(args.outdir))
    dump_json(Path(args.outdir) / "cards.json", render_cards(rec))
    print(f"rendered {len(written)} documents + cards.json into {args.outdir}")
    return 0


def cmd_cards(args) -> int:
    rec = load_json(Path(args.record))
    cards = render_cards(rec)
    dump_json(Path(args.out), {"cards": cards})
    print(f"{len(cards)} card payloads -> {args.out}")
    return 0


def cmd_pipeline(args) -> int:
    base = date.fromisoformat(args.date)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    raw = read_transcript(Path(args.transcript))
    segments = parse_segments(raw)
    if not segments:
        print("error: no timestamped segments found", file=sys.stderr)
        return 1
    participants = infer_participants(segments)
    dump_json(outdir / "segments.json", {"segments": segments, "participants": participants})

    review = load_json(Path(args.review))
    aliases = build_aliases(
        review.get("participants") or [{"name": n} for n in participants],
        review.get("aliases"))
    cands = extract_candidates(segments, base, aliases)
    dump_json(outdir / "candidates.json", cands)

    rec = merge_record(cands, review, base, include_machine=args.include_machine)
    rec["meeting"]["started_at"] = rec["meeting"].get("started_at") or f"{base.isoformat()}T00:00:00"
    rec["meeting"].setdefault("duration_minutes", None)
    rec.setdefault("sources", {})
    rec["sources"] = {
        "transcript": str(Path(args.transcript)),
        "segments": len(segments),
        "speakers": participants,
        "extractor": f"meeting-outcomes {VERSION}",
        **rec.get("sources", {}),
    }
    for a in rec["actions"]:
        a.setdefault("date_unresolved", a.get("due_at") is None)
    dump_json(outdir / "record.json", rec)

    errors, warnings = validate_record(rec)
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    if errors:
        print(f"INVALID — {len(errors)} error(s); nothing rendered", file=sys.stderr)
        return 1

    written = render_all(rec, outdir)
    dump_json(outdir / "cards.json", {"cards": render_cards(rec)})
    print(f"ok: {len(segments)} segments, {len(rec['decisions'])} decisions, "
          f"{len(rec['actions'])} actions; {len(written)} documents -> {outdir}")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="meeting-outcomes", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--version", action="version", version=VERSION)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("parse")
    s.add_argument("transcript")
    s.add_argument("--out", required=True)
    s.set_defaults(func=cmd_parse)

    s = sub.add_parser("extract")
    s.add_argument("segments")
    s.add_argument("--date", required=True)
    s.add_argument("--out", required=True)
    s.set_defaults(func=cmd_extract)

    s = sub.add_parser("merge")
    s.add_argument("candidates", nargs="?")
    s.add_argument("--review", required=True)
    s.add_argument("--date", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("--include-machine", action="store_true")
    s.set_defaults(func=cmd_merge)

    s = sub.add_parser("validate")
    s.add_argument("record")
    s.set_defaults(func=cmd_validate)

    s = sub.add_parser("render")
    s.add_argument("record")
    s.add_argument("--outdir", required=True)
    s.set_defaults(func=cmd_render)

    s = sub.add_parser("cards")
    s.add_argument("record")
    s.add_argument("--out", required=True)
    s.set_defaults(func=cmd_cards)

    s = sub.add_parser("pipeline")
    s.add_argument("transcript")
    s.add_argument("--date", required=True)
    s.add_argument("--title")
    s.add_argument("--review", required=True)
    s.add_argument("--outdir", required=True)
    s.add_argument("--include-machine", action="store_true")
    s.set_defaults(func=cmd_pipeline)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
