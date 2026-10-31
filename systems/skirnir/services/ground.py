#!/usr/bin/env python3
"""ground — the readers Skírnir was missing: who is asking, who is who, what we sent, what a meeting decided,
and when the Allfather is free. Every answer names its door and the date it read it (Rule 37).

WHY: on 2026-10-23 a partner was greeted with the owner's name, asked *"what can you do"* and got a refusal, and
asked for his summaries in Swedish and got nothing — while every answer sat in the house's own files. The
assistant was an index with a mouth. These readers are the capability; the model is only the phrasing.

WHAT IT ANSWERS, AND FROM WHERE
    who(sender)             → the person, from `hodd/identity/collaborators.yaml` (+ companies); unknown is named
    person(name)            → the meetings they attended, the letter's state, what was filed, their replies
    decisions(text)         → the record items that match the words, with their ids and status
    availability(when)      → `calendar-ask.sh free|busy` over a window, with the read's freshness
    next_meeting(person)    → the event whose attendee list names them (via the reader's cache)
    apply_for(question)     → file a knowledge request in `pending/` + `asks.json` and say so plainly

LAWS
    * read-only, and it never touches the mailbox or the vault;
    * a send is a send only when `letters.json` carries `sent.at`;
    * an absent file is "not recorded", never "not sent"; a missing person is "not in the register";
    * a calendar answer names the freshness (`as_of`) and never presents a cache as the calendar;
    * every answer carries `source` (the door) and `read` (the date) so the surface can cite it.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SN = ROOT / "bin" / "time" / "snotra"


def home() -> Path:
    h = os.environ.get("YMIR_HOME")
    if h:
        return Path(h).expanduser()
    try:
        out = subprocess.check_output(
            ["bash", "-c", f'. "{ROOT}/bin/vault/hoard-lib.sh" >/dev/null 2>&1; out=""; ymir_home_root out; '
                           'printf "%s" "$out"'], timeout=20).decode().strip()
    except Exception:  # noqa: BLE001
        out = ""
    return Path(out) if out else Path.home() / "Documents" / "ymirhome"


def load(p: Path):
    if not p.is_file():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None


def meetings() -> list[Path]:
    sys.path.insert(0, str(SN))
    try:
        import snotra_paths  # noqa: PLC0415
        return snotra_paths.meetings(None)
    except Exception:  # noqa: BLE001
        return []


def stamp(p: Path) -> str:
    try:
        return datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y-%m-%d")
    except OSError:
        return "—"


# ── who is who ─────────────────────────────────────────────────────────────────────────────────
def people() -> list[dict]:
    d = load(home() / "hodd" / "identity" / "collaborators.yaml")
    if d is None:
        try:
            import yaml  # noqa: PLC0415
            f = home() / "hodd" / "identity" / "collaborators.yaml"
            d = yaml.safe_load(f.read_text(encoding="utf-8")) if f.is_file() else {"people": []}
        except Exception:  # noqa: BLE001
            d = {"people": []}
    return d.get("people") or []


def who(sender: str) -> dict:
    """The sender as the house knows them — by name, or by the handle in the message."""
    q = (sender or "").strip().lstrip("@").lower()
    if not q:
        return {"found": False, "why": "no sender in the message"}
    for p in people():
        hay = [p.get("name", ""), p.get("id", ""), *[e.lower() for e in p.get("emails") or []],
               *[h.lower().lstrip("@") for h in p.get("telegram") or []]]
        if any(q == h or q in h or h in q for h in hay if h):
            return {"found": True, "name": p.get("name"), "org": p.get("org") or "",
                    "status": p.get("status"), "telegram": p.get("telegram") or [],
                    "emails": p.get("emails") or [], "notes": p.get("notes") or "",
                    "source": "collaborators.yaml", "read": stamp(home() / "hodd/identity/collaborators.yaml")}
    return {"found": False, "why": f"{sender} is not in the register", "source": "collaborators.yaml",
            "read": stamp(home() / "hodd/identity/collaborators.yaml")}


# ── what we sent them, and where they were ─────────────────────────────────────────────────────
def person(name: str) -> dict:
    q = " ".join((name or "").split()).lower()
    out = []
    for d in meetings():
        rec = load(d / "record.json")
        if not isinstance(rec, dict):
            continue
        if not any(q in (p.get("name") or "").lower() for p in rec.get("participants") or []):
            continue
        m = rec.get("meeting") or {}
        letters = load(d / "letters.json") or {}
        mine = next((p for p in (letters.get("people") or []) if q in (p.get("name") or "").lower()), None)
        state, at = "not recorded", ""
        if mine:
            if mine.get("sent"):
                state, at = "sent", str((mine.get("sent") or {}).get("at") or mine.get("sent"))
            else:
                state = "draft"
        replies = 0
        if (d / "replies.jsonl").is_file():
            replies = sum(1 for line in (d / "replies.jsonl").read_text(encoding="utf-8").splitlines()
                          if line.strip() and q in line.lower())
        cards = load(d / "cards.json")
        out.append({"meeting": m.get("meeting_id"), "held": str(m.get("started_at"))[:10],
                    "letter": state, "sent_at": at,
                    "filed": len(cards) if isinstance(cards, list) else "not recorded",
                    "replies": replies,
                    "read": stamp(d / "letters.json") if (d / "letters.json").is_file() else "no letters.json"})
    return {"person": name, "found": bool(out), "meetings": out, "source": "the meeting records",
            "read": datetime.now().strftime("%Y-%m-%d")}


# ── what a meeting decided ─────────────────────────────────────────────────────────────────────
def decisions(text: str, limit: int = 5) -> dict:
    words = [w for w in re.findall(r"[a-z]{4,}", (text or "").lower()) if w not in
             ("what", "when", "about", "meeting", "decided", "decision", "that", "this", "with", "have", "does")]
    hits = []
    for d in meetings():
        rec = load(d / "record.json")
        if not isinstance(rec, dict):
            continue
        mid = (rec.get("meeting") or {}).get("meeting_id")
        for kind in ("decisions", "actions", "questions"):
            for x in rec.get(kind) or []:
                blob = " ".join(str(x.get(k) or "") for k in ("statement", "deliverable", "question")).lower()
                score = sum(1 for w in words if w in blob)
                if score:
                    hits.append({"score": score, "meeting": mid, "kind": kind[:-1],
                                 "id": x.get("decision_id") or x.get("action_id") or x.get("question_id"),
                                 "text": (x.get("statement") or x.get("deliverable") or x.get("question") or "")[:160],
                                 "status": x.get("status") or "—"})
    hits.sort(key=lambda h: -h["score"])
    return {"hits": hits[:limit], "source": "the meeting records", "read": datetime.now().strftime("%Y-%m-%d")}


# ── the calendar ──────────────────────────────────────────────────────────────────────────────
def availability(when: str = "") -> dict:
    window = when.strip() or "1d"
    tool = SN / "calendar-ask.sh"
    if not tool.is_file():
        return {"known": False, "why": "no calendar door on this seat"}
    try:
        out = subprocess.run(["bash", str(tool), "probe"], capture_output=True, text=True, timeout=30)
        probe = out.stdout.strip()
        free = subprocess.run(["bash", str(tool), "free", window], capture_output=True, text=True, timeout=30)
        verdict = {0: "free", 10: "busy", 20: "unknown"}.get(free.returncode, "unknown")
        return {"known": verdict != "unknown", "verdict": verdict, "window": window,
                "probe": probe[:240], "source": "calendar-ask.sh", "read": datetime.now().strftime("%Y-%m-%d %H:%M")}
    except Exception as e:  # noqa: BLE001
        return {"known": False, "why": str(e), "source": "calendar-ask.sh"}


# ── the knowledge application (R11) ──────────────────────────────────────────────────────────
def apply_for(question: str, asker: str, chat: str) -> dict:
    base = home() / "hodd" / "identity" / "assistant"
    pend = base / "pending"
    pend.mkdir(parents=True, exist_ok=True)
    stamp_s = datetime.now().strftime("%Y%m%d-%H%M%S")
    slug = re.sub(r"[^a-z0-9]+", "-", question.lower())[:48].strip("-") or "request"
    f = pend / f"{stamp_s}-{slug}.md"
    f.write_text(f"# A request for knowledge — {datetime.now().isoformat(timespec='minutes')}\n\n"
                 f"**Asked by:** {asker}  \n**Chat:** {chat}  \n**Question, verbatim:** {question}\n\n"
                 f"status: pending — the Allfather approves, answers, or declines.\n", encoding="utf-8")
    asks = base / "asks.json"
    rows = load(asks) or {"asks": []}
    if isinstance(rows, dict):
        rows.setdefault("asks", []).append({"at": datetime.now().isoformat(timespec="seconds"), "asker": asker,
                                            "chat": chat, "question": question, "file": f.name, "state": "pending"})
        asks.write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    return {"filed": True, "file": f.name, "source": "the knowledge queue", "read": "now"}


# ── the projects: a house's work, from the registry and the ledger ────────────────────────────
def projects(house: str = "") -> dict:
    """Every project the registry holds, with its house and its plan ledger.

    Source: `hodd/identity/projects.yaml` (the master registry), `companies.yaml` (the houses), and each project's
    plans index. A project with no plans says "no ledger", never "0 plans" — an absent file is not an empty one
    (Rule 37).
    """
    base = home() / "hodd" / "identity"
    reg = None
    try:
        import yaml  # noqa: PLC0415
        reg = yaml.safe_load((base / "projects.yaml").read_text(encoding="utf-8")) if (base / "projects.yaml").is_file() else {}
    except Exception:  # noqa: BLE001
        reg = load(base / "projects.yaml") or {}
    rows = (reg.get("projects") if isinstance(reg, dict) else reg) or {}
    items = rows.values() if isinstance(rows, dict) else rows
    q = (house or "").strip().lower()
    out = []
    for p in items:
        if not isinstance(p, dict) or not p.get("id"):
            continue
        h = (p.get("workspace") or p.get("realm") or "").lower()
        if q and q not in h and q not in (p.get("id") or "").lower():
            continue
        path = p.get("path") or (p.get("git") or {}).get("repo") or ""
        # the registry id is not always the folder: `ymir-platform` lives under `projects/ymir`. Try the id,
        # the repo name and the last path segment — a project's ledger is found by any of its names.
        ledger = None
        names = {p["id"].lower(), ((p.get("git") or {}).get("repo") or "").lower(),
                 (p.get("path") or "").rstrip("/").split("/")[-1].lower()}
        names.discard("")
        for nm in sorted(names):
            hits = list((home()).glob(f"svartalfaheim/*/projects/{nm}/plans/README.md"))
            if hits:
                ledger = hits[0]
                break
        plans = "no ledger"
        latest = ""
        if ledger:
            txt = ledger.read_text(encoding="utf-8", errors="replace")
            nums = re.findall(r"^\|\s*(\d{1,3})\s*\|", txt, re.M)
            plans = len(nums) if nums else "no ledger"
            latest = f"latest {max(nums, key=int)}" if nums else ""
        out.append({"id": p["id"], "house": p.get("workspace") or p.get("realm") or "", "path": path,
                    "posture": p.get("posture") or "—", "plans": plans, "latest": latest})
    out.sort(key=lambda r: (r["house"], r["id"]))
    return {"projects": out, "count": len(out), "source": "hodd/identity/projects.yaml", "read": stamp(base / "projects.yaml")}


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "help"
    arg = sys.argv[2] if len(sys.argv) > 2 else ""
    if cmd == "who":
        print(json.dumps(who(arg), indent=2, ensure_ascii=False))
    elif cmd == "person":
        print(json.dumps(person(arg), indent=2, ensure_ascii=False))
    elif cmd == "decisions":
        print(json.dumps(decisions(arg), indent=2, ensure_ascii=False))
    elif cmd == "calendar":
        print(json.dumps(availability(arg), indent=2, ensure_ascii=False))
    elif cmd == "projects":
        print(json.dumps(projects(arg), indent=2, ensure_ascii=False))
    else:
        print(__doc__)
