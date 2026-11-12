#!/usr/bin/env python3
"""snotra-mail-watch — who has answered, and what they said (read-only; a person still promotes).

WHY: the letters ask the participants to confirm or correct the record *by a date*. Nothing in the house read
the replies — `mail-send.sh` can draft and send, the Gmail grant can read (measured 2026-10-23: `messages.list`
→ 200 over 201 messages), and no cron, door or agent ever looked at an inbox. A register that asks for
confirmation into an unread mailbox is a register that will never be confirmed.

WHAT IT DOES
    status <meeting-dir>            one row per participant: was the letter sent, is there a reply, what kind
    check  <meeting-dir> [--json]   the replies in full: sender, date, the sentence that classified it
    record <meeting-dir>            append what it saw to `replies.jsonl` and carve one rune (never promotes)

HOW A REPLY IS CLASSIFIED — by the words the letter asked for, and nothing else
    confirm    the reply agrees (confirm · confirmed · correct · agreed · approved · looks right · yes)
    correct    the reply objects or changes something (correct · correction · change · not right · objection · no,)
    question   anything else that answers the thread (it is kept, and named a question)
    silent     the thread exists but the participant has not replied

THE LAWS
    * read-only: this door never writes to the mailbox, never marks read, never replies;
    * it matches a thread by the letter's own subject, and a sender by the record's participant list — a
      stranger's mail is never attributed to a meeting;
    * **a reply does not promote a decision.** It is evidence. `snotra-promote.sh set … --by "<name>"` is still
      the only way a decision becomes approved, and a correction is an entry in `promotions.jsonl`, never an edit.
    * a confirmation for a *specific* decision is only counted when the reply names its id (`DEC-…`), because
      "ok" to a fourteen-decision register is not fourteen confirmations.
"""
from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import sys
import subprocess as _sp  # noqa: F401  (kept beside urllib for the resolver call)
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from pathlib import Path

ROOT = next(_p for _p in Path(__file__).resolve().parents if (_p / "RULES").is_dir() and (_p / ".agents").is_dir())
CONFIRM = ("confirm", "confirmed", "correct", "agreed", "agree", "approved", "approve", "looks right",
           "looks good", "fine by me", "yes")
CORRECT = ("correction", "not right", "isn't right", "is not right", "should be", "change", "objection",
           "object", "no,", "wrong", "actually")


def die(msg: str, code: int = 1):
    print(f"snotra-mail-watch: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


# ── the grant: the same vault refresh token mail-send.sh uses ───────────────────────────────────
def secret(key: str) -> str:
    # the hoard is RESOLVED, never restated (Rule 07)
    home = os.environ.get("YMIR_HOME")
    if not home:
        lib = ROOT / "bin" / "vault" / "hoard-lib.sh"
        try:
            home = subprocess.check_output(
                ["bash", "-c", f'. "{lib}" >/dev/null 2>&1; out=""; ymir_home_root out; printf "%s" "$out"'],
                timeout=20).decode().strip()
        except Exception:  # noqa: BLE001
            home = ""
    if not home:
        die("the hoard is unresolved — run bin/vault/hoard-lib.sh or set YMIR_HOME")
    sec = Path(home) / "hodd" / "secrets"
    try:
        val = subprocess.run(["age", "-d", "-i", str(sec / "age.key"), str(sec / "platform.env.age")],
                             capture_output=True, text=True, timeout=30).stdout
    except Exception:  # noqa: BLE001
        die("cannot read the vault — age is missing or the key is not there")
    for line in val.splitlines():
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip().strip("'\"")
    die(f"{key} is not in the vault")


def token() -> str:
    data = urllib.parse.urlencode({
        "client_id": secret("GOOGLE_MCP_CLIENT_ID"),
        "client_secret": secret("GOOGLE_MCP_CLIENT_SECRET"),
        "refresh_token": secret("SNOTRA_GOOGLE_REFRESH_TOKEN"),
        "grant_type": "refresh_token"}).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
    with urllib.request.urlopen(req, timeout=30) as r:
        tok = json.load(r).get("access_token", "")
    if not tok:
        die("token refresh failed — the Google grant needs re-consent")
    return tok


def gmail(path: str, tok: str) -> dict:
    req = urllib.request.Request("https://gmail.googleapis.com/gmail/v1" + path,
                                 headers={"Authorization": "Bearer " + tok})
    try:
        with urllib.request.urlopen(req, timeout=45) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        die(f"gmail answered {e.code} for {path} — {e.read().decode('utf-8', 'replace')[:160]}")


def body_text(payload: dict) -> str:
    out: list[str] = []
    if payload.get("body", {}).get("data"):
        out.append(base64.urlsafe_b64decode(payload["body"]["data"] + "==").decode("utf-8", "replace"))
    for part in payload.get("parts") or []:
        out.append(body_text(part))
    return "\n".join(x for x in out if x)


def classify(text: str) -> str:
    low = text.lower()
    if any(k in low for k in CORRECT) and not low.strip().startswith("not sure"):
        return "correct"
    if any(k in low for k in CONFIRM):
        return "confirm"
    return "question"


def letters(meeting: Path) -> list[dict]:
    p = meeting / "letters.json"
    if not p.is_file():
        die(f"no letters.json in {meeting} — render and draft the letters first", 2)
    rec = json.loads((meeting / "record.json").read_text(encoding="utf-8"))
    title = (rec.get("meeting") or {}).get("title") or ""
    people = json.loads(p.read_text(encoding="utf-8")).get("people") or []
    for x in people:
        x["subject"] = f"{title} — your actions and the record"
    return people


def replies(meeting: Path) -> list[dict]:
    tok = token()
    # our own address: a letter we sent to ourselves is not a reply to us
    me = (gmail("/users/me/profile", tok).get("emailAddress") or "").lower()
    out: list[dict] = []
    for p in letters(meeting):
        q = urllib.parse.quote(f'subject:("{p["subject"]}")')
        found = gmail(f"/users/me/messages?q={q}&maxResults=20", tok).get("messages") or []
        mine = []
        for m in found:
            msg = gmail(f"/users/me/messages/{m['id']}?format=full", tok)
            hdr = {h["name"].lower(): h["value"] for h in msg["payload"].get("headers", [])}
            frm = hdr.get("from", "")
            if p["email"].lower() not in frm.lower():
                continue                                  # a stranger's mail is never attributed
            if me and me in frm.lower():
                continue                                  # our own sent copy is not an answer
            text = body_text(msg["payload"])
            when = hdr.get("date", "")
            try:
                when = parsedate_to_datetime(when).astimezone().isoformat(timespec="minutes")
            except Exception:  # noqa: BLE001
                pass
            ids = sorted(set(re.findall(r"(?:DEC|ACT|OQ|RSK)-\d{8}-\d{2}", text)))
            mine.append({"from": frm, "at": when, "kind": classify(text), "ids": ids,
                         "line": next((ln.strip() for ln in text.splitlines()
                                       if any(k in ln.lower() for k in CONFIRM + CORRECT)), "")[:160]})
        out.append({"name": p["name"], "email": p["email"], "sent": bool(p.get("sent")),
                    "replies": mine, "state": (mine[-1]["kind"] if mine else "silent")})
    return out



# ── the register view: every decision beside the reply that answers it ─────────────────────────
def load_replies(meeting: Path) -> list[dict]:
    rows = []
    p = meeting / "replies.jsonl"
    if p.is_file():
        for line in p.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line:
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    if not rows:                      # nothing recorded yet: look now, without writing
        for r in replies(meeting):
            for x in r["replies"]:
                rows.append({"person": r["name"], "email": r["email"], **x})
    return rows


def cmd_register(meeting: Path) -> int:
    rec = json.loads((meeting / "record.json").read_text(encoding="utf-8"))
    decs = rec.get("decisions") or []
    rows = load_replies(meeting)
    by_id: dict[str, list[dict]] = {}
    whole: list[dict] = []
    for x in rows:
        for did in x.get("ids") or []:
            by_id.setdefault(did, []).append(x)
        if not x.get("ids"):
            whole.append(x)

    answered = confirmed = 0
    for d in decs:
        did = d.get("decision_id")
        state = d.get("status") or "proposed"
        hits = [x for x in by_id.get(did, []) if x.get("kind") in ("confirm", "correct")]
        if hits:
            answered += 1
            x = hits[-1]
            if x["kind"] == "confirm":
                confirmed += 1
            say(f"decision{{id:{did},grade:{d.get('grade')},status:{state},answer:{x['kind']},"
                f"person:{x['person']},at:{x['at']},line:{x.get('line','')[:90]!r}}}")
        else:
            say(f"decision{{id:{did},grade:{d.get('grade')},status:{state},answer:none}}")

    for x in whole:
        say(f"reply{{person:{x['person']},kind:{x['kind']},names_no_id:true,at:{x['at']},"
            f"line:{x.get('line','')[:90]!r}}}")
    say(f"register{{decisions:{len(decs)},answered_by_id:{answered},confirmed_by_id:{confirmed},"
        f"unnamed_replies:{len(whole)}}}")

    # a reply is EVIDENCE. Promotion is a person's act: `--apply --by "<name>"` is how he performs it.
    if "--apply" in sys.argv:
        by = None
        for i, a in enumerate(sys.argv):
            if a == "--by" and i + 1 < len(sys.argv):
                by = sys.argv[i + 1]
        if not by:
            die("refused: --apply needs a person — --by \"<name>\" (a machine may propose, only a person promotes)", 2)
        promote = ROOT / "bin" / "time" / "snotra" / "snotra-promote.sh"
        n = 0
        for d in decs:
            did = d.get("decision_id")
            if (d.get("status") or "proposed") != "proposed":
                continue
            hits = [x for x in by_id.get(did, []) if x.get("kind") == "confirm"]
            if not hits:
                continue
            x = hits[-1]
            r = subprocess.run(["bash", str(promote), "set", str(meeting), did, "accept", "--by", by,
                                "--why", f"reply {x['at']} from {x['person']}: {x.get('line','')[:120]}"],
                               capture_output=True, text=True)
            say((r.stdout or r.stderr).strip().splitlines()[-1] if (r.stdout or r.stderr) else f"promote {did}: ?")
            n += 1 if r.returncode == 0 else 0
        say(f"promoted{{count:{n},by:{by}}}")
    elif confirmed:
        say("next: a person promotes — `snotra-mail-watch.sh register <dir> --apply --by \"<name>\"`")
    return 0


def cmd_status(meeting: Path) -> int:
    rows = replies(meeting)
    for r in rows:
        say(f"reply{{person:{r['name']},sent:{str(r['sent']).lower()},state:{r['state']},"
            f"count:{len(r['replies'])}}}")
    n = sum(1 for r in rows if r["replies"])
    say(f"mail_watch{{people:{len(rows)},answered:{n},silent:{len(rows) - n}}}")
    return 0


def cmd_check(meeting: Path) -> int:
    rows = replies(meeting)
    if "--json" in sys.argv:
        say(json.dumps(rows, indent=2))
        return 0
    for r in rows:
        for x in r["replies"]:
            say(f"reply{{person:{r['name']},kind:{x['kind']},at:{x['at']},ids:{x['ids']},"
                f"line:{x['line']!r}}}")
    return 0


def cmd_record(meeting: Path) -> int:
    rows = replies(meeting)
    p = meeting / "replies.jsonl"
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    n = 0
    with open(p, "a", encoding="utf-8") as f:
        for r in rows:
            for x in r["replies"]:
                f.write(json.dumps({"at": now, "person": r["name"], "email": r["email"], **x},
                                   ensure_ascii=False) + "\n")
                n += 1
    say(f"recorded{{file:{p.name},replies:{n}}} — evidence only; a person promotes with snotra-promote.sh")
    if n and (ROOT / "bin/records/runes-append.sh").is_file():
        subprocess.run(["bash", str(ROOT / "bin/records/runes-append.sh"), "brokk", "mail-watch",
                        "--message", f"{n} reply(ies) recorded for {meeting.name}"],
                       capture_output=True, text=True)
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd, meeting = argv[1], Path(argv[2]).expanduser().resolve()
    if not (meeting / "record.json").is_file():
        die(f"no record.json in {meeting}")
    if cmd == "status":
        return cmd_status(meeting)
    if cmd == "check":
        return cmd_check(meeting)
    if cmd == "record":
        return cmd_record(meeting)
    if cmd == "register":
        return cmd_register(meeting)
    die(f"unknown command {cmd!r} — status | check | record | register", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
