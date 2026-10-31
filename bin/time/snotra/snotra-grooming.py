#!/usr/bin/env python3
"""snotra-grooming — the Monthly Grooming card (DEC-20261022-04).

WHY: Reygan's meeting framework requires a monthly grooming session that goes
through the bucket list of tasks/actions discussed and picked up during calls,
and decides which are prioritised for the coming month. Without it the Backlog
grows unbounded and the Monday Meeting has no prioritised list to pull from.

WHAT IT DOES
    run     <meeting-dir>   create/update the Monthly Grooming card on the
                            Next Meeting Agenda list. The card lists all actions
                            from the record that are not yet done, grouped by
                            priority (due date, blocking status).
    dry-run <meeting-dir>   what would be created — no writes.
    status  <meeting-dir>   is the grooming card there, in the right list?

THE LAWS
    * the record is the only source: every line traces to a DEC / ACT / OQ id;
    * the card carries `record-key: <meeting>:GROOM-<YYYY-MM>` — a second run
      updates, never duplicates;
    * a card in another list is drift, reported and left where a human put it;
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
    print(f"snotra-grooming: {msg}", file=sys.stderr)
    raise SystemExit(code)


def say(msg: str):
    print(msg, flush=True)


def load_yaml(path: Path) -> dict:
    try:
        import yaml  # noqa: PLC0415
    except Exception:
        die("PyYAML is missing: pip install pyyaml")
    if not path.is_file():
        die(f"no place profile at {path}")
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {}


def place_of(rec: dict) -> dict:
    m = rec.get("meeting") or {}
    company, place = (m.get("company") or ""), (m.get("place") or "")
    if not company or not place:
        die("the record names no company/place — the grooming cannot know which shape to use")
    return load_yaml(T.home_dir() / "hodd" / "identity" / "places" / company / place / "place.yaml")


def find_agenda_list(place: dict) -> tuple[str, str]:
    """Return (board_name, list_id) for Next Meeting Agenda."""
    board = place.get("board") or die("the place declares no board")
    b = T.resolve_board(board)
    b["id"] = T.board_id_of(board)
    _, lst = T.resolve_list(board, "Next Meeting Agenda")
    return board, lst["id"]


def find_grooming_card(board_id: str, month_key: str) -> dict | None:
    """Find the grooming card for this month."""
    for c in T.board_cards(board_id):
        for line in (c.get("desc") or "").splitlines():
            if line.strip() == f"{KEY}: {month_key}":
                return c
    return None


def build_grooming_card(rec: dict, month: str) -> tuple[str, str]:
    """Build the grooming card content."""
    mid = (rec.get("meeting") or {}).get("meeting_id") or "meeting"
    today = date.today()
    month_name = datetime.strptime(month, "%Y-%m").strftime("%B %Y")

    # Gather all actions not yet done
    actions = rec.get("actions") or []
    overdue = []
    due_soon = []
    no_due = []
    for a in actions:
        due = a.get("due_at") or ""
        status = a.get("status") or "proposed"
        if status in ("done", "completed", "signed"):
            continue
        if due:
            try:
                due_date = datetime.strptime(due[:10], "%Y-%m-%d").date()
                if due_date < today:
                    overdue.append(a)
                elif (due_date - today).days <= 7:
                    due_soon.append(a)
                else:
                    no_due.append(a)
            except ValueError:
                no_due.append(a)
        else:
            no_due.append(a)

    lines = [
        f"**Monthly Grooming — {month_name}**",
        "",
        f"**Meeting:** {mid}",
        "",
        "The grooming session triages the Backlog into the coming month's priorities.",
        "",
        "**1 · Overdue actions** — these need immediate attention",
    ]
    if overdue:
        for i, a in enumerate(overdue, 1):
            lines.append(f"{i}. {a.get('deliverable') or a.get('action_id')} — {a.get('owner') or 'unowned'}, due {a.get('due_at') or 'unresolved'} (*{a.get('action_id')}*)")
    else:
        lines.append("_No overdue actions._")

    lines.extend(["", "**2 · Due this week** — these are due soon", ""])
    if due_soon:
        for i, a in enumerate(due_soon, 1):
            lines.append(f"{i}. {a.get('deliverable') or a.get('action_id')} — {a.get('owner') or 'unowned'}, due {a.get('due_at') or 'unresolved'} (*{a.get('action_id')}*)")
    else:
        lines.append("_No actions due this week._")

    lines.extend(["", "**3 · Backlog** — actions without a near-term due date", ""])
    if no_due:
        for i, a in enumerate(no_due, 1):
            lines.append(f"{i}. {a.get('deliverable') or a.get('action_id')} — {a.get('owner') or 'unowned'} (*{a.get('action_id')}*)")
    else:
        lines.append("_No items in backlog._")

    lines.extend(["", "**4 · Open questions** — unanswered, blocking progress", ""])
    questions = [q for q in (rec.get("questions") or []) if (q.get("status") or "open") in ("open", "proposed")]
    if questions:
        for i, q in enumerate(questions, 1):
            lines.append(f"{i}. {q.get('question') or q.get('question_id')} (*{q.get('question_id')}*)")
    else:
        lines.append("_No open questions._")

    lines.extend(["", f"{KEY}: {month_key}"])
    name = f"Grooming — {month_name}"
    desc = "\n".join(lines)
    return name, desc


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
    dry = cmd == "dry-run"

    board_name, agenda_id = find_agenda_list(place)
    month = date.today().strftime("%Y-%m")
    month_key = f"{(rec.get('meeting') or {}).get('meeting_id', 'meeting')}:GROOM-{month}"
    name, desc = build_grooming_card(rec, month)

    card = find_grooming_card(T.board_id_of(board_name), month_key)

    if cmd == "status":
        if card is None:
            say(f"grooming{{missing:true,month:{month}}}")
            return 1
        in_list = card.get("idList") == agenda_id
        say(f"grooming{{card:{card['id']},in_list:{str(in_list).lower()},month:{month}}}")
        return 0 if in_list else 1

    if cmd == "dry-run":
        if card is None:
            say(f"would-create grooming card for {month}")
        else:
            say(f"would-update grooming card {card['id']} for {month}")
        for line in desc.splitlines():
            say("  " + line)
        return 0

    # apply
    if card is None:
        made = T.create_card(agenda_id, T.board_id_of(board_name), name, desc, [])
        back = T.get_card(made["id"])
        ok = back.get("idList") == agenda_id
        say(f"created{{card:{made['id']},month:{month},list_ok:{str(ok).lower()}}}")
        return 0 if ok else 1

    if card.get("idList") != agenda_id:
        say(f"DRIFT{{card:{card['id']},why:'in another list than Next Meeting Agenda'}} — left where it is")
        return 1

    if (card.get("desc") or "").strip() == desc.strip() and card.get("name") == name:
        say(f"ok{{card:{card['id']},month:{month},verdict:'already current'}}")
        return 0

    T.update_card(card["id"], name=name, desc=desc)
    say(f"updated{{card:{card['id']},month:{month}}}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
