#!/usr/bin/env python3
"""report.sh — what the card ledger says (gimle plan 328.5): per board, the cards made, the refusals, the fields
each board could not hold, and the cards that never moved.

    report.sh [--last 30d|12h|all] [--json]

Reads $CARDS_LEDGER (else $YMIR_HOME/hodd/state/boards/cards.jsonl). Read-only.
"""
from __future__ import annotations

import collections
import datetime as dt
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cardlib as L  # noqa: E402


def since(spec: str):
    if not spec or spec == "all":
        return None
    m = re.fullmatch(r"(\d+)([dh])", spec)
    if not m:
        raise SystemExit(f"report: '{spec}' is not N d or N h (e.g. 30d)")
    n = int(m.group(1))
    delta = dt.timedelta(days=n) if m.group(2) == "d" else dt.timedelta(hours=n)
    return (dt.datetime.now(dt.timezone.utc) - delta).strftime("%Y-%m-%dT%H:%M:%SZ")


def main(argv):
    last = "30d"
    if "--last" in argv:
        last = argv[argv.index("--last") + 1]
    cut = since(last)
    rows = [r for r in L.read() if not cut or r.get("at", "") >= cut]
    boards = collections.OrderedDict((b, {"cards": 0, "projected": 0, "refusals": 0, "degraded": collections.Counter(),
                                          "lost": collections.Counter(), "never_moved": 0})
                                     for b in ("record only",) + L.BOARDS)
    refused_by = collections.Counter()
    refused_field = collections.Counter()
    audits = collections.Counter()
    for r in rows:
        b = r.get("board") or "record only"
        boards.setdefault(b, {"cards": 0, "projected": 0, "refusals": 0, "degraded": collections.Counter(),
                              "lost": collections.Counter(), "never_moved": 0})
        if r.get("verb") == "audit":
            audits[r.get("verdict")] += 1
            continue
        if not r.get("ok"):
            boards[b]["refusals"] += 1
            refused_by[f"{r.get('door')}/{r.get('who')}"] += 1
            for f in r.get("refused") or []:
                refused_field[f["field"]] += 1
            continue
        if r.get("verb") == "add":
            boards[b]["cards"] += 1
            if r.get("board_state") == "projected":
                boards[b]["projected"] += 1
            boards[b]["degraded"].update(r.get("degraded") or [])
            boards[b]["lost"].update(r.get("lost") or [])
    for k, v in L.fold(rows).items():
        if not any(op["verb"] == "move" for op in v["ops"]):
            first = v["ops"][0].get("board") or "record only"
            boards[first]["never_moved"] += 1
    if "--json" in argv:
        print(json.dumps({"last": last, "boards": boards, "refused_by": refused_by, "refused_field": refused_field,
                          "audit": audits}, indent=1, default=dict))
        return 0
    print(f"card report — last {last} · {len(rows)} ledger line(s) · {L.ledger_path()}\n")
    print(f"{'board':<12} {'cards':>5} {'by hand':>7} {'refused':>7} {'never moved':>11}  fields kept in body/labels · fields lost")
    for b, s in boards.items():
        deg = ", ".join(f"{f}×{n}" for f, n in s["degraded"].most_common()) or "-"
        lost = ", ".join(f"{f}×{n}" for f, n in s["lost"].most_common()) or "-"
        print(f"{b:<12} {s['cards']:>5} {s['projected']:>7} {s['refusals']:>7} {s['never_moved']:>11}  {deg} · lost: {lost}")
    if refused_by:
        print("\nrefusals by door/who: " + ", ".join(f"{k}×{n}" for k, n in refused_by.most_common()))
        print("refusals by field:    " + ", ".join(f"{k}×{n}" for k, n in refused_field.most_common()))
    if audits:
        print("audit verdicts:       " + ", ".join(f"{k}×{n}" for k, n in audits.most_common()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
