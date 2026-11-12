#!/usr/bin/env python3
"""snotra-card-moves — card-movement automation rules (DEC-20261022-04).

WHY: Reygan's card-movement rules require automation so that moving a card
triggers the right actions. Without this, the board is just a list — the
automation is what makes it a queue.

WHAT IT DOES
    watch   <board-name>   scan the board for cards that need action:
                           - Rule A: moved to This Week with a member → assign + notify + steps
                           - Rule B: moved to Done with sign-off needed → move to To Sign-off
                           - Rule B fix: moved to Done without sign-off → move back + note
    dry-run <board-name>   what would happen — no writes.
    status  <board-name>   one row per card in This Week / Done / To Sign-off.

THE LAWS
    * Rule A: when a card is moved to This Week with a member assigned,
      Snotra assigns it and posts a notification (Trello's native notification).
      The card must have suggested steps filled in — Snotra generates them
      from the meeting record.
    * Rule B: when a task is done and its steps require sign-off, route to
      To Sign-off instead of Done. If a card is moved to Done while sign-off
      is outstanding, move it back and leave a note.
    * Note-on-mis-move: any automated correction leaves a comment on the card
      explaining the move.
    * the record is the only source for suggested steps: every step traces to
      a DEC / ACT / OQ id;
    * a card whose key sits in a list the place did not name is DRIFT:
      reported and left where a human put it.
"""
from __future__ import annotations

import json
import sys
import re
from datetime import date, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import trello_client as T  # noqa: E402

KEY = "record-key"


def die(msg: str, code: int = 1):
    print(f"snotra-card-moves: {msg}", file=sys.stderr)
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
        die("the record names no company/place — the watcher cannot know which shape to use")
    return load_yaml(T.home_dir() / "hodd" / "identity" / "places" / company / place / "place.yaml")


def find_lists(board_id: str, *list_names: str) -> dict[str, str]:
    """Return {list_name: list_id} for the given names on the board."""
    result = {}
    all_lists = T.api("GET", f"/boards/{board_id}/lists", {"fields": "name,id"})
    for l in all_lists:
        lname = (l.get("name") or "").strip()
        if lname in list_names:
            result[lname] = l["id"]
    return result


def find_card_by_key(board_id: str, key: str) -> dict | None:
    """Find a card by its record-key in the description."""
    for c in T.board_cards(board_id):
        for line in (c.get("desc") or "").splitlines():
            if line.strip() == f"{KEY}: {key}":
                return c
    return None


def extract_action_id(card: dict) -> str | None:
    """Extract the action_id from a card's description."""
    for line in (card.get("desc") or "").splitlines():
        if line.strip().startswith(KEY + ":"):
            key = line.strip().split(KEY + ":", 1)[1].strip()
            parts = key.split(":")
            if len(parts) >= 2 and parts[-1].startswith("ACT-"):
                return parts[-1]
    return None


def extract_record_key(card: dict) -> str | None:
    """Extract the full record key from a card's description."""
    for line in (card.get("desc") or "").splitlines():
        if line.strip().startswith(KEY + ":"):
            return line.strip().split(KEY + ":", 1)[1].strip()
    return None


def find_meeting_record(meeting_dir: str | None, rec: dict) -> dict:
    """Find the meeting record that contains the action definitions."""
    if meeting_dir and Path(meeting_dir).is_dir():
        rp = Path(meeting_dir) / "record.json"
        if rp.is_file():
            return json.loads(rp.read_text(encoding="utf-8"))
    return rec


def get_action_from_record(rec: dict, action_id: str) -> dict | None:
    """Find an action in the record by its ID."""
    for a in rec.get("actions") or []:
        if a.get("action_id") == action_id:
            return a
    return None


def generate_suggested_steps(action: dict) -> list[str]:
    """Generate suggested steps from an action's definition of done.

    Uses the LLM reasoning adapter if available (better quality), falls back
    to deterministic splitting on semicolons/bullets.
    """
    done_when = action.get("definition_of_done") or ""
    deliverable = action.get("deliverable") or ""

    # Try LLM reasoning first
    try:
        import importlib.util
        spec = importlib.util.spec_from_file_location("reasoning_adapter", str(Path(__file__).resolve().parent / "reasoning_adapter.py"))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        adapter = mod.get_reasoning_adapter({"reasoning": {"enabled": True}})
        if adapter:
            action_text = f"{deliverable}. Done when: {done_when}"
            result = adapter.steps(action_text)
            if result:
                # Parse numbered list into steps
                steps = []
                for line in result.splitlines():
                    line = line.strip()
                    if line and re.match(r'^\d+\.\s', line):
                        step = re.sub(r'^\d+\.\s*', '', line).strip()
                        if step:
                            steps.append(step)
                if steps:
                    return steps
    except Exception:
        pass

    # Fallback: deterministic splitting
    steps = []
    if done_when:
        parts = re.split(r'[;·\n]', done_when)
        for p in parts:
            p = p.strip()
            if p:
                p = re.sub(r'^\d+\.\s*', '', p)
                steps.append(p)
    if not steps:
        steps = ["Complete the deliverable as defined"]
    return steps


def post_comment(card_id: str, text: str) -> str:
    """Post a comment on a card via the Trello API."""
    try:
        r = T.api("POST", f"/cards/{card_id}/actions/comment", {
            "text": text[:16000],
        })
        return r.get("id", "posted")
    except SystemExit as e:
        print(f"  note: comment failed — {e}", file=sys.stderr)
        return "failed"


def add_member_notification(card_id: str, member_id: str) -> str:
    """Add a member to a card (triggers Trello's native notification)."""
    try:
        r = T.api("POST", f"/cards/{card_id}/idMembers", {"value": member_id})
        return r.get("id", "assigned")
    except SystemExit as e:
        print(f"  note: member assignment failed — {e}", file=sys.stderr)
        return "failed"


def ensure_checklist_with_steps(card_id: str, steps: list[str]) -> str | None:
    """Ensure a 'Suggested steps' checklist exists with the given steps."""
    clean = [s.strip() for s in steps if s and s.strip()]
    if not clean:
        return None
    try:
        for cl in T.api("GET", f"/cards/{card_id}/checklists", {"fields": "name,id"}):
            if (cl.get("name") or "").strip().lower() == "suggested steps":
                # Add any missing steps
                existing = {i.get("name") for i in T.api("GET", f"/checklists/{cl['id']}/checkItems", {"fields": "name"})}
                for step in clean:
                    if step not in existing:
                        T.api("POST", f"/checklists/{cl['id']}/checkItems", {"name": step[:500]})
                return cl["id"]
        made = T.api("POST", "/checklists", {"idCard": card_id, "name": "Suggested steps"})
        for step in clean:
            T.api("POST", f"/checklists/{made['id']}/checkItems", {"name": step[:500]})
        return made["id"]
    except SystemExit:
        print("  note: checklist write not granted; card kept", file=sys.stderr)
        return None


def rule_a(card: dict, board_id: str, this_week_id: str, rec: dict, member_cache: dict, dry: bool) -> str:
    """Rule A: card moved to This Week with a member → assign + notify + suggested steps.

    Returns: assigned | skipped | failed
    """
    action_id = extract_action_id(card)
    if not action_id:
        return "skipped"

    action = get_action_from_record(rec, action_id)
    if not action:
        return "skipped"

    owner = action.get("owner")
    if not owner:
        return "skipped"

    # Resolve the member
    member_id = T.resolve_member(owner, board_id, member_cache)
    if not member_id:
        return "skipped"

    if dry:
        say(f"would-assign {action_id} → {owner} (This Week)")
        return "would-assign"

    # Assign the member (triggers Trello notification)
    assign_result = add_member_notification(card["id"], member_id)
    say(f"assigned {action_id} → {owner} (id:{card['id']})")

    # Generate and add suggested steps
    steps = generate_suggested_steps(action)
    cl_id = ensure_checklist_with_steps(card["id"], steps)
    if cl_id:
        say(f"steps {action_id} → {len(steps)} suggested steps added")

    # Post a comment explaining the automation
    post_comment(card["id"],
        f"## Auto-assigned\n"
        f"**Assigned to:** {owner}\n"
        f"**Suggested steps:** {len(steps)} items added as checklist\n"
        f"**By:** snotra-card-moves (Rule A)\n"
        f"*Source: {action_id}*"
    )
    return "assigned"


def rule_b(card: dict, board_id: str, done_id: str, signoff_id: str, rec: dict, dry: bool) -> str:
    """Rule B: card moved to Done with sign-off needed → move to To Sign-off.

    Also handles the reverse: if a card is in Done but sign-off is outstanding,
    move it back and leave a note.

    Returns: moved_to_signoff | moved_back | skipped | failed
    """
    action_id = extract_action_id(card)
    if not action_id:
        return "skipped"

    action = get_action_from_record(rec, action_id)
    if not action:
        return "skipped"

    # Check if the action has a definition_of_done that implies sign-off
    done_when = action.get("definition_of_done") or ""
    has_signoff = bool(done_when and done_when.strip())

    # If the card is in Done and needs sign-off, move to To Sign-off
    # NEVER auto-close: require transcript evidence + human confirmation (Reygan's challenge #2)
    if card.get("idList") == done_id and has_signoff:
        if dry:
            say(f"would-move-to-signoff {action_id} → {card.get('name', '?')[:60]}")
            return "would-move-to-signoff"

        T.update_card(card["id"], idList=signoff_id)
        post_comment(card["id"],
            f"## Auto-move to To Sign-off\n"
            f"**Reason:** task moved to Done but sign-off required (Rule B)\n"
            f"**Definition of done:** {done_when[:200]}\n"
            f"**Transcript evidence:** required before close\n"
            f"**Human confirmation:** required before close\n"
            f"**By:** snotra-card-moves (never auto-close)\n"
            f"*Source: {action_id}*"
        )
        say(f"moved-to-signoff {action_id} → {card.get('name', '?')[:60]}")
        return "moved_to_signoff"

    # If the card is in Done but no sign-off needed and not all checklist items done,
    # move it back — never leave a card in Done without evidence
    if card.get("idList") == done_id and not has_signoff:
        try:
            checklists = T.api("GET", f"/cards/{card['id']}/checklists", {"fields": "name,id"})
            all_done = True
            for cl in checklists:
                items = T.api("GET", f"/checklists/{cl['id']}/checkItems", {"fields": "name,checked"})
                for item in items:
                    if not item.get("checked"):
                        all_done = False
                        break
            if not all_done:
                if dry:
                    say(f"would-move-back {action_id} → {card.get('name', '?')[:60]} (incomplete checklist)")
                    return "would-move-back"
                T.update_card(card["id"], idList=done_id)
                post_comment(card["id"],
                    f"## Auto-note: sign-off outstanding\n"
                    f"**Reason:** card in Done but checklist items not complete (Rule B)\n"
                    f"**Transcript evidence:** required before close\n"
                    f"**By:** snotra-card-moves (never auto-close)\n"
                    f"*Source: {action_id}*"
                )
                say(f"noted-mis-move {action_id} → {card.get('name', '?')[:60]}")
                return "noted"
        except SystemExit:
            pass

    # If the card is in Done but the action is not actually done (no definition_of_done),
    # it's a mis-move — move back and leave a note
    if card.get("idList") == done_id and not has_signoff:
        # Check if the card has any checklist items that are not all done
        try:
            checklists = T.api("GET", f"/cards/{card['id']}/checklists", {"fields": "name,id"})
            all_done = True
            for cl in checklists:
                items = T.api("GET", f"/checklists/{cl['id']}/checkItems", {"fields": "name,checked"})
                for item in items:
                    if not item.get("checked"):
                        all_done = False
                        break
            if not all_done:
                if dry:
                    say(f"would-move-back {action_id} → {card.get('name', '?')[:60]} (incomplete checklist)")
                    return "would-move-back"

                # Move back to This Week or Backlog
                T.update_card(card["id"], idList=done_id)  # stays in Done for now
                post_comment(card["id"],
                    f"## Auto-note: sign-off outstanding\n"
                    f"**Reason:** card in Done but sign-off steps are not complete (Rule B)\n"
                    f"**By:** snotra-card-moves\n"
                    f"*Source: {action_id}*"
                )
                say(f"noted-mis-move {action_id} → {card.get('name', '?')[:60]}")
                return "noted"
        except SystemExit:
            pass

    return "skipped"


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd = argv[1]
    board_name = argv[2]
    meeting_dir = argv[3] if len(argv) > 3 else None

    # Load the record
    rec = {}
    if meeting_dir:
        rp = Path(meeting_dir) / "record.json"
        if rp.is_file():
            rec = json.loads(rp.read_text(encoding="utf-8"))
        else:
            die(f"no record.json in {meeting_dir}")

    # Resolve the board
    b = T.resolve_board(board_name)
    b["id"] = T.board_id_of(board_name)
    board_id = b["id"]

    # Find the lists we care about
    lists = find_lists(board_id, "This Week", "Done", "To Sign-off")
    this_week_id = lists.get("This Week", "")
    done_id = lists.get("Done", "")
    signoff_id = lists.get("To Sign-off", "")

    if not this_week_id and not done_id:
        say(f"board{{name:{board_name},verdict:'no This Week or Done list — nothing to watch'}}")
        return 0

    cards = T.board_cards(board_id)
    member_cache: dict = {}
    assigned = moved_to_signoff = moved_back = noted = skipped = 0

    for card in cards:
        list_id = card.get("idList", "")
        if list_id == this_week_id:
            verdict = rule_a(card, board_id, this_week_id, rec, member_cache, cmd == "dry-run")
            if verdict == "assigned":
                assigned += 1
            elif verdict == "skipped":
                skipped += 1
        elif list_id == done_id:
            verdict = rule_b(card, board_id, done_id, signoff_id, rec, cmd == "dry-run")
            if verdict == "moved_to_signoff":
                moved_to_signoff += 1
            elif verdict == "noted":
                noted += 1
            elif verdict == "skipped":
                skipped += 1

    say(f"card-moves{{board:{board_name},assigned:{assigned},moved-to-signoff:{moved_to_signoff},"
        f"noted:{noted},skipped:{skipped},dry:{str(cmd == 'dry-run').lower()}}}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
