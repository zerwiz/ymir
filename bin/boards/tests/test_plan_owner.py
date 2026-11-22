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

# --- start date, backfill, topic labels (2026-11-22) ---
import subprocess
d = tempfile.mkdtemp()
fa = os.path.join(d, "1-a.md")
open(fa, "w").write("# Plan 1 - a\n\n**Opened 2026-03-04.**\n")
check("the Opened header gives the start date", plan_sync.opened_date(fa) == "2026-03-04")
fb = os.path.join(d, "2-b.md")
open(fb, "w").write("# Plan 2 - b\nOpened 2026-05-06\n")
check("a bare 'Opened DATE' line is read", plan_sync.opened_date(fb) == "2026-05-06")
fc = os.path.join(d, "3-c.md")
open(fc, "w").write("# Plan 3 - c\n")
env = dict(os.environ, GIT_AUTHOR_DATE="2026-01-02T10:00:00", GIT_COMMITTER_DATE="2026-01-02T10:00:00")
for c in (["init", "-q"], ["add", "3-c.md"], ["-c", "user.name=t", "-c", "user.email=t@example.com", "commit", "-q", "-m", "x"]):
    subprocess.run(["git", "-C", d] + c, env=env, capture_output=True)
check("no header: the date of the file's first commit", plan_sync.opened_date(fc) == "2026-01-02")

class Rec:
    def __init__(self): self.calls = []
    def update_card(self, num, **kw): self.calls.append((num, kw))
    def ensure_label(self, name, dry=False): return False

def sync_one(card, path, title="t"):
    b = Rec()
    s = plan_sync.Sync(home, {}, "place", b, False)
    s.topics = ({"security": ["secret"], "ui-ux": ["screen"]}, {})
    p = {"num": 1, "title": title, "rel": "r/1.md", "abs": path, "group": "unstarted", "status": "open"}
    plan_sync.plan_body = lambda p: ("x", False)
    plan_sync.card_markdown = lambda p, t, c: "x"
    plan_sync.read_phases = lambda t, h: []
    s.steps_whole = lambda *a: True
    s.steps = lambda *a, **k: None
    s.link = lambda *a, **k: None
    card.setdefault("title", plan_sync.card_title(p)); card.setdefault("group", "unstarted")
    card["stamp"] = f"unstarted.{plan_sync.short(plan_sync.card_title(p) + 'x')}"
    s.one(p, card, [])
    return b.calls

calls = sync_one({"card": 7, "start": "", "assignees": [], "labels": ["plan"]}, fa)
check("an empty start and no assignee are backfilled", calls and calls[0][1].get("start") == "2026-03-04" and calls[0][1].get("assignees") == ["ada@example.com"])
calls = sync_one({"card": 7, "start": "2025-12-01", "assignees": ["bob@example.com"], "labels": ["plan"]}, fa)
check("a start and assignees a person set are never overwritten", not any("start" in c[1] or "assignees" in c[1] for c in calls))

fl = os.path.join(d, "4-l.md")
open(fl, "w").write("# Plan 4 - screen secret\n\n**Labels:** Security, UI UX\n")
check("declared labels win over words", plan_sync.plan_labels(fl, "screen secret", ({"memory": ["screen"]}, {})) == ["security", "ui-ux"])
fi = os.path.join(d, "5-i.md")
open(fi, "w").write("# Plan 5\n\nThe secret store and a new screen.\n")
check("no declaration: labels inferred from words", plan_sync.plan_labels(fi, "Plan 5", ({"security": ["secret"], "ui-ux": ["screen"], "memory": ["well"]}, {})) == ["security", "ui-ux"])
fh = os.path.join(d, "6-h.md")
open(fh, "w").write("# Plan 6\n\nBelongs to utgard-studios.\n")
check("a House the plan names is a label", "utgard-studios" in plan_sync.plan_labels(fh, "Plan 6", ({}, {})))
calls = sync_one({"card": 8, "start": "2026-01-01", "assignees": ["x"], "labels": ["plan", "mine"]}, fi, "screen")
check("labels are added and a person's label is never removed", calls and calls[0][1]["labels"][:2] == ["plan", "mine"] and "ui-ux" in calls[0][1]["labels"])

# --- relations (2026-11-22) ---
fr = os.path.join(d, "7-r.md")
open(fr, "w").write("# Plan 7 - r\n\n**Parent:** plan 3\n**Blocked by:** plan 8\n**Stands on, and does not repeat:** plan 4 · 5 (2026-11-01)\nsupersedes plan 2\n\nSee hodd/docs/audits/x.md and docs/fixes/a/b.md; plan 6 is mentioned only.\n")
r = plan_sync.plan_relations(fr)
check("a declared parent is read", r["parent"] == 3)
check("stands-on, supersedes are related; dates are not numbers", sorted(r["related"]) == sorted([("relates_to", 4), ("relates_to", 5), ("duplicate", 2), ("blocked_by", 8)]))
check("documents named are collected", r["docs"] == ["hodd/docs/audits/x.md", "docs/fixes/a/b.md"])
fm = os.path.join(d, "8-m.md")
open(fm, "w").write("# Plan 8 - m\n\nThis follows plan 3 and extends nothing; compare plan 7.\n")
fpr = os.path.join(d, "10-p.md")
open(fpr, "w").write("# Plan 10\nStatus: open\nPriority: none\n\n## Later\nPriority: urgent\n")
check("a later Priority line wins", plan_sync.plan_priority(fpr, [], {}) == "urgent")
fp2 = os.path.join(d, "11-p.md")
open(fp2, "w").write("# Plan 11\nStatus: open\n")
check("no Priority: the home's topic default, else none",
      plan_sync.plan_priority(fp2, ["security"], {"security": "high"}) == "high" and plan_sync.plan_priority(fp2, ["docs"], {"security": "high"}) == "none")
calls = sync_one({"card": 9, "start": "2026-01-01", "assignees": ["x"], "labels": ["plan"], "priority": "low"}, fpr)
check("a priority a person set is never overwritten", not any("priority" in c[1] for c in calls))
calls = sync_one({"card": 9, "start": "2026-01-01", "assignees": ["x"], "labels": ["plan"], "priority": "none"}, fpr)
check("an unset priority is filled from the plan", calls and calls[0][1].get("priority") == "urgent")
check("a mention is never a parent", plan_sync.plan_relations(fm)["parent"] is None)
fe = os.path.join(d, "9-e.md")
open(fe, "w").write("# Plan 9\n\nStatus: open. Extends plan 3.\n")
check("'extends plan N' in the header is a parent", plan_sync.plan_relations(fe)["parent"] == 3)

class Rec2(Rec):
    def __init__(self): super().__init__(); self.links = []; self.added = []; self.rels = set(); self.relcalls = []
    def can_relate(self): return True
    def relations(self, n): return set(self.rels)
    def add_relation(self, n, kind, other): self.relcalls.append((kind, other)); self.rels.add((kind, str(other)))
    def get_card(self, n): return {"links": [{"url": u} for u in self.links]}
    def add_link(self, n, url, title): self.added.append(url); self.links.append(url)

def sync_rel(card, b):
    s = plan_sync.Sync(home, {"board": {"file_url": "https://x.example/{path}"}}, "place", b, False)
    s.cards = {3: 30, 4: 40, 5: 50, 2: 20, 8: 80}
    p7 = {"num": 7, "title": "r", "rel": "l/7-r.md", "abs": fr}
    s.byrel = {7: p7, 4: {"num": 4, "title": "four", "rel": "l/4.md"}, 5: {"num": 5, "title": "five", "rel": "l/5.md"}, 2: {"num": 2, "title": "two", "rel": "l/2.md"}, 8: {"num": 8, "title": "eight", "rel": "l/8.md"}}
    s.relate(p7, 70, card)
b = Rec2()
sync_rel({"card": 70, "parent": None}, b)
check("the parent is set on the declared plan's card", b.calls == [(70, {"parent": 30})])
n1 = len(b.added)
sync_rel({"card": 70, "parent": 30}, b)
check("document links and typed relations are not duplicated on a second sync",
      n1 == 2 and len(b.added) == n1 and len(b.relcalls) == 4 and len(set(b.relcalls)) == 4)
check("stands-on is relates_to, supersedes is duplicate, blocked-by is blocked_by",
      {("relates_to", 40), ("relates_to", 50), ("duplicate", 20), ("blocked_by", 80)} == set(b.relcalls))
b2 = Rec2()
sync_rel({"card": 70, "parent": 99}, b2)
check("a parent a person set is never replaced", b2.calls == [])

print(("ok" if not fails else "FAIL") + f": {fails} failed")
sys.exit(1 if fails else 0)
