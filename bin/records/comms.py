#!/usr/bin/env python3
"""comms.py — every communication, in, out and owed, and the to-do they move (plan 261).

One door over the house's messages. It READS the mail record where it already lives
(`hodd/memory/mail/messages.jsonl`, never copied), keeps one append-only file per other
channel under `hodd/memory/comms/<channel>.jsonl`, gathers everything still waiting to be
sent from the shelves it is scattered across, and PROPOSES changes to the Allfather's
to-do with the message that justifies each one. Nothing is written to the to-do without
his yes, and his own hand-written lines are never edited: an approved change is a dated
line in the house-kept part of the file.

    comms.py record --channel telegram --direction in|out --who W [--thread T] [--project P]
                    [--ref R] [--text "..."] [--at ISO]
    comms.py list   [--hours 24] [--channel C] [--direction in|out] [--max 40]
    comms.py summary [--hours 24]                 # per channel: in · out · owed
    comms.py owed                                  # every thing waiting to be sent
    comms.py todo-matches [--todo PATH] [--days 3] [--offline] [--json]
    comms.py todo-apply ID... [--todo PATH]        # writes only what he approved
    comms.py brief [--hours 24]                    # the morning brief's Markdown section

Output for agents is TOON; `brief` is Markdown for a person. Mail is never sent, replied to,
labelled or deleted from here — the only live mail road is a read-only search.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent

ROW_KEYS = ("channel", "direction", "who", "thread", "project", "at", "ref")
CHANNELS_WRITTEN = ("telegram",)          # mail keeps its own record; these are appended here

# ── the home ──────────────────────────────────────────────────────────────────


def home() -> Path:
    env = os.environ.get("YMIR_HOME")
    if env:
        return Path(os.path.expanduser(env))
    lib = ROOT / "bin" / "vault" / "hoard-lib.sh"
    try:
        out = subprocess.run(
            ["bash", "-c", f'. "{lib}" >/dev/null 2>&1; r=""; ymir_home_root r 2>/dev/null; printf "%s" "$r"'],
            capture_output=True, text=True, timeout=10).stdout.strip()
    except Exception:
        out = ""
    if out and os.path.isdir(out):
        return Path(out)
    raise SystemExit('comms[1]{error}:\n  "the home is unresolved — set YMIR_HOME"')


def comms_dir() -> Path:
    return home() / "hodd" / "memory" / "comms"


def mail_record() -> Path:
    return home() / "hodd" / "memory" / "mail" / "messages.jsonl"


def todo_path() -> Path:
    return home() / "hodd" / "life" / "personal" / "me" / "todo.md"


def now() -> dt.datetime:
    fixed = os.environ.get("COMMS_NOW")          # tests pin the clock
    if fixed:
        return parse_at(fixed) or dt.datetime.now(dt.timezone.utc)
    return dt.datetime.now(dt.timezone.utc)


def parse_at(text: str | None) -> dt.datetime | None:
    if not text:
        return None
    try:
        t = dt.datetime.fromisoformat(str(text).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def toon_cell(v) -> str:
    s = "" if v is None else str(v)
    s = s.replace("\n", " ").replace('"', "'")
    return f'"{s}"'


def toon(name: str, fields: list[str], rows: list[dict]) -> str:
    out = [f"{name}[{len(rows)}]{{{','.join(fields)}}}:"]
    for r in rows:
        out.append("  " + ",".join(toon_cell(r.get(f)) for f in fields))
    return "\n".join(out)


# ── C1 · the record ───────────────────────────────────────────────────────────


def append(channel: str, direction: str, who: str, thread: str = "", project: str = "",
           ref: str = "", text: str = "", at: str | None = None) -> bool:
    """Append one row to a channel's record. Never raises: the record must not break the
    thing it records (a bot that dies because its ledger is read-only is deaf)."""
    try:
        if channel == "mail":
            return False                      # mail's record is messages.jsonl, written by its ingest
        if direction not in ("in", "out"):
            return False
        row = {
            "channel": channel, "direction": direction, "who": who or "", "thread": str(thread or ""),
            "project": project or "", "at": at or now().strftime("%Y-%m-%dT%H:%M:%S+00:00"),
            "ref": str(ref or ""), "text": (text or "")[:500],
        }
        d = comms_dir()
        d.mkdir(parents=True, exist_ok=True)
        with open(d / f"{channel}.jsonl", "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
        return True
    except Exception:
        return False


def _addr(x) -> str:
    return (x or {}).get("email", "") if isinstance(x, dict) else str(x or "")


def mail_rows() -> list[dict]:
    """messages.jsonl, read where it lies and shaped into the one row shape."""
    rows = []
    p = mail_record()
    if not p.is_file():
        return rows
    newest: dict[str, dict] = {}      # the record appends; a re-judged message's newest row wins
    for line in p.read_text(encoding="utf-8", errors="ignore").splitlines():
        if not line.strip():
            continue
        try:
            m = json.loads(line)
        except ValueError:
            continue
        newest[str(m.get("id") or len(newest))] = m
    for m in newest.values():
        out = m.get("direction") == "out"
        who = ",".join(_addr(t) for t in (m.get("to") or [])) if out else _addr(m.get("from"))
        rows.append({
            "channel": "mail", "direction": m.get("direction", ""), "who": who,
            "thread": m.get("thread_key", ""), "project": m.get("project_id") or "",
            "at": m.get("received_at", ""), "ref": m.get("id", ""),
            "text": m.get("subject", ""), "_mail": m,
        })
    return rows


def channel_rows(channel: str) -> list[dict]:
    p = comms_dir() / f"{channel}.jsonl"
    rows = []
    if p.is_file():
        for line in p.read_text(encoding="utf-8", errors="ignore").splitlines():
            try:
                rows.append(json.loads(line))
            except ValueError:
                continue
    return rows


def all_rows() -> list[dict]:
    rows = mail_rows()
    d = comms_dir()
    if d.is_dir():
        for f in sorted(d.glob("*.jsonl")):
            rows += channel_rows(f.stem)
    rows.sort(key=lambda r: parse_at(r.get("at")) or dt.datetime.min.replace(tzinfo=dt.timezone.utc))
    return rows


def recent(rows: list[dict], hours: float) -> list[dict]:
    cut = now() - dt.timedelta(hours=hours)
    return [r for r in rows if (parse_at(r.get("at")) or cut) > cut]


# ── C2 · the owed list ────────────────────────────────────────────────────────

OWED_SHELVES = (
    ("letters", "hodd/state/letters"),
    ("mail-drafts", "hodd/state/mail-drafts"),
    ("mail/drafts", "hodd/state/mail/drafts"),
    ("collab/letters", "hodd/state/collab/letters"),
    ("approvals", "hodd/state/notify/approvals"),
)
GREETING = re.compile(r"^\s*(?:hi|hello|dear|hej)?\s*([A-ZÅÄÖ][\w'-]+(?:\s[A-ZÅÄÖ][\w'-]+)?)\s*,\s*$", re.I)
LETTER_TITLE = re.compile(r"^#\s*letter to\s+([A-ZÅÄÖ][\w'-]+)", re.I)


def person_index(mails: list[dict]) -> dict[str, set[str]]:
    """first name / local part → addresses, learned from the mail record itself."""
    idx: dict[str, set[str]] = {}
    for r in mails:
        m = r["_mail"]
        for p in [m.get("from")] + list(m.get("to") or []) + list(m.get("cc") or []):
            if not isinstance(p, dict) or not p.get("email"):
                continue
            email = p["email"].lower()
            if re.search(r"no-?reply|do-?not-?reply|notifications?@", email):
                continue
            keys = {email.split("@")[0].split(".")[0]}
            name = (p.get("name") or "").strip()
            if name:
                keys.add(name.split()[0].lower())
            for k in keys:
                if len(k) >= 3:
                    idx.setdefault(k, set()).add(email)
    return idx


def _who_from_letter(path: Path) -> str:
    try:
        head = path.read_text(encoding="utf-8", errors="ignore").splitlines()[:12]
    except Exception:
        return ""
    for line in head:
        m = LETTER_TITLE.match(line)
        if m:
            return m.group(1)
    for line in head:
        line = line.strip().strip("*")
        if not line or line.startswith("#"):
            continue
        m = GREETING.match(line)
        if m:
            return m.group(1)
    return ""


def owed(live: bool = True) -> list[dict]:
    """Every thing waiting to be sent, wherever it sits. A letter whose recipient has since
    been sent a mail on the same subject is reported as `sent?` with that mail — the shelf is
    a source, not a store, and the house never deletes from it."""
    h = home()
    mails = mail_rows()
    idx = person_index(mails)
    out = []
    for shelf, rel in OWED_SHELVES:
        d = h / rel
        if not d.is_dir():
            continue
        for f in sorted(d.iterdir()):
            if f.is_dir() or f.name.startswith("."):
                continue
            if shelf == "approvals":
                try:
                    a = json.loads(f.read_text())
                except Exception:
                    continue
                if a.get("decision") is not None:
                    continue
                out.append({"shelf": shelf, "path": f"{rel}/{f.name}", "for": "the Allfather (his OK)",
                            "what": (a.get("question") or "")[:90], "since": (a.get("asked_at") or "")[:10],
                            "state": "waits on his OK", "evidence": ""})
                continue
            if shelf == "letters" and f.suffix == ".html" and f.with_suffix(".txt").exists():
                continue                      # one letter in two dresses is one thing owed
            who = _who_from_letter(f)
            since = dt.datetime.fromtimestamp(f.stat().st_mtime, dt.timezone.utc).strftime("%Y-%m-%d")
            state, evidence = "owed", ""
            sent = _sent_since(f, who, idx, mails)
            if sent:
                state, evidence = "sent?", sent
            out.append({"shelf": shelf, "path": f"{rel}/{f.name}", "for": who or "unnamed",
                        "what": f.stem, "since": since, "state": state, "evidence": evidence})
    if live:
        for d in gmail_drafts():
            out.append({"shelf": "gmail-drafts", "path": f"gmail:{d.get('id','')}",
                        "for": d.get("to", "") or "unnamed", "what": (d.get("subject") or "")[:90],
                        "since": (d.get("date") or "")[:16], "state": "owed", "evidence": ""})
    return out


def _sent_since(path: Path, who: str, idx: dict, mails: list[dict]) -> str:
    """An out mail to the letter's person, after the letter was written, sharing a word of its name."""
    if not who:
        return ""
    addrs = idx.get(who.split()[0].lower(), set())
    if not addrs:
        return ""
    words = {w for w in re.split(r"[^a-zåäö0-9]+", path.stem.lower()) if len(w) >= 5}
    words -= {"letter", "draft", "person", who.split()[0].lower()}
    written = dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc) - dt.timedelta(days=2)
    for r in mails:
        if r["direction"] != "out":
            continue
        to = {_addr(t).lower() for t in r["_mail"].get("to") or []}
        at = parse_at(r["at"])
        if not (to & addrs) or not at or at < written:
            continue
        subj = r["text"].lower()
        if words and any(w in subj for w in words):
            return f"mail {r['ref']} {r['at'][:10]} '{r['text'][:60]}'"
    return ""


def gmail_drafts(strict: bool = False) -> list[dict] | None:
    """Gmail's own drafts, read-only through the scanner. Absent credentials is an empty shelf —
    or, with strict, None: a caller that closes items when a draft is gone must know the
    difference between "no drafts" and "could not look"."""
    if os.environ.get("COMMS_OFFLINE") == "1":
        return None if strict else []
    fixture = os.environ.get("COMMS_GMAIL_FIXTURE")       # tests answer from a file, never the mailbox
    if fixture:
        try:
            with open(fixture, encoding="utf-8") as fh:
                rows = json.load(fh).get("in:drafts")
        except Exception:
            rows = None
        if rows is None:
            return None if strict else []
        return [{"id": m.get("id"), "subject": m.get("subject"), "date": m.get("date"), "to": ""} for m in rows]
    try:
        out = subprocess.run(["bash", str(ROOT / "bin" / "mail" / "mail-scan.sh"), "--query", "in:drafts",
                              "--max", "40"], capture_output=True, text=True, timeout=90,
                             env={**os.environ, "YMIR_TREE": str(ROOT)}).stdout
        data = json.loads(out or "{}")
    except Exception:
        return None if strict else []
    if strict and "messages" not in data:
        return None
    return [{"id": m.get("id"), "subject": m.get("subject"), "date": m.get("date"), "to": ""}
            for m in data.get("messages") or []]


def gmail_search(query: str, max_n: int = 30) -> list[dict]:
    if os.environ.get("COMMS_OFFLINE") == "1":
        return []
    fixture = os.environ.get("COMMS_GMAIL_FIXTURE")       # tests answer the search from a file
    if fixture:
        try:
            with open(fixture, encoding="utf-8") as fh:
                data = json.load(fh)
            return [m for m in data.get(query, [])]
        except Exception:
            return []
    try:
        out = subprocess.run(["bash", str(ROOT / "bin" / "mail" / "mail-scan.sh"), "--query", query,
                              "--max", str(max_n)], capture_output=True, text=True, timeout=90,
                             env={**os.environ, "YMIR_TREE": str(ROOT)}).stdout
        return json.loads(out or "{}").get("messages") or []
    except Exception:
        return []


# ── C3 · the to-do ────────────────────────────────────────────────────────────

HOUSE_MARK = "# The house-kept half — what his messages moved"
ITEM = re.compile(r"^- \[( |x|X)\] (.*)$")
BOLD = re.compile(r"\*\*(.+?)\*\*")
QUOTED = re.compile(r"[\"“]([^\"”]{6,})[\"”]")
EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+")

OUT_VERBS = {"send", "answer", "reply", "ask", "mail", "write", "tell", "forward"}
PLATFORM_VERBS = {"confirm", "accept", "sign", "complete", "approve"}
GENERIC = {
    "send", "answer", "reply", "email", "emails", "mail", "mails", "draft", "drafts", "letter", "letters",
    "message", "the", "two", "three", "with", "from", "this", "that", "your", "their", "about", "confirm",
    "accept", "sign", "complete", "invitation", "invite", "request", "today", "week", "they", "them",
    "what", "when", "which", "ask", "write", "tell", "forward", "approve", "into", "onto", "after",
}
DONE_WORDS = re.compile(r"\b(completed|signed|accepted|welcome|välkommen|klar|confirmed)\b", re.I)


def parse_todo(text: str) -> list[dict]:
    """Every checkbox in HIS half (the house-kept and derived halves are not his items)."""
    items, section, cur = [], "", None
    his = True
    for n, line in enumerate(text.splitlines(), 1):
        if line.startswith("# The derived half") or line.startswith(HOUSE_MARK):
            his = False
        if line.startswith("# His half"):
            his = True
        if line.startswith("## "):
            section = line[3:].strip()
        m = ITEM.match(line)
        if m:
            cur = {"line": n, "checked": m.group(1).lower() == "x", "text": m.group(2),
                   "section": section, "his": his}
            items.append(cur)
            continue
        if cur and line.startswith("      ") and line.strip():
            cur["text"] += " " + line.strip()
        elif not line.strip() or not line.startswith(" "):
            cur = None
    for it in items:
        b = BOLD.search(it["text"])
        it["title"] = (b.group(1) if b else it["text"][:80]).strip()
        it["id"] = hashlib.sha256(it["title"].encode()).hexdigest()[:8]
    return items


def house_notes(text: str) -> set[str]:
    """Item ids the house has already recorded as moved (so nothing is proposed twice)."""
    return set(re.findall(r"\(item ([0-9a-f]{8})\)", text))


def item_birth(path: Path, line: int) -> dt.datetime | None:
    """When the item was written — the blame of its first line, if the file is in git."""
    try:
        out = subprocess.run(["git", "-C", str(path.parent), "blame", "--porcelain", "-L", f"{line},{line}",
                              "--", path.name], capture_output=True, text=True, timeout=20).stdout
        m = re.search(r"^author-time (\d+)", out, re.M)
        return dt.datetime.fromtimestamp(int(m.group(1)), dt.timezone.utc) if m else None
    except Exception:
        return None


def _words(s: str) -> list[str]:
    return [w for w in re.split(r"[^a-zåäö0-9#]+", s.lower()) if w]


def _persons(item: dict, idx: dict) -> dict[str, set[str]]:
    found: dict[str, set[str]] = {}
    for e in EMAIL.findall(item["text"]):
        found[e.split("@")[0]] = {e.lower()}
    for tok in re.findall(r"\b([A-ZÅÄÖ][a-zåäö]+)(?:'s)?\b", item["title"]):
        k = tok.lower()
        if k in idx and k not in GENERIC:
            found.setdefault(k, set()).update(idx[k])
    # a person named in the body as the counterparty ("to Ada", "to Bo")
    for tok in [t for pair in re.findall(r"\bto ([A-Z][a-zåäö]+)(?: and ([A-Z][a-zåäö]+))?\b", item["text"])
                for t in pair if t]:
        k = tok.lower()
        if k in idx:
            found.setdefault(k, set()).update(idx[k])
    return found


def _keys(item: dict, persons: dict) -> list[str]:
    ks = []
    for w in _words(item["title"]):
        if (len(w) < 4 and not w.startswith("#")) or w in GENERIC or w in persons:
            continue
        if w not in ks:
            ks.append(w)
    return ks


def match_todo(todo_text: str, todo_file: Path | None = None, days: float = 3,
               live: bool = True) -> list[dict]:
    """Proposals, each with its evidence. Kinds: tick (an open item of his a message has answered) ·
    open (a conversation that needs his answer and has no item) · send (a draft waiting in Gmail) ·
    wait (a question he sent, unanswered) · close (a house-kept line he has since answered) ·
    open from the daily log (an entry tagged open, plan 274)."""
    mails = mail_rows()
    idx = person_index(mails)
    done = house_notes(todo_text)
    proposals = []
    for it in parse_todo(todo_text):
        if it["checked"] or not it["his"] or it["id"] in done:
            continue
        verb = (_words(it["title"]) or [""])[0]
        persons = _persons(it, idx)
        keys = _keys(it, persons)
        born = item_birth(todo_file, it["line"]) if todo_file else None
        floor = (born - dt.timedelta(days=3)) if born else None
        ev = None
        if verb in OUT_VERBS:
            ev = _answered_by_out_mail(it, persons, keys, mails, floor)
        elif verb in PLATFORM_VERBS:
            ev = _platform_done(it, persons, keys, mails, live)
        if ev:
            proposals.append({"id": it["id"], "kind": "tick", "section": it["section"], "item": it["title"],
                              "confidence": ev["confidence"], "evidence": ev["why"], "refs": ev["refs"]})
    drafts = gmail_drafts(strict=True) if live else None
    drafted = {_bare(d.get("subject") or "") for d in drafts or []}
    proposals += [p for p in _opens(mails, todo_text, days) if _bare(p["subject"]) not in drafted]
    proposals += _sends(drafts, todo_text)
    proposals += _waits(mails, todo_text, days)
    proposals += _closes(mails, todo_text, drafts)
    proposals += _log_opens(todo_text)
    return proposals


def _answered_by_out_mail(it, persons, keys, mails, floor):
    """A Send/Answer item is answered when a mail went OUT to every person it names, with the
    item's own words in the subject. A quoted phrase in the item must be in the subject."""
    if not persons or not keys:
        return None
    # a short item must be matched by ALL its words; a long one by any two of them
    need = len(keys) if len(keys) <= 2 else 2
    quoted = [q.lower() for q in QUOTED.findall(it["text"])]
    hits: dict[str, dict] = {}
    for r in sorted(mails, key=lambda r: r["at"]):     # the FIRST mail that answers it, not any later one
        if r["direction"] != "out" or _is_draft(r["_mail"]):
            continue
        at = parse_at(r["at"])
        if floor and at and at < floor:
            continue
        subj = r["text"].lower()
        if quoted and not any(q in subj for q in quoted):
            continue
        if sum(1 for k in keys if k in subj) < need:
            continue
        to = {_addr(t).lower() for t in r["_mail"].get("to") or []} | \
             {_addr(t).lower() for t in r["_mail"].get("cc") or []}
        for name, addrs in persons.items():
            if to & addrs and name not in hits:
                hits[name] = dict(r, _to=sorted(to & addrs)[0])
    if not hits or len(hits) < len(persons):
        return None
    refs = [hits[n]["ref"] for n in persons]
    why = "; ".join(f"sent to {hits[n]['_to']} {hits[n]['at'][:16]} '{hits[n]['text'][:60]}'"
                    for n in persons)
    return {"confidence": "high", "why": why, "refs": refs}


def _platform_done(it, persons, keys, mails, live):
    """A Confirm/Accept item points at a platform's request (a signature, an invitation).
    Mail cannot see the platform, so the evidence is what the mail around it shows:
      high   — the platform wrote that THIS document or account is completed / accepted
      medium — the platform's reminders to him about it stopped (it reminds until he acts), or
               the person who asked has since written to him from inside that very account."""
    asker: set[str] = set()
    for name, addrs in persons.items():
        asker.add(name)
        asker |= addrs
    reqs = []
    for r in mails:
        m = r["_mail"]
        if r["direction"] != "in":
            continue
        sender = _addr(m.get("from")).lower()
        dom = sender.split("@")[-1]
        if not any(k in dom for k in keys):
            continue                          # a platform's request comes FROM the platform
        hay = (r["text"] + " " + (m.get("body_text") or "")[:1500]).lower()
        if asker and not any(a in hay for a in asker):
            continue                          # ...and, when the item names who asked, it is theirs
        reqs.append(r)
    if not reqs:
        return None
    reqs.sort(key=lambda r: r["at"])
    req = reqs[-1]                            # the newest request is the one the item means
    dom = _addr(req["_mail"].get("from")).lower().split("@")[-1]
    platform = next((k for k in keys if k in dom), dom.split(".")[0])
    stop = {"please", "complete", "reminder", "document", "invited", platform}
    doc = {w for w in _words(req["text"]) if len(w) >= 6 and w not in stop}
    refs = [req["ref"]]

    def same_doc(subject: str) -> bool:
        return bool(doc & set(_words(subject or "")))

    for r in reqs:
        if DONE_WORDS.search(r["text"]) and same_doc(r["text"]):
            return {"confidence": "high", "why": f"{platform} wrote '{r['text'][:60]}' {r['at'][:10]}",
                    "refs": [r["ref"]]}
    if live:   # the record keeps only what the ingest swept, so the platform's series is read live
        series = [m for m in gmail_search(f"in:anywhere from:{dom} newer_than:60d")
                  if same_doc(m.get("subject"))]
        done_live = [m for m in series if DONE_WORDS.search(m.get("subject") or "")]
        if done_live:
            m = done_live[0]
            return {"confidence": "high", "why": f"{platform} wrote '{(m.get('subject') or '')[:60]}'",
                    "refs": [m.get("id", "")]}
        rem = [m for m in series if (m.get("subject") or "").lower().startswith("reminder")]
        if len(rem) >= 2:
            dated = [(_rfc_date(m.get("date")), m) for m in rem]
            dated = [(t, m) for t, m in dated if t]
            if dated:
                last_at = max(t for t, _ in dated)
                if now() - last_at > dt.timedelta(days=7):
                    return {"confidence": "medium",
                            "why": (f"{platform} asked {req['at'][:10]} and reminded him {len(rem)} times, "
                                    f"the last {last_at:%Y-%m-%d}; it reminds until he acts and has been "
                                    f"silent {(now() - last_at).days} days (no 'completed' yet — the other "
                                    f"side may still have to sign)"),
                            "refs": refs + [m.get("id", "") for _, m in dated]}
    entity = _entity((req["_mail"].get("body_text") or "") + " " + req["text"])
    fat = parse_at(req["at"])
    for r in mails:
        at = parse_at(r["at"])
        if r["direction"] != "in" or not at or not fat or at <= fat or r["ref"] == req["ref"]:
            continue
        text = (r["text"] + " " + (r["_mail"].get("body_text") or "")[:3000]).lower()
        if platform not in text or not entity or entity.lower() not in text:
            continue
        if not asker or not any(a in text for a in asker):
            continue
        return {"confidence": "medium",
                "why": (f"{platform} invited him {req['at'][:10]} to {entity}; on {r['at'][:10]} the one who "
                        f"asked wrote to him from inside that account ('{r['text'][:60]}') — mail cannot "
                        f"see the acceptance itself"),
                "refs": refs + [r["ref"]]}
    return None


def _entity(text: str) -> str:
    m = re.search(r"\b([A-ZÅÄÖ][\w&-]+(?:\s[A-ZÅÄÖ][\w&-]+){0,3}\s(?:AB|Ltd|Inc|GmbH|AS|Oy))\b", text)
    return m.group(1) if m else ""


def _rfc_date(s):
    from email.utils import parsedate_to_datetime
    try:
        t = parsedate_to_datetime(s)
        return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)
    except Exception:
        return None


NOREPLY = re.compile(r"^(no-?reply|do-?not-?reply|mail-?no-?reply|notifications?|mailer-daemon|receipts?)", re.I)


def _contact_after(mails, direction, addr, at) -> bool:
    """Any mail the other way with that person after `at` — a reply often starts a new thread."""
    addr = addr.lower()
    for r in mails:
        t = parse_at(r["at"])
        if r["direction"] != direction or not t or t <= at:
            continue
        m = r["_mail"]
        people = {_addr(m.get("from")).lower()} | {_addr(x).lower() for x in m.get("to") or []} | \
                 {_addr(x).lower() for x in m.get("cc") or []}
        if addr in people:
            return True
    return False


ASKS = ("reply_needed", "create_card", "schedule_meeting")   # the judge's verdicts that ask him something


def asks_him(m: dict) -> bool:
    """An incoming mail that asks the operator something: a verdict that wants an answer, or one
    the judge was unsure of (a human decides). Calendar mail, notices and bulk are archived or
    recorded by the judge and never ask."""
    if m.get("direction") == "out" or m.get("handled_at"):
        return False
    conf = m.get("confidence")
    return m.get("proposed_action") in ASKS or (conf is not None and float(conf) < 0.6)


def _is_draft(m: dict) -> bool:
    return "DRAFT" in (m.get("labels") or [])


def _shared_word(a: str, b: str) -> bool:
    wa = {w for w in _words(a) if len(w) >= 5 and w not in GENERIC}
    return bool(wa & {w for w in _words(b) if len(w) >= 5})


def _answered(mails, thread: str, sender: str, subject: str, at) -> dict | None:
    """The mail he sent that answers a conversation: a sent reply in the same thread, or a new
    mail to the same person whose subject shares a word with it (a reply often starts a new
    thread). A draft is not an answer."""
    for r in sorted(mails, key=lambda r: r["at"]):
        m = r["_mail"]
        t = parse_at(r["at"])
        if r["direction"] != "out" or _is_draft(m) or not t or t <= at:
            continue
        if thread and r["thread"] == thread:
            return r
        to = {_addr(x).lower() for x in (m.get("to") or []) + (m.get("cc") or [])}
        if sender in to and _shared_word(subject, r["text"]):
            return r
    return None


def owed_conversations(mails, days: float | None = None) -> list[dict]:
    """Every conversation where the last word is theirs, it asks him something, and he has not
    answered — newest first. The same rule the mail index shows as "you owe a reply"."""
    cut = (now() - dt.timedelta(days=days)) if days else None
    threads: dict[str, list[dict]] = {}
    for r in mails:
        threads.setdefault(r["thread"] or r["ref"], []).append(r)
    out = []
    for key, rs in threads.items():
        real = sorted((r for r in rs if not _is_draft(r["_mail"])), key=lambda r: r["at"])
        if not real or real[-1]["direction"] != "in":
            continue
        last = real[-1]
        m, at = last["_mail"], parse_at(last["at"])
        if not at or (cut and at < cut) or not asks_him(m):
            continue
        sender = _addr(m.get("from")).lower()
        if NOREPLY.match(sender.split("@")[0]) or _answered(mails, key, sender, last["text"], at):
            continue
        drafted = any(_is_draft(r["_mail"]) and r["at"] >= last["at"] for r in rs)
        out.append({"thread": key, "last": last, "sender": sender, "at": at, "drafted": drafted,
                    "first": real[0]["text"]})
    return sorted(out, key=lambda c: c["at"], reverse=True)


def _opens(mails, todo_text, days):
    """A conversation that needs his answer, unanswered, with no line yet: one line per thread."""
    out = []
    for c in owed_conversations(mails, days):
        pid = hashlib.sha256(("open" + c["thread"]).encode()).hexdigest()[:8]
        if f"(item {pid}" in todo_text:
            continue
        m, last = c["last"]["_mail"], c["last"]
        name = (m.get("from") or {}).get("name") or c["sender"]
        age = (now() - c["at"]).days
        out.append({"id": pid, "kind": "open", "section": "Today" if age <= 2 else "This week",
                    "item": f"Answer {name} — {c['first'][:70]}", "confidence": "high" if m.get("proposed_action") in ASKS else "low",
                    "evidence": (f"their last word {last['at'][:16]} ({m.get('proposed_action')}: "
                                 f"{(m.get('evidence') or '')[:90]}); nothing sent back since"
                                 + ("; a draft answer is waiting" if c["drafted"] else "")),
                    "refs": [last["ref"]], "thread": c["thread"], "subject": last["text"]})
    return out


def _bare(subject: str) -> str:
    """A subject without its Re:/Fwd: prefixes, for matching a draft to its conversation."""
    return re.sub(r"^\s*((re|fwd?|sv|vb)\s*:\s*)+", "", subject or "", flags=re.I).strip().lower()


def _sends(drafts, todo_text):
    """A draft waiting in Gmail: one line, so a written answer is not forgotten in the folder."""
    out = []
    for d in drafts or []:
        did = str(d.get("id") or "")
        if not did:
            continue
        pid = hashlib.sha256(("send" + did).encode()).hexdigest()[:8]
        if f"(item {pid}" in todo_text:
            continue
        out.append({"id": pid, "kind": "send", "section": "Today",
                    "item": f"Send or drop the draft «{(d.get('subject') or '(no subject)')[:70]}»",
                    "confidence": "high", "evidence": f"in Gmail's drafts since {(d.get('date') or '')[:16]}",
                    "refs": [did], "draft": did})
    return out


HOUSE_LINE = re.compile(r"^- \[ \] (\d{4}-\d{2}-\d{2}) · (.*)\(item ([0-9a-f]{8})"
                        r"(?: · (thread|draft|log) ([^)\s]+))?\)\s*$")


def _closes(mails, todo_text, drafts):
    """An open line the house wrote that a sent mail has since answered, or whose draft has left
    the drafts folder. Proposed like everything else; nothing closes without his yes."""
    if HOUSE_MARK not in todo_text:
        return []
    out = []
    by_ref = {r["ref"]: r for r in mails}
    for line in todo_text[todo_text.index(HOUSE_MARK):].splitlines():
        m = HOUSE_LINE.match(line)
        if not m or not m.group(4):
            continue
        day, text, pid, kind, ref = m.groups()
        cid = hashlib.sha256(("close" + pid).encode()).hexdigest()[:8]
        title = text.split(" — ")[0].strip()
        if kind == "thread":
            ins = sorted((r for r in mails if r["thread"] == ref and r["direction"] == "in"), key=lambda r: r["at"])
            if not ins:
                continue
            last = ins[-1]
            sender = _addr(last["_mail"].get("from")).lower()
            ans = _answered(mails, ref, sender, last["text"], parse_at(last["at"]))
            if ans:
                out.append({"id": cid, "kind": "close", "section": "Today", "item": title, "confidence": "high",
                            "evidence": f"answered {ans['at'][:16]} to {ans['who'][:40]}: '{ans['text'][:60]}'",
                            "refs": [ans["ref"]], "closes": pid})
        elif kind == "draft" and drafts is not None and ref not in {str(d.get("id")) for d in drafts}:
            out.append({"id": cid, "kind": "close", "section": "Today", "item": title, "confidence": "medium",
                        "evidence": "the draft is no longer in Gmail's drafts — sent or discarded",
                        "refs": [ref], "closes": pid})
    return out


# A product's own mail (a password reset, an address to confirm) asks a user to click, not to answer;
# and a test mailbox (a local part with "test") or a reserved test domain has nobody to answer at all.
TRANSACTIONAL = re.compile(r"\b(reset your|confirm your|verify your|your password|password reset|"
                           r"återställ|bekräfta din)\b", re.I)
TEST_DOMAIN = re.compile(r"^[^@]*\btest\b[^@]*@|@(?:[\w-]+\.)*(?:test|invalid|localhost)$", re.I)


def _waits(mails, todo_text, days):
    """A question he sent that nobody has answered yet: Waiting on others. A question is one the
    subject asks, or one his own closing lines ask — a letter that merely contains a '?' is not."""
    cut = now() - dt.timedelta(days=days)
    out, seen = [], set()
    for r in sorted(mails, key=lambda r: r["at"], reverse=True):
        m = r["_mail"]
        at = parse_at(r["at"])
        if r["direction"] != "out" or not at or at < cut:
            continue
        own = (m.get("body_text") or "").split("\nOn ")[0].strip()
        tail = "\n".join([l for l in own.splitlines() if l.strip()][-6:])
        asks = "?" in r["text"] or "question" in r["text"].lower() or "?" in tail
        if not asks:
            continue
        if TRANSACTIONAL.search(r["text"]) or _is_draft(m):
            continue
        for to in [_addr(x).lower() for x in m.get("to") or []]:
            if not to or TEST_DOMAIN.search(to) or _contact_after(mails, "in", to, at) or (to, r["text"]) in seen:
                continue
            seen.add((to, r["text"]))
            pid = hashlib.sha256(("wait" + r["ref"] + to).encode()).hexdigest()[:8]
            if f"(item {pid})" in todo_text:
                continue
            out.append({"id": pid, "kind": "wait", "section": "Waiting on others",
                        "item": f"{to} — '{r['text'][:70]}'", "confidence": "medium",
                        "evidence": f"he asked {r['at'][:16]}; nothing has come back from them since",
                        "refs": [r["ref"]]})
    return out


# ── plan 274 · the daily log and the list, joined ───────────────────────────


def daily_dir() -> Path:
    """The daily log's shelf — the one `bin/records/daily-log.sh` writes (DAILY_LOG_DIR overrides)."""
    env = os.environ.get("DAILY_LOG_DIR")
    return Path(env) if env else home() / "hodd" / "memory" / "daily"


LOG_HEAD = re.compile(r"^## (\d{2}:\d{2}) — (.+?)\s*$")
OPEN_TAGS = {"open", "todo"}
LOG_DAYS = 3          # how far back an open log entry is still offered to the list


def log_entries(day: str) -> list[dict]:
    """The entries of one day's log: a `## HH:MM — actor` head, its `- ` lines, and `- tags:`."""
    f = daily_dir() / f"{day}.md"
    if not f.is_file():
        return []
    out, cur = [], None
    for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
        m = LOG_HEAD.match(line)
        if m:
            cur = {"day": day, "at": m.group(1), "actor": m.group(2), "lines": [], "tags": set()}
            out.append(cur)
        elif cur is not None and line.startswith("- tags:"):
            cur["tags"] |= {t.strip().lower() for t in line[7:].split(",") if t.strip()}
        elif cur is not None and line.startswith("- "):
            cur["lines"].append(line[2:].strip())
    for e in out:
        e["text"] = " ".join(e["lines"]).strip()
    return [e for e in out if e["text"]]


def _log_days(n: int) -> list[str]:
    return [(now() - dt.timedelta(days=i)).strftime("%Y-%m-%d") for i in range(n)]


def _log_opens(todo_text: str) -> list[dict]:
    """A log entry tagged open (or todo) that is not on the list yet: offered, never written."""
    out = []
    for day in _log_days(LOG_DAYS):
        for e in log_entries(day):
            if not (e["tags"] & OPEN_TAGS) or e["text"].lower().startswith("done:"):
                continue
            pid = hashlib.sha256(("log" + day + e["at"] + e["text"]).encode()).hexdigest()[:8]
            if f"(item {pid}" in todo_text:
                continue
            first = re.split(r"(?<=[.;])\s", e["text"], maxsplit=1)[0]
            out.append({"id": pid, "kind": "open", "section": "Today",
                        "item": first[:110].rstrip(" .;:"), "confidence": "high",
                        "evidence": f"the daily log, {day} {e['at']} ({e['actor']})",
                        "refs": [f"{day}T{e['at']}"], "log": f"{day}T{e['at']}", "subject": ""})
    return out


def todo_seen_path() -> Path:
    return comms_dir() / "todo-seen.json"


def _checkboxes(todo_text: str) -> list[dict]:
    """Every checkbox in his half and the house-kept half (the derived half is the house's
    measurement, rewritten whole, so a tick there is not an act). Keyed by the item id a line
    carries, or by its title's hash."""
    out, part = [], "his"
    lines = todo_text.splitlines()
    for n, line in enumerate(lines, 1):
        if line.startswith("# The derived half"):
            part = "derived"
        elif line.startswith(HOUSE_MARK):
            part = "house"
        elif line.startswith("# His half"):
            part = "his"
        m = ITEM.match(line)
        if not m or part == "derived":
            continue
        text = m.group(2)
        own = re.search(r"\(item ([0-9a-f]{8})", text)
        b = BOLD.search(text)
        title = (b.group(1) if b else re.sub(r"\s*\(item [^)]*\).*$", "", text)[:100]).strip()
        key = own.group(1) if own else hashlib.sha256(title.encode()).hexdigest()[:8]
        out.append({"key": key, "checked": m.group(1).lower() == "x", "title": title, "part": part})
    return out


def _log_add(text: str, tags: str, actor: str = "todo") -> None:
    """Append one entry in the daily log's own format (append-only, Rule 06)."""
    d = daily_dir()
    d.mkdir(parents=True, exist_ok=True)
    t = now()
    f = d / f"{t.strftime('%Y-%m-%d')}.md"
    if not f.exists():
        f.write_text(f"# {t.strftime('%Y-%m-%d')} — the day's work\n\n", encoding="utf-8")
    with f.open("a", encoding="utf-8") as fh:
        fh.write(f"## {t.strftime('%H:%M')} — {actor}\n- {text}\n- tags: {tags}\n\n")


def log_ticks(todo_text: str) -> list[dict]:
    """A line ticked since the house last looked — by him in his editor, or by todo-apply — is
    written to today's log as one `done:` entry. The first run only remembers what is ticked
    already, so the past is not replayed into today."""
    boxes = _checkboxes(todo_text)
    ticked = {b["key"]: b for b in boxes if b["checked"]}
    path = todo_seen_path()
    try:
        seen = set(json.loads(path.read_text(encoding="utf-8")).get("ticked", []))
        first = False
    except (OSError, ValueError):
        seen, first = set(), True
    new = [] if first else [b for k, b in ticked.items() if k not in seen]
    # the log itself is the second guard: another machine of the fleet may have logged this tick
    # already and synced it through the home before this one's seen-state caught up
    logged = {m for day in _log_days(LOG_DAYS) for e in log_entries(day) if e["text"].startswith("done:")
              for m in re.findall(r"\(item ([0-9a-f]{8})\)", e["text"])}
    new = [b for b in new if b["key"] not in logged]
    for b in new:
        who = "by him" if b["part"] == "his" else "in the house-kept half"
        _log_add(f"done: {b['title'][:140]} — ticked {who} (item {b['key']})", "todo")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"ticked": sorted(set(ticked) | (seen & set(ticked))),
                                "as_of": now().isoformat(timespec="seconds")}, indent=1), encoding="utf-8")
    return new


def log_join(todo_text: str) -> dict:
    """Today's log against the list: entries, those marked open, and those not on the list yet."""
    today = now().strftime("%Y-%m-%d")
    es = log_entries(today)
    opens = [e for e in es if e["tags"] & OPEN_TAGS and not e["text"].lower().startswith("done:")]
    return {"entries": len(es), "open": len(opens),
            "not_listed": sum(1 for p in _log_opens(todo_text) if p["log"].startswith(today)),
            "day": today}


HOUSE_HALF = f"""

---

{HOUSE_MARK}

Kept by the house from his mail and his other messages (plan 261), and written **only after his yes**.
His own lines above are never edited: when a message closes one of them, the closing is recorded here as a
dated line naming the message. Each line ends with the item's id, so the house never proposes it twice.

## Today

## This week

## Waiting on others
"""


def apply(ids: list[str], todo_file: Path, live: bool = True, days: float = 14) -> list[dict]:
    """Write the approved proposals as dated lines in the house-kept half. His own lines are never
    touched; a close ticks the house's own line and says which mail answered it."""
    text = todo_file.read_text(encoding="utf-8")
    props = {p["id"]: p for p in match_todo(text, todo_file, days=days, live=live)}
    picked = [props[i] for i in ids if i in props]
    if not picked:
        return []
    if HOUSE_MARK not in text:
        text = text.rstrip("\n") + "\n" + HOUSE_HALF
    day = now().strftime("%Y-%m-%d")
    for p in picked:
        if p["kind"] == "tick":
            line = (f"- [x] {day} · done: «{p['item']}» ({p['section']}) — {p['evidence']} "
                    f"· approved by him (item {p['id']})")
            text = _insert_under(text, "Today", line)
        elif p["kind"] == "close":
            text = _close_line(text, p["closes"], f"{day} · {p['evidence']}")
        elif p["kind"] in ("open", "send"):
            tag = (f" · thread {p['thread']}" if p.get("thread") else f" · draft {p['draft']}" if p.get("draft")
                   else f" · log {p['log']}" if p.get("log") else "")
            line = f"- [ ] {day} · {p['item']} — {p['evidence']} (item {p['id']}{tag})"
            text = _insert_under(text, p["section"], line)
        else:
            line = f"- [ ] {day} · {p['item']} — {p['evidence']} (item {p['id']})"
            text = _insert_under(text, "Waiting on others", line)
    todo_file.write_text(text, encoding="utf-8")
    return picked


def _close_line(text: str, pid: str, note: str) -> str:
    """Tick the house's own line for item pid, in the house-kept half only, and say why."""
    start = text.index(HOUSE_MARK)
    head, body = text[:start], text[start:].split("\n")
    for i, line in enumerate(body):
        if line.startswith("- [ ] ") and f"(item {pid}" in line:
            body[i] = "- [x] " + line[6:] + f" — closed {note}"
            break
    return head + "\n".join(body)


def _insert_under(text: str, section: str, line: str) -> str:
    """Insert at the END of a section of the house-kept half (newest last, nothing moved)."""
    start = text.index(HOUSE_MARK)
    head, body = text[:start], text[start:]
    lines = body.split("\n")
    try:
        i = lines.index(f"## {section}")
    except ValueError:
        lines += ["", f"## {section}", ""]
        i = len(lines) - 2
    j = i + 1
    while j < len(lines) and not lines[j].startswith("## "):
        j += 1
    k = j
    while k > i + 1 and not lines[k - 1].strip():
        k -= 1
    lines[k:k] = ([""] if k == i + 1 else []) + [line]
    return head + "\n".join(lines)


# ── C6 · the brief ────────────────────────────────────────────────────────────


def summary(hours: float) -> list[dict]:
    rows = recent(all_rows(), hours)
    owe = owed(live=False)
    chans = sorted({r["channel"] for r in rows} | {"mail", "telegram"})
    out = []
    for c in chans:
        rs = [r for r in rows if r["channel"] == c]
        out.append({"channel": c, "in": sum(1 for r in rs if r["direction"] == "in"),
                    "out": sum(1 for r in rs if r["direction"] == "out"),
                    "owed": sum(1 for o in owe if o["state"] == "owed") if c == "mail" else 0})
    return out


def brief(hours: float) -> str:
    rows = recent(all_rows(), hours)
    owe = owed(live=False)
    lines = [f"## Messages — in · out · owed (last {int(hours)} h)", ""]
    for s in summary(hours):
        lines.append(f"- **{s['channel'].capitalize()}**: {s['in']} in · {s['out']} out"
                     + (f" · {s['owed']} owed" if s["channel"] == "mail" else ""))
    last = max((parse_at(r["at"]) for r in all_rows() if r["channel"] == "mail"), default=None)
    if last and now() - last > dt.timedelta(hours=hours):
        lines.append(f"- The mail record's newest row is {last:%Y-%m-%d %H:%M} UTC — the ingest is behind, "
                     "so these counts are what the house has read, not what arrived.")
    for r in rows[-8:]:
        arrow = "←" if r["direction"] == "in" else "→"
        lines.append(f"  - {arrow} {r['channel']} · {r['who'][:40]} · {r['text'][:70]}")
    still = [o for o in owe if o["state"] == "owed"]
    if still:
        lines += ["", "**Still to send:**"]
        lines += [f"- {o['what']} — for {o['for']} ({o['shelf']}, since {o['since']})" for o in still[:10]]
    tp = todo_path()
    moved, props = [], []
    if tp.is_file():
        text = tp.read_text(encoding="utf-8")
        day = now().strftime("%Y-%m-%d")
        yday = (now() - dt.timedelta(days=1)).strftime("%Y-%m-%d")
        if HOUSE_MARK in text:
            moved = [l for l in text[text.index(HOUSE_MARK):].splitlines()
                     if l.startswith("- [") and (f" {day} " in l or f" {yday} " in l)]
        try:
            props = match_todo(text, tp, live=False)
        except Exception:
            props = []
    lines += ["", "**What moved on his list:**"]
    lines += [f"- {l[2:][:160]}" for l in moved] or ["- nothing written since yesterday"]
    if props:
        lines.append(f"- {len(props)} change(s) wait on his yes — say *update my to-do from my mail*:")
        lines += [f"  - {p['kind']}: {p['item'][:80]} ({p['confidence']})" for p in props[:8]]
    return "\n".join(lines) + "\n"


# ── the command line ──────────────────────────────────────────────────────────


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="comms.sh", description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("record")
    for k in ("channel", "direction", "who"):
        r.add_argument(f"--{k}", required=True)
    for k in ("thread", "project", "ref", "text", "at"):
        r.add_argument(f"--{k}", default="")
    ls = sub.add_parser("list")
    ls.add_argument("--hours", type=float, default=24)
    ls.add_argument("--channel")
    ls.add_argument("--direction")
    ls.add_argument("--max", type=int, default=40)
    sm = sub.add_parser("summary")
    sm.add_argument("--hours", type=float, default=24)
    ow = sub.add_parser("owed")
    ow.add_argument("--offline", action="store_true")
    tm = sub.add_parser("todo-matches")
    tm.add_argument("--todo")
    tm.add_argument("--days", type=float, default=14)
    tm.add_argument("--offline", action="store_true")
    tm.add_argument("--json", action="store_true")
    tm.add_argument("--no-log", action="store_true", help="do not write new ticks to the daily log")
    lt = sub.add_parser("log-ticks")
    lt.add_argument("--todo")
    lj = sub.add_parser("log-join")
    lj.add_argument("--todo")
    ta = sub.add_parser("todo-apply")
    ta.add_argument("ids", nargs="+")
    ta.add_argument("--todo")
    ta.add_argument("--offline", action="store_true")
    ta.add_argument("--days", type=float, default=14)
    br = sub.add_parser("brief")
    br.add_argument("--hours", type=float, default=24)
    a = ap.parse_args(argv)

    if a.cmd == "record":
        ok = append(a.channel, a.direction, a.who, a.thread, a.project, a.ref, a.text, a.at or None)
        print(toon("recorded", ["channel", "direction", "ok"],
                   [{"channel": a.channel, "direction": a.direction, "ok": "yes" if ok else "no"}]))
        return 0 if ok else 1
    if a.cmd == "list":
        rows = recent(all_rows(), a.hours)
        if a.channel:
            rows = [x for x in rows if x["channel"] == a.channel]
        if a.direction:
            rows = [x for x in rows if x["direction"] == a.direction]
        print(toon("comms", list(ROW_KEYS) + ["text"], rows[-a.max:]))
        return 0
    if a.cmd == "summary":
        print(toon("comms_summary", ["channel", "in", "out", "owed"], summary(a.hours)))
        return 0
    if a.cmd == "owed":
        print(toon("owed", ["shelf", "path", "for", "what", "since", "state", "evidence"],
                   owed(live=not a.offline)))
        return 0
    if a.cmd == "todo-matches":
        tp = Path(a.todo) if a.todo else todo_path()
        text = tp.read_text(encoding="utf-8")
        ticks = [] if a.no_log else log_ticks(text)
        props = match_todo(text, tp, a.days, live=not a.offline)
        if a.json:
            print(json.dumps(props, ensure_ascii=False, indent=1))
        else:
            print(toon("todo_proposals", ["id", "kind", "section", "item", "confidence", "evidence"], props))
            print("help: nothing is written without his yes — comms.sh todo-apply <id>...")
            if ticks:
                print(toon("logged_ticks", ["key", "part", "title"], ticks))
        return 0
    if a.cmd == "todo-apply":
        tp = Path(a.todo) if a.todo else todo_path()
        done = apply(a.ids, tp, live=not a.offline, days=a.days)
        print(toon("todo_applied", ["id", "kind", "item"], done))
        missing = [i for i in a.ids if i not in {d["id"] for d in done}]
        if missing:
            print(f"help: not proposed now, so not written: {' '.join(missing)}")
        return 0 if done else 1
    if a.cmd == "log-ticks":
        tp = Path(a.todo) if a.todo else todo_path()
        print(toon("logged_ticks", ["key", "part", "title"], log_ticks(tp.read_text(encoding="utf-8"))))
        return 0
    if a.cmd == "log-join":
        tp = Path(a.todo) if a.todo else todo_path()
        print(toon("log_join", ["day", "entries", "open", "not_listed"], [log_join(tp.read_text(encoding="utf-8"))]))
        return 0
    if a.cmd == "brief":
        sys.stdout.write(brief(a.hours))
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
