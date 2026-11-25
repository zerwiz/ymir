#!/usr/bin/env python3
"""board_move.py — move a Plane card to another project (Plane Community cannot do this itself).

  python3 scripts/board_move.py ALPHA-282 --to BETA            # dry run: say what would happen
  python3 scripts/board_move.py ALPHA-282 BETA-5 --to GAMMA --apply

Plane Community 1.4 has no "move to project", and a card's number belongs to its project, so a move is a copy
plus a closing note: the card is created in the target project (same title, description, priority, people,
labels, dates, and the comments, each marked with its author), the original gets a comment `Moved to BETA-7`
and is set to its project's Cancelled state, and the new card's description starts with `Moved from ALPHA-282`.
The new card has a NEW number; links that name the old one must be updated by hand.

A card that a plan file is synced to (see board_sync.py) takes its file link with it: the new card keeps the
`external_id`, the old one is released. Change the file's `product` to the target so the next sync agrees.

Never deletes anything. The token is read from the environment variable named in `plans/.board.json`.
"""
import argparse
import html
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import board_sync as bs  # noqa: E402


def find_card(plane, projects, ref):
    ident, _, num = ref.rpartition("-")
    if ident not in projects or not num.isdigit():
        bs.die(f"{ref}: no such project or card number")
    pid = projects[ident]["id"]
    for i in plane.pages(f"/projects/{pid}/issues/"):
        if str(i["sequence_id"]) == num:
            return ident, pid, i
    bs.die(f"{ref}: no such card")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cards", nargs="+", help="card ids such as ALPHA-282")
    ap.add_argument("--to", required=True, help="target project identifier, e.g. BETA")
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()
    cfg = bs.load_config()
    plane = bs.Plane(cfg)
    projects = {p["identifier"]: p for p in plane.pages("/projects/")}
    if a.to not in projects:
        bs.die(f"no project {a.to}")
    tid = projects[a.to]["id"]
    t_states = {s["name"]: s["id"] for s in plane.pages(f"/projects/{tid}/states/")}
    t_labels = {l["name"].lower(): l["id"] for l in plane.pages(f"/projects/{tid}/labels/")}
    for ref in a.cards:
        ident, pid, card = find_card(plane, projects, ref)
        if ident == a.to:
            print(f"{ref}: already in {a.to}")
            continue
        s_states = {s["id"]: s["name"] for s in plane.pages(f"/projects/{pid}/states/")}
        s_labels = {l["id"]: l["name"] for l in plane.pages(f"/projects/{pid}/labels/")}
        cancelled = next((s["id"] for s in plane.pages(f"/projects/{pid}/states/") if s.get("group") == "cancelled"), None)
        comments = plane.pages(f"/projects/{pid}/issues/{card['id']}/comments/")
        state_name = s_states.get(card.get("state"))
        print(f"{ref} -> {a.to}: \"{card['name'][:60]}\"  state {state_name} -> "
              f"{state_name if state_name in t_states else 'Backlog'}, {len(comments)} comments, "
              f"{len(card.get('labels') or [])} labels{'  (synced to a file)' if card.get('external_id') else ''}")
        if not a.apply:
            continue
        lab_ids = []
        for lid in card.get("labels") or []:
            n = s_labels.get(lid)
            if n and n.lower() not in t_labels:
                t_labels[n.lower()] = plane.call("POST", f"/projects/{tid}/labels/", {"name": n})["id"]
                time.sleep(bs.PAUSE)
            if n:
                lab_ids.append(t_labels[n.lower()])
        body = {"name": card["name"], "priority": card.get("priority") or "none",
                "state": t_states.get(state_name) or t_states.get("Backlog"),
                "assignees": card.get("assignees") or [], "labels": lab_ids,
                "start_date": card.get("start_date"), "target_date": card.get("target_date"),
                "description_html": f"<p>Moved from {ref}</p>" + (card.get("description_html") or "")}
        if card.get("external_id"):
            body["external_id"], body["external_source"] = card["external_id"], card.get("external_source")
        new = plane.call("POST", f"/projects/{tid}/issues/", {k: v for k, v in body.items() if v is not None})
        time.sleep(bs.PAUSE)
        for c in comments:
            who = (c.get("actor_detail") or {}).get("display_name") or "someone"
            plane.call("POST", f"/projects/{tid}/issues/{new['id']}/comments/",
                       {"comment_html": f"<p><em>{html.escape(who)} wrote on {ref}:</em></p>" + (c.get("comment_html") or "")})
            time.sleep(bs.PAUSE)
        plane.call("POST", f"/projects/{pid}/issues/{card['id']}/comments/",
                   {"comment_html": f"<p>Moved to {a.to}-{new['sequence_id']}</p>"})
        patch = {"external_id": None, "external_source": None} if card.get("external_id") else {}
        if cancelled:
            patch["state"] = cancelled
        if patch:
            plane.call("PATCH", f"/projects/{pid}/issues/{card['id']}/", patch)
        time.sleep(bs.PAUSE)
        print(f"  done: {a.to}-{new['sequence_id']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
