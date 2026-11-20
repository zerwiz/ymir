#!/usr/bin/env python3
"""card_audit.py — `card.sh audit`: hold every card already on a board against the contract (gimle plan 328.6).

    card.sh audit --export <board.json> --record <record.md> --place <place> [--out <audit.md>]

<board.json> is a board read in the shape the Trello MCP's `list_by_board` answers ({lists:[{name, cards:[…]}]}).
<record.md> is the record the cards were projected from: a Markdown table whose first cell is the row id
(`| **PA1** | the action | the owner | the state |`).

Each card gets one verdict, and nothing is deleted:

    satisfies  — the card as it stands meets the contract
    reshaped   — fields recovered from the card and its record make it meet the contract
    held       — recovered what could be recovered; the named fields are owed by a person (most often acceptance)
    retired    — not a card under the contract (a decision or a question, several records in one card, no owner);
                 it may stay on the board as a view of the record, and it is named here as retired

The board is READ, never written: reshaping a board someone else lays out is that person's call. The reshaped
records are what `card.sh add` would accept once the owed fields are written.
"""
from __future__ import annotations

import json
import os
import re
import sys

import cardlib as L

NOT_TASK_LISTS = {"decided", "decisions", "open questions", "questions", "signed", "sign-off", "weekly updates"}
ID = r"[A-Z]{1,3}\d+"


def record_rows(path: str) -> dict:
    rows = {}
    if not path or not os.path.exists(path):
        return rows
    for line in open(path, encoding="utf-8"):
        s = line.strip()
        if not s.startswith("|") or "---" in s:
            continue
        cells = [re.sub(r"\*\*", "", c).strip() for c in s.strip("|").split("|")]
        if cells and re.fullmatch(ID, cells[0]):
            rows[cells[0]] = cells
    return rows


def split_title(name: str):
    m = re.match(rf"^\s*((?:{ID})(?:\s*(?:[–\-,]|,?\s*and)\s*{ID})*)\s*[—:-]\s*(.+)$", name)
    if not m:
        return [], name.strip()
    ids = re.findall(ID, m.group(1))
    if re.search(rf"{ID}\s*[–\-]\s*{ID}", m.group(1)):
        ids = ids + ["(range)"]
    return ids, m.group(2).strip()


def owner_of(desc: str, row) -> str:
    if row and len(row) >= 3:
        o = row[2]
        if not re.search(r"unnamed|no owner|nobody", o, re.I):
            return o
        return ""
    m = re.search(r"Owners?:\s*([^.]+?)(?:\s*\(tentative\))?\.", desc or "")
    return m.group(1).strip() if m else ""


def run(o: dict) -> int:
    c = L.load_contract()
    export, record, place = o.get("_export"), o.get("_record", ""), o.get("_place", "")
    if not export or not place:
        print("usage: card.sh audit --export <board.json> --record <record.md> --place <place> [--out audit.md]", file=sys.stderr)
        return 2
    board = json.load(open(export, encoding="utf-8"))
    rows = record_rows(record)
    stem = os.path.splitext(os.path.basename(record))[0] if record else place
    out, counts = [], {"satisfies": 0, "reshaped": 0, "held": 0, "retired": 0}
    for lst in board.get("lists") or []:
        lname = (lst.get("name") or "").strip()
        for card in lst.get("cards") or []:
            name, desc = card.get("name", ""), card.get("description") or card.get("desc") or ""
            ids, bare = split_title(name)
            status = {"blocked": "blocked", "in progress": "doing", "done": "done"}.get(lname.lower(), "proposed")
            v = {"card": name, "list": lname, "url": card.get("shortUrl") or card.get("url", "")}
            if lname.lower() in NOT_TASK_LISTS:
                v.update(verdict="retired", why=f"a row of the record's '{lname}' list is a decision or a question, not a task")
            elif len(ids) > 1:
                v.update(verdict="retired", why=f"carries {len([i for i in ids if i != '(range)'])}+ records in one card ({', '.join(i for i in ids if i != '(range)')}) — one card is one deliverable")
            else:
                rid = ids[0] if ids else ""
                row = rows.get(rid)
                owner = owner_of(desc, row)
                if not owner:
                    v.update(verdict="retired", why="no owner in the card or the record — 'owed a name' is not a card until someone takes it")
                else:
                    as_is = {"title": name, "owner": "", "place": place}
                    if not L.validate(L.normalise(as_is, c), c, caller="agent"):
                        v.update(verdict="satisfies")
                    else:
                        candidates = [bare] + ([row[1]] if row and len(row) > 1 else [])
                        title = next((t for t in candidates if not L.check_title(t, "task", c)), bare)
                        new = {"title": title, "owner": owner, "place": place, "status": status,
                               "evidence": f"{os.path.basename(record)}#{rid}" if rid else "",
                               "key": f"{stem}:{rid}" if rid else ""}
                        new = L.normalise(new, c)
                        reasons = L.validate(new, c, caller="agent")
                        recovered = [f for f in ("title", "owner", "evidence", "key", "status") if new.get(f)]
                        v.update(reshaped=new, recovered=recovered)
                        if reasons:
                            v.update(verdict="held", owed=reasons)
                        else:
                            v.update(verdict="reshaped")
            counts[v["verdict"]] += 1
            L.append({"door": "audit", "caller": "agent", "who": os.environ.get("CARD_WHO", "audit"), "verb": "audit",
                      "key": (v.get("reshaped") or {}).get("key", ""), "board": "trello", "ok": True,
                      "verdict": v["verdict"], "title": name,
                      "refused": v.get("owed") or ([{"field": "card", "why": v["why"]}] if v.get("why") else [])})
            out.append(v)
    md = render(out, counts, place, record, export)
    if o.get("_out"):
        with open(o["_out"], "w", encoding="utf-8") as fh:
            fh.write(md)
    print(json.dumps({"cards": len(out), **counts, "out": o.get("_out")}, indent=1))
    return 0


def render(rows, counts, place, record, export) -> str:
    L_ = ["| # | Card on the board | List | Verdict | Recovered | Owed or why |", "|---|---|---|---|---|---|"]
    for i, v in enumerate(rows, 1):
        owed = "; ".join(f"{r['field']}: {r['why']}" for r in v.get("owed") or []) or v.get("why", "")
        rec = ", ".join(v.get("recovered") or [])
        if v.get("reshaped"):
            rec += f" → *{v['reshaped']['title']}* · owner {v['reshaped']['owner']} · key `{v['reshaped'].get('key', '')}`"
        L_.append(f"| {i} | {v['card']} | {v['list']} | **{v['verdict']}** | {rec} | {owed.replace('|', '/')} |")
    head = (f"# Card audit — {place}\n\nGenerated by `card.sh audit` against `{os.path.basename(record)}`.\n\n"
            f"**{len(rows)} cards** — satisfies {counts['satisfies']} · reshaped {counts['reshaped']} · "
            f"held {counts['held']} · retired {counts['retired']}. Nothing was deleted, and the board was not written.\n\n")
    return head + "\n".join(L_) + "\n"
