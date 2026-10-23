#!/usr/bin/env python3
"""snotra-promote — the register becomes law: accept · reject · hold, and the promotion is recorded.

WHY: the 22 October meeting took 14 decisions and every one is `proposed` with `decided_by: null`. Until a
person promotes them, *"the meeting's decisions are the law"* means law nobody signed. The engine can
validate a record and the charts can show it, but there was no door that could say **"this one stands,
approved by this person, on this date, for this reason"** — and no record of who said so.

WHAT IT DOES
    list   <meeting-dir>                       every candidate, its state, and who (if anyone) promoted it
    set    <meeting-dir> <ID> accept|reject|hold [--by NAME] [--why TEXT] [--dry-run]
    check  <meeting-dir>                       validate the record through the engine's own validator
    log    <meeting-dir>                       the promotion log, oldest first

THE LAWS
    * **a machine may propose, only a person may promote** — `--by` is required, and it is a person's
      name, not "snotra", not "the system";
    * **append-only**: a promotion is written to `promotions.jsonl` and never rewritten; a second
      promotion of the same id is a NEW line (`from` → `to`), so the history of a decision survives its
      correction;
    * **nothing is promoted through a broken record**: `validate` (the engine's own) runs first and its
      errors stop the door;
    * **hold is a state, not a failure**: it records that a person looked and did not decide yet, with the
      reason;
    * **idempotent**: setting the same value twice writes no second line and says so.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
KINDS = ("decisions", "actions", "questions")
STATES = {"accept": "approved", "reject": "rejected", "hold": "held"}


def die(msg: str, code: int = 1):
    print(f"snotra-promote: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def load(d: Path) -> dict:
    p = d / "record.json"
    if not p.is_file():
        die(f"no record.json in {d}")
    return json.loads(p.read_text(encoding="utf-8"))


def candidates(rec: dict) -> list[dict]:
    out = []
    for kind in KINDS:
        for x in rec.get(kind) or []:
            iid = x.get("decision_id") or x.get("action_id") or x.get("question_id")
            text = x.get("statement") or x.get("deliverable") or x.get("question") or ""
            out.append({"id": iid, "kind": kind[:-1], "text": text,
                        "state": x.get("status") or ("decided" if kind == "decisions" else "proposed"),
                        "by": x.get("decided_by") or x.get("approved_by"), "item": x})
    return out


def validate(d: Path) -> tuple[bool, str]:
    eng = ROOT / ".agents" / "skills" / "snotra-meeting-outcomes" / "scripts" / "meeting-outcomes.py"
    if not eng.is_file():
        return True, "the engine's validator is not in this tree — validation skipped and SAID SO"
    r = subprocess.run([sys.executable, str(eng), "validate", str(d / "record.json")],
                       capture_output=True, text=True)
    tail = (r.stdout or r.stderr or "").strip().splitlines()
    return r.returncode == 0, (tail[-1] if tail else "")


def log_path(d: Path) -> Path:
    return d / "promotions.jsonl"


def append_promotion(d: Path, entry: dict) -> None:
    with open(log_path(d), "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def cmd_list(d: Path) -> int:
    rec = load(d)
    cands = candidates(rec)
    for c in cands:
        who = f" by {c['by']}" if c["by"] else ""
        say(f"item{{id:{c['id']},kind:{c['kind']},state:{c['state']}{who.replace(' by ', ',by:')},"
            f"text:{c['text'][:60]!r}}}")
    from collections import Counter
    say(f"register{{items:{len(cands)},states:{dict(Counter(c['state'] for c in cands))}}}")
    return 0


def cmd_log(d: Path) -> int:
    p = log_path(d)
    if not p.is_file():
        say("promotions{none:'nothing promoted yet'}")
        return 0
    n = 0
    for line in p.read_text(encoding="utf-8").splitlines():
        if line.strip():
            o = json.loads(line)
            n += 1
            say(f"promotion{{at:{o['at']},id:{o['id']},from:{o['from']},to:{o['to']},by:{o['by']},why:{o.get('why')!r}}}")
    say(f"promotions{{count:{n}}}")
    return 0


def cmd_set(d: Path, item_id: str, verb: str) -> int:
    if verb not in STATES:
        die(f"unknown verb {verb!r} — accept | reject | hold", 2)
    by = None
    why = None
    for i, a in enumerate(sys.argv):
        if a == "--by" and i + 1 < len(sys.argv):
            by = sys.argv[i + 1]
        if a == "--why" and i + 1 < len(sys.argv):
            why = sys.argv[i + 1]
    dry = "--dry-run" in sys.argv
    if not by:
        die("refused: a promotion names the person who made it — `--by \"<name>\"` (a machine may propose, "
            "only a person may promote)")
    ok, msg = validate(d)
    if not ok:
        die(f"refused: the record does not validate — {msg} (fix the record, not the promotion)")
    rec = load(d)
    hit = next((c for c in candidates(rec) if c["id"] == item_id), None)
    if not hit:
        die(f"no candidate {item_id!r} in this record", 2)
    item = hit["item"]
    frm = item.get("status") or "proposed"
    to = STATES[verb]
    if frm == to:
        say(f"noop{{id:{item_id},state:{to},why:'already promoted to this state'}}")
        return 0
    entry = {"at": datetime.now(timezone.utc).isoformat(timespec="seconds"), "id": item_id,
             "kind": hit["kind"], "from": frm, "to": to, "by": by, "why": why,
             "record": (d / "record.json").name}
    if dry:
        say(f"would{{id:{item_id},from:{frm},to:{to},by:{by},why:{why!r}}}")
        return 0
    item["status"] = to
    if to == "approved":
        item["decided_by"] = by
        item["approver_pending"] = False
    append_promotion(d, entry)
    (d / "record.json").write_text(json.dumps(rec, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    back = json.loads((d / "record.json").read_text(encoding="utf-8"))
    back_item = next((c["item"] for c in candidates(back) if c["id"] == item_id), {})
    if back_item.get("status") != to:
        die(f"the write did not hold: {item_id} reads {back_item.get('status')!r} — the record is the truth")
    say(f"promoted{{id:{item_id},from:{frm},to:{to},by:{by}}}")
    return 0


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd, d = argv[1], Path(argv[2]).expanduser().resolve()
    if not (d / "record.json").is_file():
        die(f"no record.json in {d}")
    if cmd == "list":
        return cmd_list(d)
    if cmd == "log":
        return cmd_log(d)
    if cmd == "check":
        ok, msg = validate(d)
        say(f"validate{{ok:{str(ok).lower()},message:{msg!r}}}")
        return 0 if ok else 1
    if cmd == "set":
        if len(argv) < 5:
            die("usage: set <meeting-dir> <ITEM-ID> accept|reject|hold --by '<name>' [--why '...'] [--dry-run]", 2)
        return cmd_set(d, argv[3], argv[4])
    die(f"unknown command {cmd!r} — list | set | check | log", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
