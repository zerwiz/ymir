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
        "due": business_days_after(held, days),
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
            cur += (" " if cur.strip() else "") + w
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
    for line in wrap("  ", f"Confirm or correct this record by {f['due']} ({f['days']} business days). "
                           "Every decision in it is proposed until you confirm it. A correction is added as a "
                           "new entry, never by editing the old one. Silence is recorded as provisional "
                           "acceptance, not agreement."):
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


def letter_html(rec: dict, place: dict, person: dict) -> str:
    f = _facts(rec, place, person)
    e = esc
    parts: list[str] = []
    parts.append(f"<h1>{e(f['title'])}</h1>")
    parts.append(f"<p class='kicker'>{e(f['when'])} · the record, your actions, and one thing to confirm</p>")
    parts.append(f"<p class='meta'>{len(f['decisions'])} decisions · {f['actions_total']} actions · "
                 f"{len(f['questions'])} open questions"
                 + (f" · chair: {e(f['chair'])}" if f['chair'] else "") + "</p>")
    parts.append(f"<p>{e(f['name'])},</p>")
    parts.append(f"<p>Here is the record of this meeting. It is the record itself, not a summary — "
                 f"every line below traces to a numbered item in the attachments.</p>")
    parts.append("<h2>Your actions</h2>")
    if f["mine"]:
        parts.append("<ul>" + "".join(
            f"<li><strong>{e(a.get('deliverable'))}</strong> — due {e(str(a.get('due_at') or ('unresolved' if a.get('date_unresolved') else 'no date')))}."
            f"<br><span class='muted'>Done when: {e(a.get('definition_of_done') or 'to be agreed')}</span></li>"
            for a in f["mine"]) + "</ul>")
    else:
        parts.append("<p class='muted'>You own no action from this meeting.</p>")
    parts.append("<h2>The decisions</h2>")
    for grp in ("A", "B", "C"):
        rows = [d for d in f["decisions"] if (d.get("grade") or "").upper() == grp]
        if not rows:
            continue
        parts.append(f"<p class='grade'>Grade {grp}</p><ul>")
        for d in rows:
            mark = " <span class='muted'>(you decided)</span>" if (d.get("decided_by") or "").strip().lower() == f["name"].lower() else ""
            parts.append(f"<li>{e(d.get('statement'))}{mark}</li>")
        parts.append("</ul>")
    if f["questions"]:
        parts.append("<h2>Open questions</h2><ul>" + "".join(
            f"<li>{e(q.get('question'))}</li>" for q in f["questions"]) + "</ul>")
    parts.append("<h2>What I need from you</h2>")
    parts.append(f"<div class='ask'><p><strong>Confirm or correct this record by {e(f['due'])}</strong> "
                 f"({f['days']} business days). Every decision is <em>proposed</em> until you confirm it. "
                 f"A correction is added as a new entry — nothing is edited after sending. Silence is "
                 f"recorded as provisional acceptance, not as agreement.</p></div>")
    parts.append("<h2>What this record covers</h2><div class='note'>")
    parts.append(f"<p>{e(f['cov'].get('audio_source') or 'declared in the record')}.</p>")
    if f["cov"].get("missing_before"):
        parts.append(f"<p>Missing before: {e(f['cov']['missing_before'])}.</p>")
    if f["cov"].get("diarisation"):
        parts.append(f"<p>Speaker attribution: {e(f['cov']['diarisation'])}.</p>")
    parts.append("</div>")
    if f["attachments"]:
        parts.append("<h2>Attached</h2><ul>" + "".join(f"<li>{e(a)}</li>" for a in f["attachments"]) + "</ul>")
    if f["chair"]:
        parts.append(f"<p class='sign'>— {e(f['sender'] or 'the house')}</p>")
        parts.append(f"<p class='muted'>{e(f['chair'])} holds the register as chair.</p>")
    body = "\n".join(parts)
    foot = (f"Sent from the house system on the operator's approval. The record lives in the vault under "
            f"{e((rec.get('meeting') or {}).get('meeting_id') or 'this meeting')}.")
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="light">
<title>{e(subject_for(rec, place, person))}</title>
<style>{CSS}</style></head>
<body><table role="presentation" class="wrap" width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center">
<table role="presentation" class="card" width="600" cellpadding="0" cellspacing="0" border="0">
<tr><td class="pad">{body}</td></tr>
<tr><td class="foot">{foot}</td></tr>
</table></td></tr></table></body></html>
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
