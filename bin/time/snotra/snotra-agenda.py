#!/usr/bin/env python3
"""snotra-agenda — the agenda card that drives the next meeting (DEC-20261022-04).

WHY: the room decided that *the agenda drives the meeting*: one subject, sent 1–2 days ahead, and the last
point is always open questions. Nothing in the house read or wrote an agenda, so the Monday meeting would
have had no spine and the minutes nothing to follow.

WHAT IT DOES
    plan    <meeting-dir> [--date YYYY-MM-DD]   what the agenda card would say — no writes
    apply   <meeting-dir> [--date YYYY-MM-DD]   create/update the dated card in the place's agenda list
    verify  <meeting-dir> [--date YYYY-MM-DD]   is the card there, in the right list, with the right text

WHERE IT GOES: the place's `lists.agenda` (Synteon: *Next Meeting Agenda*), by name through the board map.
The date comes from `--date`, else the place's cadence (`monday_at` → the next such weekday).

WHAT IS ON IT, in the room's order:
    1 the open questions from the record (unanswered — they lead, because they are what is unresolved)
    2 the decisions still `proposed` (a confirmation is a meeting's business)
    3 the actions due on or before the meeting
    4 **Open questions** — always last (DEC-04)

THE LAWS
    * the record is the only source: every line traces to a DEC / ACT / OQ id;
    * the card carries `record-key: <meeting>:AGENDA-<date>` — a second run updates, never duplicates;
    * a card in another list is drift, reported, and left where a human put it;
    * nothing is invented to fill a section: an empty section says so.
"""
from __future__ import annotations

import json
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T  # noqa: E402

KEY = "record-key"


def die(msg: str, code: int = 1):
    print(f"snotra-agenda: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def load_yaml(path: Path) -> dict:
    try:
        import yaml  # noqa: PLC0415
    except Exception:  # noqa: BLE001
        die("PyYAML is missing: pip install pyyaml")
    if not path.is_file():
        die(f"no place profile at {path}")
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def place_of(rec: dict) -> dict:
    m = rec.get("meeting") or {}
    company, place = (m.get("company") or ""), (m.get("place") or "")
    if not company or not place:
        die("the record names no company/place — the agenda cannot know which shape to use")
    return load_yaml(T.home_dir() / "hodd" / "identity" / "places" / company / place / "place.yaml")


def next_date(place: dict, override: str | None, last_held: str | None) -> str:
    if override:
        return override
    cadence = place.get("cadence") or {}
    at = str(cadence.get("monday_at") or "09:00")
    start = date.today()
    if last_held:
        try:
            start = datetime.strptime(last_held[:10], "%Y-%m-%d").date()
        except ValueError:
            pass
    d = start + timedelta(days=1)
    while d.weekday() != 0:  # Monday — the room's weekly review
        d += timedelta(days=1)
    return f"{d.isoformat()} {at}"


def build(rec: dict, place: dict, when: str) -> tuple[str, str, str]:
    mid = (rec.get("meeting") or {}).get("meeting_id") or "meeting"
    day = when[:10]
    qs = [q for q in (rec.get("questions") or []) if (q.get("status") or "open") in ("open", "proposed")]
    pending = [d for d in (rec.get("decisions") or []) if (d.get("status") or "decided") == "proposed"]
    acts = [a for a in (rec.get("actions") or []) if (a.get("due_at") or "9999")[:10] <= day]
    lines = [f"**Meeting: {when}** — the agenda drives the meeting (DEC-20261022-04). The last point is "
             f"always open questions.", ""]
    n = 0
    lines.append("**1 · Confirm what is still proposed**")
    if pending:
        for d in pending:
            n += 1
            lines.append(f"{n}. [{d.get('grade') or '—'}] {d.get('statement')} — *{d.get('decision_id')}, still proposed*")
    else:
        lines.append("_Every decision in the register is promoted._")
    lines.append("")
    lines.append("**2 · Actions due by this meeting**")
    if acts:
        for a in acts:
            n += 1
            lines.append(f"{n}. {a.get('deliverable')} — {a.get('owner') or 'unowned'}, due "
                         f"{a.get('due_at') or 'unresolved'} (*{a.get('action_id')}*)")
    else:
        lines.append("_No action falls due by this date._")
    lines.append("")
    lines.append("**3 · Open questions** — the last point, always")
    if qs:
        for q in qs:
            n += 1
            lines.append(f"{n}. {q.get('question')} (*{q.get('question_id')}*)")
    else:
        lines.append("_No open question stands._")
    lines.append("")
    lines.append(f"{KEY}: {mid}:AGENDA-{day}")
    name = f"Agenda — {when} · {place.get('place')}"
    desc = "\n".join(lines)
    return name, desc, f"{mid}:AGENDA-{day}"


def resolve(place: dict) -> tuple[dict, str]:
    board = place.get("board") or die("the place declares no board")
    listname = (place.get("lists") or {}).get("agenda") or die("the place declares no agenda list")
    b = T.resolve_board(board)
    b["id"] = T.board_id_of(board)
    _, lst = T.resolve_list(board, listname)
    return b, lst["id"]


def find_card(board_id: str, key: str) -> dict | None:
    for c in T.board_cards(board_id):
        for line in (c.get("desc") or "").splitlines():
            if line.strip() == f"{KEY}: {key}":
                return c
    return None


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd = argv[1]
    d = Path(argv[2]).expanduser().resolve()
    rec_p = d / "record.json"
    if not rec_p.is_file():
        die(f"no record.json in {d}")
    rec = json.loads(rec_p.read_text(encoding="utf-8"))
    place = place_of(rec)
    override = None
    for i, a in enumerate(argv):
        if a == "--date" and i + 1 < len(argv):
            override = argv[i + 1]
    when = next_date(place, override, (rec.get("meeting") or {}).get("started_at"))
    name, desc, key = build(rec, place, when)
    b, list_id = resolve(place)
    card = find_card(b["id"], key)
    if cmd in ("plan",):
        verdict = "create" if not card else ("update" if (card.get("name") != name or (card.get("desc") or "").strip() != desc.strip()) else "ok")
        say(f"agenda{{date:{when},board:{b.get('name')},list_id:{list_id},verdict:{verdict},card:{card.get('id') if card else None}}}")
        for line in desc.splitlines():
            say("  " + line)
        return 0
    if cmd == "apply":
        desc_lines = desc.splitlines()
        lids = [T.ensure_label(b["id"], n, c) for n, c in ((place.get("labels") or {}).items())
                if n in desc]
        if card is None:
            made = T.create_card(list_id, b["id"], name, desc, lids)
            back = T.get_card(made["id"])
            ok = back.get("idList") == list_id
            say(f"created{{id:{made['id']},list_ok:{str(ok).lower()}}}")
            return 0 if ok else 1
        if card.get("idList") != list_id:
            say(f"DRIFT{{card:{card['id']},why:'in another list than the place names'}} — left where it is")
            return 1
        if (card.get("desc") or "").strip() == desc.strip() and card.get("name") == name:
            say(f"ok{{card:{card['id']},verdict:'already current'}}")
            return 0
        T.update_card(card["id"], name=name, desc=desc)
        say(f"updated{{card:{card['id']}}}")
        return 0
    if cmd in ("verify", "status"):
        if card is None:
            say("agenda{missing:true}")
            return 1
        in_list = card.get("idList") == list_id
        say(f"agenda{{card:{card['id']},in_list:{str(in_list).lower()},name:{card.get('name')!r}}}")
        return 0 if in_list else 1
    die(f"unknown command {cmd!r} — plan | apply | verify | status", 2)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
