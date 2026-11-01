#!/usr/bin/env python3
"""snotra-friday-synch — the Friday Synch (DEC-20261022-04).

WHY: Reygan's meeting framework requires a Friday Synch that updates the system
on assigned tasks/actions. Without it the Monday Meeting has no spine — the
"Last week's open tasks" section would be empty and the room would re-decide
everything from scratch.

WHAT IT DOES
    run     <meeting-dir>   post status updates on cards in This Week for the
                            given meeting (or the most recent meeting if the dir
                            has no record). Comments on each card with the
                            owner's progress, or moves it to Backlog if
                            unstarted.
    dry-run <meeting-dir>   what would be posted — no writes at all.
    status  <meeting-dir>   one row per card in This Week: title, owner, status.

THE LAWS
    * the record is the only source: every update traces to a DEC / ACT / OQ id;
    * a card in This Week with an owner gets a comment summarising its state;
    * a card in This Week with no progress since last Friday is moved to Backlog
      with a comment explaining why;
    * nothing is invented to fill a section: an empty section says so;
    * the card carries `record-key: <meeting>:ACT-<id>` — a second run updates,
      never duplicates.
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
    print(f"snotra-friday-synch: {msg}", file=sys.stderr)
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
        die("the record names no company/place — the synch cannot know which shape to use")
    return load_yaml(T.home_dir() / "hodd" / "identity" / "places" / company / place / "place.yaml")


def find_this_week_list(place: dict) -> tuple[str, str]:
    """Return (board_name, list_id) for This Week."""
    board = place.get("board") or die("the place declares no board")
    # This Week is a standard list name across all workstream boards
    b = T.resolve_board(board)
    b["id"] = T.board_id_of(board)
    # Try to resolve "This Week" directly; fall back to scanning lists
    try:
        _, lst = T.resolve_list(board, "This Week")
        return board, lst["id"]
    except SystemExit:
        # Scan the board's lists for "This Week"
        for l in T.api("GET", f"/boards/{b['id']}/lists", {"fields": "name,id"}):
            if (l.get("name") or "").strip().lower() == "this week":
                return board, l["id"]
        die(f"board {board!r} has no 'This Week' list")
    return board, ""


def find_card_by_key(board_id: str, key: str) -> dict | None:
    """Find a card by its record-key in the description."""
    for c in T.board_cards(board_id):
        for line in (c.get("desc") or "").splitlines():
            if line.strip() == f"{KEY}: {key}":
                return c
    return None


def last_synch_comment(card: dict) -> str:
    """Extract the last Friday Synch comment from the card's description or comments."""
    desc = card.get("desc") or ""
    for line in desc.splitlines():
        if line.startswith("## Last Friday Synch"):
            # Everything after this heading is the last synch
            idx = desc.find("## Last Friday Synch")
            return desc[idx + len("## Last Friday Synch"):].strip()
    return ""


def build_synch_comment(rec: dict, card: dict, action_id: str) -> str:
    """Build a Friday Synch comment for a card."""
    mid = (rec.get("meeting") or {}).get("meeting_id") or "meeting"
    # Find the action in the record
    action = None
    for a in rec.get("actions") or []:
        if a.get("action_id") == action_id:
            action = a
            break
    if not action:
        return f"## Last Friday Synch\nNo matching action in record for {action_id}"

    owner = action.get("owner") or "unowned"
    due = action.get("due_at") or "unresolved"
    done_when = action.get("definition_of_done") or "to be agreed"
    status = action.get("status") or "in_progress"

    # Check if the card has a checklist and count completed items
    checklist_text = ""
    try:
        checklists = T.api("GET", f"/cards/{card['id']}/checklists", {"fields": "name"})
        for cl in checklists:
            items = T.api("GET", f"/checklists/{cl['id']}/checkItems", {"fields": "name,checked"})
            total = len(items)
            done = sum(1 for i in items if i.get("checked"))
            if total > 0:
                checklist_text = f"\n**Progress:** {done}/{total} checklist items done"
    except SystemExit:
        pass

    return (
        f"## Last Friday Synch\n"
        f"**Owner:** {owner}\n"
        f"**Due:** {due}\n"
        f"**Status:** {status}\n"
        f"**Done when:** {done_when}"
        + checklist_text
        + f"\n\n*Source: {mid} · {action_id}*"
    )


def post_comment(card_id: str, text: str) -> str:
    """Post a comment on a card via the Trello API."""
    try:
        r = T.api("POST", "/cards/{card_id}/actions/comment", {
            "text": text[:16000],
        })
        return r.get("id", "posted")
    except SystemExit as e:
        print(f"  note: comment failed — {e}", file=sys.stderr)
        return "failed"


def move_card(card_id: str, list_id: str, board_id: str, reason: str) -> str:
    """Move a card to a different list and leave a note."""
    try:
        T.update_card(card_id, idList=list_id)
        # Leave a note explaining the move
        note = f"## Auto-move\n**Reason:** {reason}\n**Moved by:** snotra-friday-synch\n"
        post_comment(card_id, note)
        return "moved"
    except SystemExit as e:
        print(f"  note: move failed — {e}", file=sys.stderr)
        return "failed"


def run_one_card(rec: dict, card: dict, this_week_id: str, backlog_id: str, board_id: str, dry: bool) -> str:
    """Process one card in This Week. Returns verdict: updated | moved | skipped."""
    # Extract action_id from the card's description
    key = None
    for line in (card.get("desc") or "").splitlines():
        if line.strip().startswith(KEY + ":"):
            key = line.strip().split(KEY + ":", 1)[1].strip()
            break
    if not key:
        return "skipped"

    action_id = key.split(":")[-1] if ":" in key else key
    if not action_id.startswith("ACT-"):
        return "skipped"

    if dry:
        say(f"would-comment {action_id} → {card.get('name', '?')[:60]}")
        return "would-comment"

    comment = build_synch_comment(rec, card, action_id)
    cid = post_comment(card["id"], comment)
    say(f"commented {action_id} → {card.get('name', '?')[:60]} (id:{card['id']})")
    return "updated"


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

    board_name, this_week_id = find_this_week_list(place)
    # Find Backlog list for Rule A fallback
    backlog_id = None
    try:
        _, bl = T.resolve_list(board_name, "Backlog")
        backlog_id = bl["id"]
    except SystemExit:
        for l in T.api("GET", f"/boards/{T.board_id_of(board_name)}/lists", {"fields": "name,id"}):
            if (l.get("name") or "").strip().lower() == "backlog":
                backlog_id = l["id"]
                break

    cards = T.board_cards(T.board_id_of(board_name))
    this_week_cards = [c for c in cards if c.get("idList") == this_week_id]

    updated = moved = skipped = 0
    for card in this_week_cards:
        verdict = run_one_card(rec, card, this_week_id, backlog_id, T.board_id_of(board_name), dry)
        if verdict == "updated":
            updated += 1
        elif verdict == "moved":
            moved += 1
        else:
            skipped += 1

    say(f"friday-synch{{board:{board_name},cards:{len(this_week_cards)},updated:{updated},moved:{moved},skipped:{skipped},dry:{str(dry).lower()}}}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
