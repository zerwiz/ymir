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
    h = os.environ.get("YMIR_HOME")
    return Path(h).expanduser() if h else Path(os.path.expanduser("~/Documents/ymirhome"))


def slugify(s: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", (s or "").lower()).strip("-")
    return s or "person"


def place_of(rec: dict) -> dict:
    m = rec.get("meeting") or {}
    p = home() / "hodd" / "identity" / "places" / (m.get("company") or "_") / (m.get("place") or "_") / "place.yaml"
    return load_yaml(p)


def business_days_after(iso_date: str, n: int) -> str:
    d = datetime.strptime(iso_date[:10], "%Y-%m-%d")
    added = 0
    while added < n:
        d += timedelta(days=1)
        if d.weekday() < 5:
            added += 1
    return d.strftime("%Y-%m-%d")


def letter(rec: dict, place: dict, person: dict) -> tuple[str, str, str]:
    """Return (subject, markdown, html) for one participant."""
    m = rec.get("meeting") or {}
    name = person.get("name") or "colleague"
    title = m.get("title") or "the meeting"
    held = str(m.get("started_at") or "")[:10]
    mid = m.get("meeting_id") or ""
    cadence = place.get("cadence") or {}
    days = int(cadence.get("signoff_business_days") or 2)
    due = business_days_after(held, days)

    mine = [a for a in (rec.get("actions") or []) if (a.get("owner") or "").strip().lower() == name.strip().lower()]
    decs = rec.get("decisions") or []
    qs = rec.get("questions") or []
    cov = m.get("coverage") or {}
    attachments = ["record.pdf", "decisions.md", "actions.md"]

    L: list[str] = []
    L.append(f"# {title} — {held}")
    L.append("")
    L.append(f"{name},")
    L.append("")
    L.append(f"Here is what we took from the meeting on {held}. This is the record, not a summary: "
             f"it holds {len(decs)} decisions, {len(rec.get('actions') or [])} actions and {len(qs)} open questions.")
    L.append("")
    L.append("## Your actions")
    if mine:
        for a in mine:
            due_a = a.get("due_at") or ("date unresolved" if a.get("date_unresolved") else "no date")
            L.append(f"- **{a.get('deliverable')}** — due {due_a}. Done when: {a.get('definition_of_done') or 'to be agreed'}.")
    else:
        L.append("- You own no action from this meeting.")
    L.append("")
    L.append("## The decisions")
    for grp in ("A", "B", "C"):
        rows = [d for d in decs if (d.get("grade") or "").upper() == grp]
        if not rows:
            continue
        L.append(f"**Grade {grp}**")
        for d in rows:
            L.append(f"- {d.get('statement') or d.get('title')}")
    L.append("")
    if qs:
        L.append("## Open questions")
        for q in qs:
            L.append(f"- {q.get('question')}")
        L.append("")
    L.append("## What this record covers")
    L.append(f"- Audio source: {cov.get('audio_source') or 'declared in the record'}")
    L.append(f"- Recorded from {cov.get('recorded_from') or '?'}"
             + (f"; missing before {cov.get('missing_before')}" if cov.get("missing_before") else ""))
    if cov.get("diarisation"):
        L.append(f"- Speaker attribution: {cov.get('diarisation')}")
    L.append("")
    L.append("## What I need from you")
    L.append(f"Confirm or correct this record by **{due}** — two business days. Every decision in it is "
             "`proposed` until you confirm; a correction is registered as a new entry, never by editing "
             "the old one. Silence is recorded as provisional acceptance, not as agreement.")
    L.append("")
    L.append("## Attached")
    for a in attachments:
        L.append(f"- {a}")
    L.append("")
    L.append("— sent from the house system, on the operator's approval.")
    md = "\n".join(L) + "\n"

    subject = f"{title} — the record, your actions, and what I need confirmed"
    html = md_to_html(md)
    return subject, md, html


def md_to_html(md: str) -> str:
    out = ["<!doctype html><meta charset=utf-8><title>letter</title>",
           "<style>body{font:16px/1.55 -apple-system,Segoe UI,Roboto,sans-serif;max-width:44rem;margin:2rem auto;padding:0 1rem;color:#141414}"
           "h1{font-size:1.5rem}h2{font-size:1.05rem;margin-top:1.6rem;border-bottom:1px solid #ddd;padding-bottom:.2rem}"
           "li{margin:.2rem 0}</style>"]
    for line in md.splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("# "):
            out.append(f"<h1>{esc(s[2:])}</h1>")
        elif s.startswith("## "):
            out.append(f"<h2>{esc(s[3:])}</h2>")
        elif s.startswith("- "):
            out.append(f"<li>{inline(s[2:])}</li>")
        else:
            out.append(f"<p>{inline(s)}</p>")
    return "\n".join(out) + "\n"


def esc(s: str) -> str:
    return (s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


def inline(s: str) -> str:
    s = esc(s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    return s


def render(d: Path) -> int:
    rec = json.loads((d / "record.json").read_text(encoding="utf-8"))
    place = place_of(rec)
    outdir = d / "letters"
    outdir.mkdir(exist_ok=True)
    n = 0
    for p in rec.get("participants") or []:
        if p.get("present") is False:
            continue
        subject, md, html = letter(rec, place, p)
        slug = slugify(p.get("name") or "")
        (outdir / f"{slug}.md").write_text(md, encoding="utf-8")
        (outdir / f"{slug}.html").write_text(html, encoding="utf-8")
        n += 1
        say(f"letter{{person:{p.get('name')},subject:{subject!r},md:letters/{slug}.md,html:letters/{slug}.html}}")
    say(f"render{{letters:{n},dir:{outdir}}}")
    return 0


def drafts(d: Path) -> int:
    rec = json.loads((d / "record.json").read_text(encoding="utf-8"))
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
        md_p = d / "letters" / f"{slug}.md"
        if not md_p.is_file():
            die(f"no letter for {p.get('name')} — run render first")
        subject = md_p.read_text(encoding="utf-8").splitlines()[0].lstrip("# ").strip()
        res = subprocess.run(["bash", str(mail), "draft", "--to", p["email"], "--subject",
                              f"{subject} — your actions and the record", "--body", str(md_p.resolve()),
                              "--record", str(d.resolve())], capture_output=True, text=True)
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
        say(f"draft{{person:{p.get('name')},draft:{did},to:{p['email']}}}")
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
    sent = 0
    for p in state.get("people", []):
        if p.get("sent"):
            continue
        chk = subprocess.run(["bash", str(approve), "check", p["draftId"]], capture_output=True, text=True)
        if chk.returncode != 0:
            say(f"held{{person:{p['name']},why:'no valid approval for draft {p['draftId']}'}}")
            continue
        res = subprocess.run(["bash", str(mail), "send", p["draftId"]], capture_output=True, text=True)
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
