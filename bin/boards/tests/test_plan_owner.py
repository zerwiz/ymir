#!/usr/bin/env python3
"""A new plan card is assigned to its owner, and plan numbers are taken after the board's highest (2026-11-22)."""
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import plan_sync  # noqa: E402

fails = 0


def check(name, cond):
    global fails
    print(("ok   " if cond else "FAIL ") + name)
    fails += 0 if cond else 1


home = tempfile.mkdtemp()
os.makedirs(os.path.join(home, "hodd", "identity"))
with open(os.path.join(home, "hodd", "identity", "operator.yaml"), "w") as f:
    f.write("name: Ada\nemail: ada@example.com\n")

check("the operator in the home is the default assignee", plan_sync.plan_assignees(home, {}) == ["ada@example.com"])
check("a row's board.assignee wins", plan_sync.plan_assignees(home, {"board": {"assignee": "grace@example.com"}}) == ["grace@example.com"])
check("a list of assignees is kept", plan_sync.plan_assignees(home, {"board": {"assignee": ["ada@example.com", "grace@example.com"]}}) == ["ada@example.com", "grace@example.com"])
empty = tempfile.mkdtemp()
check("no operator and no row: nobody is invented", plan_sync.plan_assignees(empty, {}) == [])


class FakeBoard:
    saturated = False

    def list_all(self):
        return [{"title": "012 · Twelve", "labels": ["plan"], "parent": None},
                {"title": "352 · Another seat's plan", "labels": ["plan"], "parent": None},
                {"title": "400 · a step", "labels": [], "parent": 7},
                {"title": "not a plan", "labels": [], "parent": None}]


plan_sync.build_board = lambda home, row: ("place", FakeBoard())
plan_sync.shelf_labels = lambda home: set()
check("the board's highest plan number is read, steps ignored", plan_sync.highest_on_board(home, {}) == 352)

f = os.path.join(home, "p.md")
with open(f, "w") as fh:
    fh.write("# Plan 1 - x\n**Status:** plan\n" + "line\n" * 60 + "## Closed 2026-11-22\n\n**Status:** done — every part merged\n")
check("a status appended later closes the plan", plan_sync.status_group(plan_sync.header_status(f)) == "done")

print(("ok" if not fails else "FAIL") + f": {fails} failed")
sys.exit(1 if fails else 0)
