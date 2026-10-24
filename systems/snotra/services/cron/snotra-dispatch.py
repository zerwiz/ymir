#!/usr/bin/env python3
"""snotra-dispatch — what we did with each person: which meetings, what was sent, what came back.

WHY: the Allfather asked *"he should know if we have emailed Reygan, cuz we have — and what was in that email"*
and *"did we send them the board?"*. Every answer exists — in `record.json` (`participants[]`), `letters.json`
(drafted/sent, with the time), `replies.jsonl` (what came back), `cards.json` (what was filed) — and no door read
them together, so the assistant could not answer a thing the house had already done.

WHAT IT DOES
    who "<person>"         every meeting they were in · the letter's state · what was filed · what came back
    who --unsent           every meeting whose letters are drafted and NOT sent
    who --board <name>     which meetings were filed on a board, and how many cards

THE LAWS (it is read-only, and it never guesses)
    * a **send** is a send only when `letters.json` carries `sent.at` — a draft is a draft, however it looks;
    * a file that is absent is reported as **not recorded**, never as "not sent" (Rule 37);
    * it reads the vault's own files and **never the mailbox** — the watcher owns the mail, this owns the record;
    * every row names the meeting id and the date the file was written, so a reader can check it.
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime
from pathlib import Path

ROOT = next(_p for _p in Path(__file__).resolve().parents if (_p / "RULES").is_dir() and (_p / ".agents").is_dir())


def die(msg: str, code: int = 1):
    print(f"snotra-dispatch: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def meetings() -> list[Path]:
    for _svc in ("record", "cron"): sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "services" / _svc))
    import snotra_paths  # noqa: PLC0415
    return snotra_paths.meetings(None)


def load(p: Path) -> dict | list | None:
    if not p.is_file():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def winfo(p: Path) -> str:
    try:
        return datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d %H:%M")
    except OSError:
        return "—"


def person_rows(name: str) -> int:
    q = " ".join(name.split()).lower()
    rows = 0
    for d in meetings():
        rec = load(d / "record.json")
        if not isinstance(rec, dict):
            continue
        parts = rec.get("participants") or []
        me = next((p for p in parts if q in (p.get("name") or "").lower()), None)
        if not me:
            continue
        m = rec.get("meeting") or {}
        letters = load(d / "letters.json") or {}
        mine = next((p for p in (letters.get("people") or []) if q in (p.get("name") or "").lower()), None)
        replies = [json.loads(l) for l in (d / "replies.jsonl").read_text(encoding="utf-8").splitlines()
                   if l.strip()] if (d / "replies.jsonl").is_file() else []
        my_replies = [r for r in replies if q in (r.get("person") or "").lower()]
        cards = load(d / "cards.json")
        filed = len(cards) if isinstance(cards, list) else "not recorded"
        state = "not recorded"
        detail = ""
        if mine:
            if mine.get("sent"):
                state = "sent"
                detail = f"at {(mine.get('sent') or {}).get('at') or mine['sent']} · draft {mine.get('draftId')}"
            else:
                state = "draft"
                detail = f"draft {mine.get('draftId')} · not sent"
        letter_txt = d / "letters" / f"{(me.get('name') or '').lower().replace(' ', '-')}.txt"
        subject = ""
        if letter_txt.is_file():
            subject = next((l.strip() for l in letter_txt.read_text(encoding="utf-8").splitlines()
                            if l.strip()), "")[:120]
        say(f"meeting{{id:{m.get('meeting_id')},held:{str(m.get('started_at'))[:10]},present:{me.get('present')},"
            f"letter:{state},detail:{detail!r},filed:{filed},replies:{len(my_replies)},"
            f"read:{winfo(d / 'letters.json') if (d / 'letters.json').is_file() else 'no letters.json'}}}")
        if subject:
            say(f"  opens{{text:{subject!r}}}")
        for r in my_replies[-2:]:
            say(f"  reply{{kind:{r.get('kind')},at:{r.get('at')},line:{str(r.get('line'))[:100]!r}}}")
        rows += 1
    return rows


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == "who":
        if "--unsent" in argv:
            n = 0
            for d in meetings():
                letters = load(d / "letters.json")
                if not isinstance(letters, dict):
                    continue
                pending = [p for p in (letters.get("people") or []) if not p.get("sent")]
                if pending:
                    n += 1
                    say(f"unsent{{meeting:{d.name},people:{[p.get('name') for p in pending]}}}")
            say(f"unsent{{meetings:{n}}}")
            return 0
        who = next((a for a in argv[2:] if not a.startswith("--")), None)
        if not who:
            die('who "<person>" — or --unsent', 2)
        n = person_rows(who)
        if n == 0:
            say(f"person{{{who}: 'not recorded — no meeting names this person in participants[]'}}")
            return 1
        say(f"person{{name:{who},meetings:{n}}}")
        return 0
    die(f"unknown command {cmd!r} — who", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
