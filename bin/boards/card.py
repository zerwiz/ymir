#!/usr/bin/env python3
"""card.sh — THE door every card passes through (gimle plan 328). A person, an agent, Rödd by voice and an MCP tool
all make cards here, against one contract, into one ledger.

    card.sh add    --to <place> --title "<verb + deliverable>" --owner <person|seat> --accept "<check>" [--accept …]
                   [--due YYYY-MM-DD | --due unresolved --decide-by YYYY-MM-DD] [--evidence <file#line|meeting:ts>]
                   [--kind task|bug|chore|spike] [--timebox 1h] [--status proposed] [--key <derived>]
                   [--objective …] [--step …] [--out-of-scope …]
                   [--area …] [--context @desk] [--energy deep] [--estimate 1h] [--start YYYY-MM-DD] [--waiting …]
                   [--board plane|trello|github --target <workspace/project | list-id | owner/repo>]
    card.sh move   <key> --status proposed|accepted|doing|done|blocked [--why "blocked by …"] [--due …]
    card.sh assign <key> --to <person|seat>
    card.sh bind   <key> --board <b> --ref <board's id> [--target …]   # after an MCP tool carried a projected card
    card.sh list   [--to <place>] [--status …]
    card.sh show   <key>                          # the record, and which board carries it
    card.sh check  [the add flags]                # the guard alone; writes nothing
    card.sh audit  --export <board.json> --record <record.md> --place <p> [--out <file.md>]
    card.sh contract                              # where the contract is, and its required fields

Every flag also reads --as <who> (default $CARD_WHO, else $USER) and --door <shell|mcp|voice|agent> (default shell;
mcp, voice and agent must carry --evidence). Exit: 0 ok · 1 refused by name · 2 usage.
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cardlib as L  # noqa: E402

REPEAT = {"--accept": "acceptance", "--step": "steps"}
SINGLE = {"--to": "place", "--title": "title", "--owner": "owner", "--due": "due", "--decide-by": "decide_by",
          "--evidence": "evidence", "--kind": "kind", "--timebox": "timebox", "--status": "status", "--key": "key",
          "--objective": "objective", "--out-of-scope": "out_of_scope", "--area": "area", "--context": "context",
          "--energy": "energy", "--estimate": "estimate", "--start": "start", "--waiting": "waiting",
          "--board": "_board", "--target": "_target", "--as": "_who", "--door": "_door", "--why": "_why",
          "--ref": "_ref", "--export": "_export", "--record": "_record", "--place": "_place", "--out": "_out",
          "--last": "_last"}


def parse(argv):
    o, rest, i = {}, [], 0
    while i < len(argv):
        a = argv[i]
        if a in REPEAT and i + 1 < len(argv):
            o.setdefault(REPEAT[a], []).append(argv[i + 1])
            i += 2
        elif a in SINGLE and i + 1 < len(argv):
            o[SINGLE[a]] = argv[i + 1]
            i += 2
        else:
            rest.append(a)
            i += 1
    return o, rest


def refused(verb, exc: L.Refused):
    print(f"card[{len(exc.reasons)}]{{verb,refused,field,why}}:", file=sys.stderr)
    for r in exc.reasons:
        print(f'  "{verb}","REFUSED","{r["field"]}","{r["why"].replace(chr(34), chr(39))}"', file=sys.stderr)
    return 1


def who_and_door(o):
    door = o.get("_door", "shell")
    caller = {"shell": "person"}.get(door, door)
    return o.get("_who") or os.environ.get("CARD_WHO") or os.environ.get("USER", "unknown"), door, caller


def card_of(o):
    return {k: v for k, v in o.items() if not k.startswith("_")}


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0 if argv else 2
    verb, args = argv[0], argv[1:]
    o, rest = parse(args)
    who, door, caller = who_and_door(o)
    try:
        if verb == "contract":
            c = L.load_contract()
            req = {f: s.get("required") for f, s in (c.get("fields") or {}).items()}
            print(json.dumps({"contract": c["_path"], "required": req,
                              "boards": {f: s.get("boards") for f, s in (c.get("fields") or {}).items()}}, indent=1))
            return 0
        if verb == "check":
            c = L.load_contract()
            card = L.normalise(card_of(o), c)
            reasons = L.validate(card, c, caller=caller)
            if reasons:
                return refused("check", L.Refused(reasons))
            print(json.dumps({"accepted": True, "key": card["key"],
                              **({"projection": L.plan_projection(card, o["_board"], c)} if o.get("_board") else {})},
                             indent=1, ensure_ascii=False))
            return 0
        if verb == "add":
            row = L.add(card_of(o), door=door, caller=caller, who=who, board=o.get("_board", ""),
                        target=o.get("_target", ""))
            out = {"added": row["key"], "status": row["card"]["status"], "owner": row["card"]["owner"]}
            if row.get("board"):
                out.update({k: row.get(k) for k in ("board", "board_state", "ref", "carried", "degraded", "lost", "notes", "why")})
                for f in row.get("degraded") or []:
                    print(f"card: {row['board']} has no place for '{f}' — kept in the card's body/labels", file=sys.stderr)
                for f in row.get("lost") or []:
                    print(f"card: {row['board']} cannot hold '{f}' — LOST on the board, kept in the ledger", file=sys.stderr)
                if row.get("board_state") == "projected":
                    out["carry"] = {"title": row["card"]["title"], "body": row["body"],
                                    "then": f"card.sh bind {row['key']} --board {row['board']} --ref <the id the board answers>"}
            print(json.dumps(out, indent=1, ensure_ascii=False))
            return 0
        if verb == "move":
            if not rest or not o.get("status"):
                print("usage: card.sh move <key> --status <status> [--why …]", file=sys.stderr)
                return 2
            row = L.move(rest[0], o["status"], door=door, caller=caller, who=who, waiting=o.get("_why", "") or o.get("waiting", ""),
                         due=o.get("due", ""), decide_by=o.get("decide_by", ""))
            print(json.dumps({"moved": row["key"], "status": o["status"], "boards": row.get("boards_moved"),
                              "notes": row.get("notes")}, indent=1, ensure_ascii=False))
            return 0
        if verb == "assign":
            if not rest or not o.get("place"):
                print("usage: card.sh assign <key> --to <person|seat>", file=sys.stderr)
                return 2
            row = L.assign(rest[0], o["place"], door=door, caller=caller, who=who)
            print(json.dumps({"assigned": row["key"], "owner": o["place"], "notes": row.get("notes")}, indent=1, ensure_ascii=False))
            return 0
        if verb == "bind":
            if not rest or not o.get("_board") or not o.get("_ref"):
                print("usage: card.sh bind <key> --board <b> --ref <id>", file=sys.stderr)
                return 2
            row = L.bind(rest[0], o["_board"], o["_ref"], target=o.get("_target", ""), door=door, caller=caller, who=who)
            print(json.dumps({"bound": row["key"], "board": row["board"], "ref": row["ref"]}, indent=1))
            return 0
        if verb == "list":
            cards = L.fold(L.read())
            print("card list — key · status · owner · place · boards · title")
            n = 0
            for k, v in cards.items():
                c = v["card"]
                if o.get("place") and c.get("place") != o["place"]:
                    continue
                if o.get("status") and c.get("status") != o["status"]:
                    continue
                n += 1
                print(f"  {k} · {c.get('status')} · {c.get('owner')} · {c.get('place')} · "
                      f"{','.join(v['refs']) or 'record only'} · {c.get('title')}")
            print(f"{n} card(s)")
            return 0
        if verb == "show":
            if not rest:
                print("usage: card.sh show <key>", file=sys.stderr)
                return 2
            print(json.dumps(L.find(rest[0]), indent=1, ensure_ascii=False))
            return 0
        if verb == "audit":
            import card_audit
            return card_audit.run(o)
    except L.Refused as exc:
        return refused(verb, exc)
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
