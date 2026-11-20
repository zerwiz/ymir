#!/usr/bin/env python3
"""test_todo_board — the to-do board door, against a fake board (no network, a fenced home).

Run: python3 bin/records/tests/test_todo_board.py
"""
from __future__ import annotations

import importlib.util
import json
import os
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("todo_board", HERE.parent / "todo_board.py")
tb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tb)

TODO_MD = """# A day — invented for the test

# His half — what only he can do

## Today

- [ ] **Call Ada about the roof** — before noon. *(due 2026-12-01; priority high)*
      A second line that belongs to it.
- [x] **Send the invoice** — done already.

## This week

- [ ] **Book the trip**

## Held, deliberately

- [ ] **Learn the lute**

# The house-kept half — what his messages moved

## Set from the night

### Waiting on you — nothing else moves these

- [ ] 2026-11-12 · host-a — waiting on a reply
"""

VOICE = [
    {"ts": "2026-11-10T05:24:33", "action": "add", "id": "t1", "item": "Measure the card", "due": "2026-11-10",
     "priority": "high", "project": "lab"},
    {"ts": "2026-11-10T05:25:00", "action": "add", "id": "t2", "item": "Tidy the shelf", "due": "",
     "priority": "low", "project": ""},
    {"ts": "2026-11-11T09:00:00", "action": "done", "id": "t2"},
]


class FakeBoard:
    """Speaks the board door's tool names; holds cards in memory; can go dark on demand."""

    def __init__(self, states=None):
        self.states = states or [{"name": "Backlog", "group": "backlog"}, {"name": "Todo", "group": "unstarted"},
                                 {"name": "Done", "group": "completed"}]
        self.labels, self.cards, self.dark, self.calls = set(), [], False, []

    def __call__(self, name, args):
        self.calls.append(name)
        if self.dark:
            raise tb.BoardDark("fake: dark")
        if name == "list_states":
            return {"states": self.states}
        if name == "list_labels":
            return {"labels": [{"name": n} for n in sorted(self.labels)]}
        if name == "create_label":
            self.labels.add(args["name"])
            return {"label": args["name"]}
        if name == "create_card":
            for l in args.get("labels") or []:
                if l not in self.labels:
                    raise tb.BoardError(f"unknown label {l}")
            if any(a not in ("ada",) for a in args.get("assignees") or []):
                raise tb.BoardError(f"cannot assign {args['assignees']}")
            card = len(self.cards) + 1
            self.cards.append(dict(args, card=card))
            return {"created": {"card": card, "title": args["title"]}, "labels": 0}
        if name == "list_cards":
            return {"cards": [{"card": c["card"], "title": c["title"], "state": c.get("state")} for c in self.cards],
                    "count": len(self.cards)}
        raise AssertionError(f"unexpected tool {name}")


FAILS = []


def check(name, cond, detail=""):
    print(("ok   " if cond else "FAIL ") + name + (f" — {detail}" if detail and not cond else ""))
    if not cond:
        FAILS.append(name)


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        # the fence: a home of our own, nothing real is read or written
        os.environ["YMIR_HOME"] = tmp
        os.environ["YMIR_STATE_DIR"] = str(Path(tmp) / "state")
        for k in ("YMIR_TODO_BOARD_PLACE", "YMIR_TODO_BOARD_URL", "YMIR_TODO_BOARD_TOKEN"):
            os.environ.pop(k, None)
        me = Path(tmp) / "hodd" / "life" / "personal" / "me"
        me.mkdir(parents=True)
        (me / "todo.md").write_text(TODO_MD, encoding="utf-8")
        vdir = Path(tmp) / "hodd" / "state" / "voice"
        vdir.mkdir(parents=True)
        (vdir / "todos.jsonl").write_text("".join(json.dumps(e) + "\n" for e in VOICE), encoding="utf-8")

        # 1. unconfigured is a clean skip, never an error
        r = tb.add({"title": "x"})
        check("unconfigured add is a skip", r["verdict"] == "skip", r)

        cfg = {"place": "house/private", "url": "https://fake.invalid", "token": "t", "owners": {"Ada": "ada"}}
        fake = FakeBoard()
        board = tb.Board(cfg, call=fake)

        # 2. parsing: every checkbox one item, continuation kept verbatim, lanes from headings
        items = tb.read_items()
        md = [i for i in items if "todo.md" in i["source"]]
        check("five markdown items", len(md) == 5, len(md))
        first = md[0]
        check("title from the bold", first["title"] == "Call Ada about the roof", first["title"])
        check("continuation kept verbatim", "A second line that belongs to it." in first["note"])
        check("due and priority read", first["due"] == "2026-12-01" and first["priority"] == "high")
        lanes = [i["lane"] for i in md]
        check("lanes from headings", lanes == ["Today", "Done", "This week", "Someday", "Waiting"], lanes)
        voice = [i for i in items if "voice" in i["key"]]
        check("voice record replayed", [v["status"] for v in voice] == ["open", "done"])

        # 3. migration counts in == out, and a second run files nothing new
        rep = tb.migrate(board)
        check("migration whole", rep["whole"] and rep["in"] == {"open": 5, "done": 2}, rep)
        check("seven cards filed", len(fake.cards) == 7 and rep["filed"] == 7, rep)
        again = tb.migrate(board)
        check("second run is idempotent", again["filed"] == 0 and again["exists"] == 7 and len(fake.cards) == 7,
              again)
        check("second run still whole", again["whole"], again)

        # 4. a lane with no state of its own rides on a label; a real state is used when it exists
        today = next(c for c in fake.cards if c["title"] == "Call Ada about the roof")
        check("no Today state -> Todo + label", today["state"] == "Todo" and "Today" in today["labels"], today)
        check("source line in the description", "source: hodd/life/personal/me/todo.md · line" in today["description"])
        done = next(c for c in fake.cards if c["title"] == "Send the invoice")
        check("done lands in Done", done["state"] == "Done")
        real = FakeBoard(states=[{"name": n, "group": tb.LANE_GROUP[n]} for n in tb.LANES])
        st, is_real = tb.Board(cfg, call=real).state_for("This week")
        check("a real lane state is preferred", st == "This week" and is_real)

        # 5. owner: a known member is assigned; an unknown owner stays in the description, the card still lands
        r = tb.add({"title": "Owned by Ada", "owner": "Ada", "source": "test"}, board)
        check("owner assigned", fake.cards[-1].get("assignees") == ["ada"], fake.cards[-1])
        r = tb.add({"title": "Owned by a stranger", "owner": "Zed", "source": "test"}, board)
        check("unknown owner kept in text", r["verdict"] == "filed" and "owner: Zed" in fake.cards[-1]["description"]
              and "assignees" not in fake.cards[-1], fake.cards[-1])

        # 6. the board goes dark: the write is queued, never lost; flush sends it once
        fake.dark = True
        r = tb.add({"title": "Said while the board was dark", "source": "voice"}, board)
        check("dark board queues", r["verdict"] == "queued", r)
        n_before = len(fake.cards)
        fake.dark = False
        f = tb.flush(board)
        check("flush sends the queue", f["sent"] == 1 and f["left"] == 0 and len(fake.cards) == n_before + 1, f)
        f2 = tb.flush(board)
        check("flush twice sends nothing", f2["sent"] == 0 and len(fake.cards) == n_before + 1, f2)

        # 7. the same add twice (a retry) files one card
        a1 = tb.add({"title": "Retry me", "source": "voice"}, board)
        a2 = tb.add({"title": "Retry me", "source": "voice"}, board)
        check("retry is one card", a1["verdict"] == "filed" and a2["verdict"] == "exists" and a1["card"] == a2["card"])

        # 7b. a card deleted on the board is marked in the cache; the next add files it afresh
        tb._append(tb.cache_path(), {"key": a1["key"], "card": a1["card"], "deleted": True})
        a3 = tb.add({"title": "Retry me", "source": "voice"}, board)
        check("deleted card is filed afresh", a3["verdict"] == "filed" and a3["card"] != a1["card"], a3)

        # 8. a lane that does not exist is refused by name
        try:
            tb.add({"title": "bad", "lane": "Tomorrow"}, board)
            check("unknown lane refused", False)
        except tb.BoardError as exc:
            check("unknown lane refused", "Tomorrow" in str(exc))

    print(f"{'PASS' if not FAILS else 'FAIL'}: {len(FAILS)} failed")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
