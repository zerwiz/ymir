#!/usr/bin/env python3
"""snotra-letter — one letter per participant, from the record, with their own tasks in it.

WHY: the participants left the meeting with decisions about their work, and the house sent them a letter
that said "no decisions were taken" (2026-10-23). A letter that does not carry the person's own actions,
the decisions that touch their work and the questions they owe is a letter that causes a meeting.

WHAT IT DOES
    render  <meeting-dir>          write letters/<person>.md and .html from record.json — no sending
    draft   <meeting-dir>          one Gmail DRAFT per person (mail-send.sh draft), recorded in letters.json
    status  <meeting-dir>          who has a letter, a draft, an approval, a send
    send    <meeting-dir> --approved   send the prepared drafts — refuses without the operator's word
                                    AND without a valid approval record (snotra-approve.sh check)

THE LAWS
    * the record is the only source: an action, a decision or a question that is not in `record.json`
      cannot appear in a letter;
    * the coverage is stated, never implied: a record reconstructed from a partial source says so
      (Rule 33), because the participant is being asked to correct it;
    * the letter names what it attaches (Rule 31) and what it asks for, with a date from the place's
      cadence (not from this file);
    * nothing is sent by this door alone: `--approved` plus `snotra-approve.sh check` on the draft id.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T  # noqa: E402
KEY = "record-key"


def die(msg: str, code: int = 1):
    print(f"snotra-letter: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def load_yaml(path: Path) -> dict:
    try:
        import yaml  # noqa: PLC0415
    except Exception:  # noqa: BLE001
        die("PyYAML is missing: pip install pyyaml")
    if not path.is_file():
        return {}
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def home() -> Path:
    """The hoard is resolved through the one resolver, never restated here."""
    return T.home_dir()


def slugify(s: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", (s or "").lower()).strip("-")
    return s or "person"


def place_of(rec: dict) -> dict:
    m = rec.get("meeting") or {}
    p = home() / "hodd" / "identity" / "places" / (m.get("company") or "_") / (m.get("place") or "_") / "place.yaml"
    return load_yaml(p)



def confirm_action(rec: dict) -> dict | None:
    """The action in the record that asks for confirmation — returned whole, so the letter can quote it."""
    for a in rec.get("actions") or []:
        t = ((a.get("deliverable") or "") + " " + (a.get("definition_of_done") or "")).lower()
        if "confirm" in t or "correct" in t:
            return a
    return None


def record_note(rec: dict) -> tuple[str | None, str | None]:
    """The record's own caveat about provisional state, verbatim, with its risk id — or nothing.

    A letter may not state a consequence the record does not carry. On 2026-10-23 the letter said
    "silence is recorded as provisional acceptance" — a policy nobody agreed to. The record's own words
    were narrower: "grade and approver are provisional until confirmed" (RSK-20261022-02).
    """
    for r in rec.get("risks") or []:
        text = (r.get("mitigation") or "").strip()
        if not text:
            continue
        low = (text + " " + (r.get("risk") or "")).lower()
        if any(k in low for k in ("provisional", "confirm", "approver")):
            return text, r.get("risk_id")
    return None, None


def business_days_after(iso_date: str, n: int) -> str:
    d = datetime.strptime(iso_date[:10], "%Y-%m-%d")
    added = 0
    while added < n:
        d += timedelta(days=1)
        if d.weekday() < 5:
            added += 1
    return d.strftime("%Y-%m-%d")


def _facts(rec: dict, place: dict, person: dict) -> dict:
    m = rec.get("meeting") or {}
    name = person.get("name") or "colleague"
    cadence = place.get("cadence") or {}
    roles = place.get("roles") or {}
    held = str(m.get("started_at") or "")[:10]
    days = int(cadence.get("signoff_business_days") or 2)
    return {
        "name": name,
        "title": m.get("title") or "the meeting",
        "held": held,
        "when": str(m.get("started_at") or "").replace("T", " ")[:16],
        # A letter's deadline must be the one the ROOM set. The 22 Oct record carries ACT-20261022-03
        # "confirm or correct this record within two business days" — due 2026-10-24. Computing 26 Oct from
        # the cadence produced a letter that contradicted its own record (seen by the Allfather, 2026-10-23).
        "ask": confirm_action(rec),
        "note": record_note(rec)[0],
        "note_id": record_note(rec)[1],
        "due": (str((confirm_action(rec) or {}).get("due_at") or "")[:10]
                or business_days_after(held, days)),
        "due_action": (confirm_action(rec) or {}).get("action_id"),
        "days": days,
        "chair": (roles.get("chair") or "").strip(),
        "sender": (roles.get("operator") or roles.get("chair") or "").strip(),
        "mine": [a for a in (rec.get("actions") or [])
                 if (a.get("owner") or "").strip().lower() == name.strip().lower()],
        "decisions": rec.get("decisions") or [],
        "questions": rec.get("questions") or [],
        "actions_total": len(rec.get("actions") or []),
        "cov": m.get("coverage") or {},
        "attachments": [f for f in ("record.pdf", "decisions.md", "actions.md", "minutes.md", "questions.md")
                        if (Path(person.get("_dir") or ".") / f).is_file()],
    }


def subject_for(rec: dict, place: dict, person: dict) -> str:
    f = _facts(rec, place, person)
    return f"{f['title']} — your actions and the record · confirm by {f['due']}"


def letter_text(rec: dict, place: dict, person: dict) -> str:
    """Plain text is a FORMAT, not a fallback: no markdown, no headings syntax, short lines,
    the ask marked with *, and every attachment named in full."""
    f = _facts(rec, place, person)
    W = 72
    def wrap(prefix: str, text: str) -> list[str]:
        words, lines, cur = (text or "").split(), [], prefix
        for w in words:
            if len(cur) + len(w) + 1 > W and cur.strip():
                lines.append(cur.rstrip()); cur = " " * len(prefix)
            cur += ("" if cur.endswith((" ", '"')) or not cur.strip() else " ") + w
        if cur.strip():
            lines.append(cur.rstrip())
        return lines or [prefix.rstrip()]
    L: list[str] = []
    L.append(f["name"] + ",")
    L.append("")
    for line in wrap("", f"Here is the record of {f['title']}, held {f['held']}. This is the record itself, "
                          f"not a summary: {len(f['decisions'])} decisions, {f['actions_total']} actions and "
                          f"{len(f['questions'])} open questions."):
        L.append(line)
    L.append("")
    L.append("YOUR ACTIONS")
    if f["mine"]:
        for a in f["mine"]:
            due = a.get("due_at") or ("date unresolved" if a.get("date_unresolved") else "no date")
            for line in wrap("  - ", f"{a.get('deliverable')} (due {due}). "
                                      f"Done when: {a.get('definition_of_done') or 'to be agreed'}."):
                L.append(line)
    else:
        L.append("  You own no action from this meeting.")
    L.append("")
    L.append("THE DECISIONS")
    for grp in ("A", "B", "C"):
        rows = [d for d in f["decisions"] if (d.get("grade") or "").upper() == grp]
        if not rows:
            continue
        L.append(f"  Grade {grp}")
        for d in rows:
            mark = " (you decided)" if (d.get("decided_by") or "").strip().lower() == f["name"].lower() else ""
            for line in wrap("    - ", f"{d.get('statement')}{mark}"):
                L.append(line)
        L.append("")
    if f["questions"]:
        L.append("OPEN QUESTIONS")
        for q in f["questions"]:
            for line in wrap("  - ", q.get("question") or ""):
                L.append(line)
        L.append("")
    L.append("* WHAT I NEED FROM YOU")
    ask = f.get("ask") or {}
    if ask:
        owner = ask.get("owner") or "unowned"
        for line in wrap("  ", f"The record carries this action — {ask.get('action_id')}, "
                               f"owned by {owner}:"):
            L.append(line)
        for line in wrap("    ", f"\"{(ask.get('deliverable') or '').rstrip('.')}.\""):
            L.append(line)
        if ask.get("definition_of_done"):
            for line in wrap("    Done when: ", ask["definition_of_done"].rstrip(".") + "."):
                L.append(line)
        if ask.get("due_at"):
            L.append(f"    By: {str(ask['due_at'])[:10]}")
        if f["name"].lower() != owner.lower() and ask.get("definition_of_done"):
            L.append("")
            for line in wrap("  ", f"Your part: {ask['definition_of_done'].rstrip('.')}."):
                L.append(line)
    else:
        L.append("  The record carries no confirmation action — review the record and reply with corrections.")
    if f.get("note"):
        L.append("")
        for line in wrap("  ", f"Note ({f.get('note_id') or 'the record'}): {f['note']}."):
            L.append(line)
    L.append("")
    L.append("WHAT THIS RECORD COVERS")
    cov = f["cov"]
    src = cov.get("audio_source") or "declared in the record"
    for line in wrap("  ", f"{src}."):
        L.append(line)
    if cov.get("missing_before"):
        for line in wrap("  ", f"Missing before: {cov['missing_before']}."):
            L.append(line)
    if cov.get("diarisation"):
        for line in wrap("  ", f"Speaker attribution: {cov['diarisation']}."):
            L.append(line)
    L.append("")
    if f["attachments"]:
        L.append("ATTACHED")
        for a in f["attachments"]:
            L.append(f"  - {a}")
        L.append("")
    if f["chair"]:
        L.append(f"Reygan, as chair, holds the register." if f["chair"].split()[0].lower() == "reygan"
                 else f"{f['chair']} holds the register.")
        L.append("")
    L.append(f"— {f['sender'] or 'the house'}")
    L.append("")
    L.append(f"Sent from the house system on the operator's approval. The record lives in the vault under "
             f"{(rec.get('meeting') or {}).get('meeting_id') or 'this meeting'}; nothing here is edited after "
             f"sending — corrections are appended.")
    return "\n".join(L) + "\n"


def esc(s: str) -> str:
    return (str(s or "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;"))


CSS = """
body{margin:0;padding:0;background:#f4f4f3;-webkit-text-size-adjust:100%;}
.wrap{width:100%;background:#f4f4f3;padding:24px 12px;}
.card{max-width:600px;margin:0 auto;background:#ffffff;border:1px solid #e3e3e0;border-radius:10px;}
.pad{padding:28px 32px;}
body,h1,h2,h3,p,li,td{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;}
h1{font-size:21px;line-height:1.3;margin:0 0 4px;color:#141413;font-weight:650;letter-spacing:-.01em;}
h2{font-size:13px;line-height:1.4;margin:28px 0 8px;color:#5b5b56;font-weight:650;text-transform:uppercase;letter-spacing:.08em;}
p,li{font-size:15.5px;line-height:1.62;color:#26261f;margin:0 0 10px;}
.kicker{font-size:13px;color:#5b5b56;margin:0 0 18px;}
.meta{font-size:13px;color:#5b5b56;border-top:1px solid #ececea;border-bottom:1px solid #ececea;padding:10px 0;margin:0 0 4px;}
ul{margin:0 0 6px;padding-left:20px;}
li{margin:0 0 7px;}
.grade{font-size:12px;font-weight:650;color:#5b5b56;text-transform:uppercase;letter-spacing:.08em;margin:14px 0 4px;}
.ask{background:#fbf6ea;border:1px solid #e8dcc0;border-left:4px solid #b8860b;border-radius:6px;padding:16px 18px;margin:8px 0 0;}
.ask p{font-size:15.5px;color:#3a3427;margin:0;}
.note{background:#f7f7f6;border:1px solid #ececea;border-radius:6px;padding:14px 16px;}
.note p{font-size:13.5px;color:#5b5b56;margin:0 0 6px;}
.foot{font-size:12.5px;line-height:1.6;color:#6b6b64;padding:0 32px 26px;}
.sign{font-size:15.5px;color:#26261f;margin:22px 0 2px;}
.muted{color:#6b6b64;}
"""


def company_name(cid: str) -> str:
    """The company's display name from the registry; the id title-cased when it has none."""
    try:
        import yaml  # noqa: PLC0415
        f = home() / "hodd" / "identity" / "companies.yaml"
        if f.is_file():
            for c in (yaml.safe_load(f.read_text(encoding="utf-8")) or {}).get("companies") or []:
                if (c.get("id") or "").lower() == (cid or "").lower():
                    return c.get("name") or cid.title()
    except Exception:  # noqa: BLE001
        pass
    return (cid or "").replace("-", " ").title()


def initials(name: str) -> str:
    parts = [x for x in (name or "").split() if x]
    return (parts[0][0] + parts[-1][0]).upper() if len(parts) > 1 else (parts[0][:2].upper() if parts else "—")


def next_monday(held: str, at: str) -> str:
    from datetime import date, datetime, timedelta
    try:
        d = datetime.strptime((held or "")[:10], "%Y-%m-%d").date()
    except ValueError:
        d = date.today()
    d += timedelta(days=1)
    while d.weekday() != 0:
        d += timedelta(days=1)
    return d.strftime("%Y-%m-%d")


CHIP = {"A": ("background:#fbeaea;color:#d64545", "Critical"),
        "B": ("background:#fdf3e2;color:#e08a00", "Important"),
        "C": ("background:#f0f3f7;color:#6b7a8d", "Standard")}


def letter_html(rec: dict, place: dict, person: dict) -> str:
    """The letter as a designed page: every value from the record, no sentence the record cannot cite."""
    f = _facts(rec, place, person)
    m = rec.get("meeting") or {}
    e = esc
    company = company_name(m.get("company") or "")
    people = ", ".join(p.get("name") or "" for p in (rec.get("participants") or []) if p.get("present") is not False)
    decs = f["decisions"]
    qs = f["questions"]
    acts = rec.get("actions") or []
    ask = f.get("ask") or {}
    # actions grouped by owner, counted — the record's own owners, nothing inferred
    owners: dict[str, int] = {}
    for a in acts:
        owners[(a.get("owner") or "unowned")] = owners.get((a.get("owner") or "unowned"), 0) + 1
    attach_rows = []
    for a in f["attachments"]:
        ext = a.rsplit(".", 1)[-1].upper()
        label = {"PDF": "Meeting Record", "MD": a.replace(".md", "").replace("-", " ").title(),
                 "TXT": "Raw transcript"}.get(ext, a)
        attach_rows.append((ext, label))
    nm = next_monday(f["held"], (place.get("cadence") or {}).get("monday_at") or "09:00")

    parts: list[str] = []
    A = parts.append
    A(f'<tr><td style="background:#12263f;padding:30px 36px 26px;border-bottom:3px solid #2f6f8f;">'
      f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
      f'<td style="vertical-align:middle;">'
      f'<div style="color:#9fb3c8;font-size:11px;letter-spacing:2px;text-transform:uppercase;font-weight:600;">{e(company)}</div>'
      f'<div style="color:#ffffff;font-size:24px;font-weight:600;margin-top:8px;line-height:1.2;letter-spacing:-0.2px;">{e(f["title"])}</div>'
      f'<div style="color:#9fb3c8;font-size:13px;margin-top:8px;">{e(f["held"])} &nbsp;·&nbsp; {e(people)}</div>'
      f'</td><td align="right" style="vertical-align:top;">'
      f'<div style="display:inline-block;padding:6px 12px;background:rgba(47,111,143,.25);border:1px solid #2f6f8f;border-radius:20px;color:#cfe3ef;font-size:10.5px;letter-spacing:1.2px;text-transform:uppercase;font-weight:600;">Meeting Record</div>'
      f'</td></tr></table></td></tr>')

    A(f'<tr><td style="padding:32px 36px 4px;font-size:15px;line-height:1.65;">'
      f'<p style="margin:0 0 14px;">Hi {e(f["name"].split()[0])},</p>'
      f'<p style="margin:0 0 14px;">Here is the record of the <strong style="color:#12263f;">{e(f["title"])}</strong> '
      f'call — what we decided and who does what next.</p></td></tr>')

    A('<tr><td style="padding:22px 36px 0;"><table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
      'style="background:#f4f7fb;border-radius:10px;overflow:hidden;"><tr>')
    for i, (n, label) in enumerate(((len(decs), "Decisions"), (len(qs), "Open Questions"), (len(acts), "Actions"))):
        border = "border-right:1px solid #e5ebf1;" if i < 2 else ""
        A(f'<td width="33.33%" style="padding:14px 18px;{border}text-align:center;">'
          f'<div style="font-size:22px;font-weight:700;color:#12263f;line-height:1;">{n}</div>'
          f'<div style="font-size:11px;letter-spacing:1px;text-transform:uppercase;color:#7b8794;margin-top:5px;font-weight:600;">{label}</div></td>')
    A('</tr></table></td></tr>')

    # ── decisions, grouped by grade, chips in the record's own grade ──
    A('<tr><td style="padding:28px 36px 0;"><div style="border-top:1px solid #e5ebf1;padding-top:20px;">'
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
      '<td style="vertical-align:middle;"><span style="font-size:11.5px;letter-spacing:1.5px;text-transform:uppercase;color:#52606d;font-weight:700;">The decisions</span></td>'
      '<td align="right" style="vertical-align:middle;"><span style="font-size:11px;color:#9aa8b6;">Graded A · B · C by criticality</span></td>'
      '</tr></table><table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:14px;font-size:14.5px;line-height:1.55;">')
    A('<tr><td colspan="2" style="padding:0 0 12px;">' + "".join(
        f'<span style="display:inline-block;margin-right:14px;font-size:11.5px;color:#7b8794;">'
        f'<span style="display:inline-block;width:9px;height:9px;background:{c};border-radius:2px;vertical-align:middle;margin-right:5px;"></span>'
        f'Grade {g} · {lab}</span>'
        for g, (st, lab), c in (("A", CHIP["A"], "#d64545"), ("B", CHIP["B"], "#e08a00"), ("C", CHIP["C"], "#9aa8b6"))) + '</td></tr>')
    ordered = sorted(decs, key=lambda d: {"A": 0, "B": 1, "C": 2}.get((d.get("grade") or "").upper(), 3))
    for i, d in enumerate(ordered):
        g = (d.get("grade") or "").upper()
        style, _ = CHIP.get(g, CHIP["C"])
        last = 'border-bottom:1px solid #f0f3f7;' if i == len(ordered) - 1 else ''
        A(f'<tr><td width="44" style="padding:11px 0;border-top:1px solid #f0f3f7;{last}vertical-align:top;">'
          f'<span style="display:inline-block;width:26px;text-align:center;padding:3px 0;{style};border-radius:4px;font-size:10.5px;font-weight:700;letter-spacing:.5px;">{g or "—"}</span></td>'
          f'<td style="padding:11px 0 11px 4px;border-top:1px solid #f0f3f7;{last}color:#243b53;">{e(d.get("statement"))}</td></tr>')
    A('</table><div style="margin-top:10px;font-size:12px;color:#9aa8b6;font-style:italic;">All decisions are pending '
      'confirmation until the chair signs the record.</div></div></td></tr>')

    # ── open questions ──
    if qs:
        A('<tr><td style="padding:26px 36px 0;"><div style="border-top:1px solid #e5ebf1;padding-top:20px;">'
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
          '<td><span style="font-size:11.5px;letter-spacing:1.5px;text-transform:uppercase;color:#52606d;font-weight:700;">Open questions</span></td>'
          '<td align="right"><span style="font-size:11px;color:#9aa8b6;">Asked by</span></td></tr></table>'
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:14px;font-size:14.5px;line-height:1.5;">')
        for i, q in enumerate(qs, 1):
            if i > 1:
                A('<tr><td height="8" style="line-height:8px;font-size:0;">&nbsp;</td></tr>')
            who = q.get("asked_by") or ""
            A('<tr><td style="padding:13px 14px;background:#f7f9fc;border:1px solid #e2e9f1;border-radius:8px;border-left:3px solid #2f6f8f;">'
              '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
              f'<td style="vertical-align:top;color:#9aa8b6;font-size:13px;font-weight:600;padding-right:10px;width:18px;">{i}.</td>'
              f'<td style="vertical-align:top;color:#243b53;">{e(q.get("question"))}</td></tr>'
              + (f'<tr><td colspan="2" style="padding-top:8px;"><span style="display:inline-block;font-size:11.5px;color:#52606d;font-weight:600;">{e(who)}</span></td></tr>' if who else "")
              + '</table></td></tr>')
        A('</table></div></td></tr>')

    # ── who does what ──
    if owners:
        A('<tr><td style="padding:26px 36px 0;"><div style="border-top:1px solid #e5ebf1;padding-top:20px;">'
          '<div style="font-size:11.5px;letter-spacing:1.5px;text-transform:uppercase;color:#52606d;font-weight:700;margin-bottom:12px;">Who does what</div>'
          '<div style="background:#f7f9fc;border:1px solid #e2e9f1;border-radius:10px;padding:18px 20px;">'
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;font-size:14px;">'
          '<tr><td style="padding:10px 0;border-bottom:1px solid #edf1f5;color:#9aa8b6;font-size:11px;letter-spacing:1px;text-transform:uppercase;font-weight:700;">Assignee</td>'
          '<td align="right" style="padding:10px 0;border-bottom:1px solid #edf1f5;color:#9aa8b6;font-size:11px;letter-spacing:1px;text-transform:uppercase;font-weight:700;">Open actions</td></tr>')
        for who, n in sorted(owners.items(), key=lambda kv: -kv[1]):
            A('<tr><td style="padding:13px 0;border-bottom:1px solid #edf1f5;">'
              '<table role="presentation" cellpadding="0" cellspacing="0"><tr>'
              f'<td style="vertical-align:middle;"><div style="width:32px;height:32px;border-radius:50%;background:#2f6f8f;color:#ffffff;text-align:center;line-height:32px;font-size:13px;font-weight:600;">{e(initials(who))}</div></td>'
              f'<td style="vertical-align:middle;padding-left:12px;color:#243b53;font-weight:500;">{e(who)}</td>'
              '</tr></table></td>'
              f'<td align="right" style="padding:13px 0;border-bottom:1px solid #edf1f5;vertical-align:middle;">'
              f'<span style="display:inline-block;background:#2f6f8f;color:#ffffff;font-size:13px;font-weight:700;padding:5px 14px;border-radius:14px;">{n}</span></td></tr>')
        A('<tr><td colspan="2" style="padding:13px 0 0;font-size:12px;color:#9aa8b6;line-height:1.5;">'
          'Action details are in the attached action register.</td></tr></table></div></div></td></tr>')

    # ── attachments, the ones this letter actually carries ──
    if attach_rows:
        A('<tr><td style="padding:26px 36px 0;"><div style="border-top:1px solid #e5ebf1;padding-top:20px;">'
          '<div style="font-size:11.5px;letter-spacing:1.5px;text-transform:uppercase;color:#52606d;font-weight:700;margin-bottom:12px;">Attached</div>'
          '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>')
        for i, (ext, label) in enumerate(attach_rows):
            if i and i % 2 == 0:
                A('</tr><tr>')
            A(f'<td style="padding:0 0 10px;width:50%;vertical-align:top;">'
              f'<div style="display:inline-block;margin:0 6px 8px 0;padding:9px 13px;background:#f2f6fa;border:1px solid #dbe4ec;border-radius:8px;font-size:12.5px;color:#243b53;">'
              f'<span style="color:#2f6f8f;font-weight:700;margin-right:6px;">{e(ext)}</span>{e(label)}</div></td>')
        A('</tr></table></div></td></tr>')

    # ── the ask, quoted from the record ──
    A('<tr><td style="padding:26px 36px 0;">'
      '<div style="border-left:3px solid #2f6f8f;background:#f7fafc;padding:18px 20px;border-radius:0 8px 8px 0;">'
      '<div style="color:#12263f;font-size:15px;font-weight:700;">What I need from you</div>'
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="margin-top:10px;font-size:14.5px;line-height:1.55;">')
    if ask:
        owner = ask.get("owner") or "unowned"
        A(f'<tr><td style="vertical-align:top;color:#243b53;padding-bottom:8px;">'
          f'<em>&ldquo;{e((ask.get("deliverable") or "").rstrip("."))}&rdquo;</em> '
          f'<span style="color:#7b8794;font-size:12.5px;">— {e(ask.get("action_id") or "")}, owned by {e(owner)}</span>'
          + (f'<br><span style="color:#7b8794;font-size:12.5px;">Done when: {e(ask.get("definition_of_done"))} · By: {e(str(ask.get("due_at"))[:10])}</span>' if ask.get("definition_of_done") or ask.get("due_at") else "")
          + '</td></tr>')
    if f.get("note"):
        A(f'<tr><td style="vertical-align:top;color:#5b6b7c;font-size:13px;">'
          f'{e(f.get("note_id") or "Note")}: {e(f["note"])}.</td></tr>')
    A('</table></div></td></tr>')

    # ── how to answer (the letter's own instruction, not a claim about the meeting) ──
    A('<tr><td style="padding:18px 36px 0;"><div style="background:#f7fafc;border:1px solid #e2e9f1;border-radius:10px;padding:16px 18px;">'
      '<div style="color:#12263f;font-size:14.5px;font-weight:700;">How to answer</div>'
      '<div style="color:#5b6b7c;font-size:13px;margin-top:6px;line-height:1.55;">'
      'Reply <strong style="background:#eef4ed;color:#2d7a46;padding:1px 7px;border-radius:4px;">confirm</strong> to sign the record, '
      'or <strong style="background:#fdeeee;color:#c0392b;padding:1px 7px;border-radius:4px;">objection: &lt;what is wrong&gt;</strong> to correct it. '
      f'Name the decision id (e.g. <span style="color:#243b53;">{e((decs[0] or {}).get("decision_id") or "DEC-…")}</span>) when you answer one decision — '
      'a reply that names no id counts as the whole record, not as fourteen signatures.</div></div></td></tr>')

    # ── next meeting (proposed) ──
    A('<tr><td style="padding:18px 36px 0;"><div style="background:#f7fafc;border:1px solid #e2e9f1;border-radius:10px;padding:16px 18px;">'
      '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr>'
      '<td style="vertical-align:top;width:60px;padding-right:14px;">'
      f'<div style="background:#ffffff;border:1px solid #e2e9f1;border-radius:8px;padding:8px 0;text-align:center;">'
      f'<div style="font-size:20px;font-weight:700;color:#12263f;line-height:1.1;">{e(nm[8:10])}</div>'
      f'<div style="font-size:10px;color:#9aa8b6;">{e(nm[:7])}</div></div></td>'
      '<td style="vertical-align:middle;"><div style="color:#12263f;font-size:14.5px;font-weight:700;">Next meeting — proposed</div>'
      f'<div style="color:#5b6b7c;font-size:13px;margin-top:3px;line-height:1.45;">{e(nm)} at {e((place.get("cadence") or {}).get("monday_at") or "09:00")} — the weekly review: what was planned, what is done, what is blocked.</div>'
      '<div style="margin-top:8px;font-size:13px;color:#243b53;line-height:1.5;">The agenda card is on the board; the first item is the register above.</div>'
      '</td></tr></table></div></td></tr>')

    # ── sign-off ──
    A('<tr><td style="padding:26px 36px 30px;font-size:14.5px;line-height:1.65;">'
      '<p style="margin:0 0 14px;">A short reply is enough. If the format is wrong, say so plainly.</p>'
      f'<p style="margin:18px 0 2px;">Best,<br>{e((f["sender"] or "the house").split()[0])}</p>'
      '<div style="margin-top:22px;padding-top:16px;border-top:1px solid #e5ebf1;color:#52606d;font-size:13px;line-height:1.55;">'
      f'<strong style="color:#12263f;">{e(f["sender"] or "")}</strong><br>{e(company)} &nbsp;·&nbsp; <a href="mailto:{e(person.get("email") or "")}" style="color:#2f6f8f;text-decoration:none;">{e(person.get("email") or "")}</a></div>'
      '<div style="margin-top:10px;color:#9aa8b6;font-size:11.5px;line-height:1.5;">'
      'Sent from the house system on the operator\'s approval. '
      f"The record lives in the vault under {e((m.get('meeting_id') or ''))}; nothing here is edited after "
      'sending — a correction is appended.</div></td></tr>')

    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{e(subject_for(rec, place, person))}</title></head>
<body style="margin:0;padding:0;background:#eef2f6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#243b53;-webkit-font-smoothing:antialiased;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#eef2f6;padding:32px 12px;"><tr><td align="center">
<table role="presentation" width="640" cellpadding="0" cellspacing="0" style="width:100%;max-width:640px;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(18,38,63,.08);">
{''.join(parts)}
</table>
<div style="max-width:640px;margin:14px auto 0;color:#9aa8b6;font-size:11px;text-align:center;line-height:1.5;">
You received this record because you attended the meeting. Reply to confirm or to raise an objection.</div>
</td></tr></table></body></html>
"""


def render(d: Path) -> int:
    rec = json.loads((d / "record.json").read_text(encoding="utf-8"))
    place = place_of(rec)
    outdir = d / "letters"
    outdir.mkdir(exist_ok=True)
    n = 0
    for p in rec.get("participants") or []:
        if p.get("present") is False:
            continue
        p = dict(p); p["_dir"] = str(d)
        txt = letter_text(rec, place, p)
        html = letter_html(rec, place, p)
        subject = subject_for(rec, place, p)
        slug = slugify(p.get("name") or "")
        (outdir / f"{slug}.txt").write_text(txt, encoding="utf-8")
        (outdir / f"{slug}.html").write_text(html, encoding="utf-8")
        (outdir / f"{slug}.md").write_text(txt, encoding="utf-8")
        n += 1
        say(f"letter{{person:{p.get('name')},subject:{subject!r},text:letters/{slug}.txt,"
            f"html:letters/{slug}.html}}")
    say(f"render{{letters:{n},dir:{outdir}}}")
    return 0


def drafts(d: Path) -> int:
    rec = json.loads((d / "record.json").read_text(encoding="utf-8"))
    place = place_of(rec)
    statep = d / "letters.json"
    state = json.loads(statep.read_text(encoding="utf-8")) if statep.is_file() else {"people": []}
    mail = ROOT / "bin" / "time" / "snotra" / "mail-send.sh"
    if not mail.is_file():
        die(f"no mail door at {mail}")
    made = 0
    for p in rec.get("participants") or []:
        if p.get("present") is False or not p.get("email"):
            continue
        slug = slugify(p.get("name") or "")
        txt_p = d / "letters" / f"{slug}.txt"
        html_p = d / "letters" / f"{slug}.html"
        if not txt_p.is_file():
            die(f"no letter for {p.get('name')} — run render first")
        pp = dict(p); pp["_dir"] = str(d)
        subject = subject_for(rec, place, pp)
        attaches: list[str] = []
        for line in txt_p.read_text(encoding="utf-8").splitlines():
            m2 = re.match(r"^  - (\S+)$", line)
            if m2 and (d / m2.group(1)).is_file():
                attaches += ["--attach", str((d / m2.group(1)).resolve())]
        cmd = ["bash", str(mail), "draft", "--to", p["email"], "--subject", subject,
               "--body", str(txt_p.resolve())]
        if html_p.is_file():
            cmd += ["--html", str(html_p.resolve())]
        cmd += ["--record", str(d.resolve())] + attaches
        res = subprocess.run(cmd, capture_output=True, text=True)
        line = (res.stdout or "").strip().splitlines()[-1] if res.stdout.strip() else res.stderr.strip()[:200]
        m = re.search(r"draft\t(\S+)", res.stdout or "")
        if not m:
            say(f"failed{{person:{p.get('name')},message:{line!r}}}")
            continue
        did = m.group(1)
        state["people"] = [x for x in state.get("people", []) if x.get("name") != p.get("name")]
        state["people"].append({"name": p.get("name"), "email": p["email"], "draftId": did,
                                "letter": f"letters/{slug}.md", "sent": None, "approved": None})
        made += 1
        say(f"draft{{person:{p.get('name')},draft:{did},to:{p['email']},attachments:{len(attaches) // 2}}}")
    statep.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    say(f"drafts{{made:{made},state:{statep}}}")
    return 0


def status(d: Path) -> int:
    statep = d / "letters.json"
    if not statep.is_file():
        say("letters{none:'no drafts prepared'}")
        return 0
    state = json.loads(statep.read_text(encoding="utf-8"))
    for p in state.get("people", []):
        verdict = "sent" if p.get("sent") else ("approved" if p.get("approved") else "draft")
        say(f"person{{name:{p['name']},state:{verdict},draft:{p.get('draftId')}}}")
    return 0


def send(d: Path) -> int:
    if "--approved" not in sys.argv:
        die("refused: sending needs the operator's word — `send --approved` after `snotra-approve.sh approve <draft-id>`")
    statep = d / "letters.json"
    if not statep.is_file():
        die("nothing prepared — run draft first", 2)
    state = json.loads(statep.read_text(encoding="utf-8"))
    mail = ROOT / "bin" / "time" / "snotra" / "mail-send.sh"
    approve = ROOT / "bin" / "time" / "snotra" / "snotra-approve.sh"
    # a TEST must be possible: `--person "<name>"` or `--to <email>` sends exactly one letter, so a trial
    # can never become a broadcast by accident.
    only_name = only_to = None
    for i, a in enumerate(sys.argv):
        if a == "--person" and i + 1 < len(sys.argv):
            only_name = sys.argv[i + 1].strip().lower()
        if a == "--to" and i + 1 < len(sys.argv):
            only_to = sys.argv[i + 1].strip().lower()
    sent = 0
    for p in state.get("people", []):
        if only_name and (p.get("name") or "").strip().lower() != only_name:
            continue
        if only_to and (p.get("email") or "").strip().lower() != only_to:
            continue
        if p.get("sent"):
            continue
        chk = subprocess.run(["bash", str(approve), "check", p["draftId"]], capture_output=True, text=True)
        if chk.returncode != 0:
            say(f"held{{person:{p['name']},why:'no valid approval for draft {p['draftId']}'}}")
            continue
        res = subprocess.run(["bash", str(mail), "send", p["draftId"]], capture_output=True, text=True)
        if res.returncode != 0:
            say(f"failed{{person:{p['name']},why:{(res.stderr or res.stdout or '').strip()[:120]!r}}}")
            continue
        p["sent"] = {"at": datetime.now().astimezone().isoformat(timespec="seconds"),
                     "out": (res.stdout or "").strip()[:200]}
        sent += 1
        say(f"sent{{person:{p['name']},draft:{p['draftId']}}}")
    statep.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    say(f"send{{sent:{sent}}}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd, d = argv[1], Path(argv[2]).expanduser().resolve()
    if not (d / "record.json").is_file():
        die(f"no record.json in {d}")
    if cmd == "render":
        return render(d)
    if cmd == "draft":
        return drafts(d)
    if cmd == "status":
        return status(d)
    if cmd == "send":
        return send(d)
    die(f"unknown command {cmd!r} — render | draft | status | send", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
