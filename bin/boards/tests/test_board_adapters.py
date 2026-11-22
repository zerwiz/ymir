#!/usr/bin/env python3
"""test_board_adapters — the file, github and trello adapters answer the contract verbs the same way; the DONE date
of a closed plan; a Mermaid label with a line break is written in the quoted form. No network: the `gh` and REST
doors are fakes."""
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))
import board_adapters as ba  # noqa: E402

spec = importlib.util.spec_from_file_location("plan_sync", HERE / "plan_sync.py")
ps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ps)

fails = []


def check(name, ok, got=None):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f" — got {got!r}"))
    if not ok:
        fails.append(name)


def contract(label, b):
    """The same story on any board: create, list, update, close with a date, relate, link."""
    b.ensure_label("plan", dry=False)
    a = b.create_card("Plan 1 — one", "body [stamp: unstarted.aa]", "unstarted", ["plan"], start="2026-11-01",
                      priority="high", assignees=["ada"])["card"]
    c = b.create_card("Plan 2 — two", "other", "backlog", ["plan"])["card"]
    got = b.get_card(a)
    check(f"{label}: title, group, start, priority, stamp", (got["title"], got["group"], got["start"], got["priority"],
                                                            got["stamp"]) == ("Plan 1 — one", "unstarted", "2026-11-01",
                                                                              "high", "unstarted.aa"), got)
    check(f"{label}: list by label and find by title", len(b.list_cards("plan")) == 2 and
          [x["card"] for x in b.find_cards("plan", "two")] == [c])
    b.update_card(a, group="done", done="2026-11-20")
    got = b.get_card(a)
    check(f"{label}: closed card is in done and carries its DONE date", (got["group"], got["done"]) == ("done", "2026-11-20"),
          got)
    check(f"{label}: relations start empty and can be asked", b.can_relate() and b.relations(a) == set())
    b.add_relation(a, "blocked_by", c)
    b.add_relation(a, "blocked_by", c)
    check(f"{label}: a relation is kept once", b.relations(a) == {("blocked_by", str(c))}, b.relations(a))
    b.add_link(a, "https://example.org/p1", "Plan file")
    b.add_link(a, "https://example.org/p1", "Plan file")
    check(f"{label}: a link is kept once", [l["url"] for l in b.get_card(a)["links"]] == ["https://example.org/p1"])
    try:
        b.add_relation(a, "friends_with", c)
        check(f"{label}: an unknown relation is refused", False)
    except ba.AdapterRefusal:
        check(f"{label}: an unknown relation is refused", True)


# ── file ──
d = tempfile.mkdtemp()
fb = ba.FileBoard(d)
contract("file", fb)
check("file: BOARD.md is a readable table", "| # | Title | State |" in open(os.path.join(d, "BOARD.md")).read())
check("file: the description sits beside the table", "[stamp: unstarted.aa]" in open(os.path.join(d, ".board", "1.md")).read())
check("file: a second board object reads the same cards", len(ba.FileBoard(d).list_all()) == 2)
fb.create_card("A | pipe", "x", "unstarted", [])
check("file: a pipe in a title survives", any(c["title"] == "A | pipe" for c in ba.FileBoard(d).list_all()))
check("make_board picks file", os.path.normpath(ba.make_board({"adapter": "file", "place": "."}, d, d)[1].table) == os.path.join(d, "BOARD.md"))


# ── github, through a fake gh ──
class FakeGh:
    def __init__(self):
        self.issues, self.items, self.comments, self.labels, self.n = {}, {}, {}, set(), 0
        self.fields = {"fields": [
            {"name": "Status", "id": "F1", "options": [{"name": n, "id": "O" + n} for n in
                                                       ("Backlog", "Todo", "In Progress", "Done")]},
            {"name": "Start", "id": "F2"}, {"name": "Done", "id": "F3"},
            {"name": "Priority", "id": "F4", "options": [{"name": "high", "id": "Phigh"}, {"name": "low", "id": "Plow"}]}]}

    def __call__(self, a, stdin=None):
        k = " ".join(a[:2])
        if k == "project field-list":
            return self.fields
        if k == "project view":
            return {"id": "PID"}
        if k == "label list":
            return [{"name": l} for l in self.labels]
        if k == "label create":
            self.labels.add(a[2])
            return ""
        if k == "issue create":
            self.n += 1
            self.issues[self.n] = {"title": a[a.index("-t") + 1], "body": a[a.index("-b") + 1],
                                   "labels": [a[i + 1] for i, x in enumerate(a) if x == "-l"]}
            return f"https://github.com/o/r/issues/{self.n}"
        if k == "project item-add":
            n = int(a[a.index("--url") + 1].rsplit("/", 1)[1])
            self.items[n] = {"id": f"I{n}"}
            return {"id": f"I{n}"}
        if k == "project item-edit":
            n = int(a[a.index("--id") + 1][1:])
            fid = a[a.index("--field-id") + 1]
            it = self.items[n]
            if "--date" in a:
                it[{"F2": "start", "F3": "done"}[fid]] = a[a.index("--date") + 1]
            else:
                oid = a[a.index("--single-select-option-id") + 1]
                it["status" if fid == "F1" else "priority"] = oid[1:]
            return ""
        if k == "project item-list":
            out = []
            for n, it in self.items.items():
                iss = self.issues[n]
                out.append({"id": it["id"], "title": iss["title"], "labels": iss["labels"], "status": it.get("status"),
                            "start": it.get("start", ""), "done": it.get("done", ""), "priority": it.get("priority"),
                            "content": {"type": "Issue", "number": n, "body": iss["body"], "repository": "o/r"}})
            return {"items": out}
        if k == "issue edit":
            n = int(a[2])
            if "-b" in a:
                self.issues[n]["body"] = a[a.index("-b") + 1]
            if "-t" in a:
                self.issues[n]["title"] = a[a.index("-t") + 1]
            return ""
        if k in ("issue close", "issue reopen"):
            return ""
        if k == "issue comment":
            self.comments.setdefault(int(a[2]), []).append(a[a.index("-b") + 1])
            return ""
        if k == "issue view":
            return {"comments": [{"body": b} for b in self.comments.get(int(a[2]), [])]}
        raise AssertionError(f"unfaked gh call {a}")


gb = ba.GithubBoard("o/r", "o", 1, run=FakeGh())
contract("github", gb)
check("github: closing writes the comment 'closed YYYY-MM-DD'", "closed 2026-11-20" in gb.run.comments[1])
try:
    ba.make_board({"adapter": "github", "place": "o/r"}, "", "")
    check("make_board refuses a github block with no project", False)
except ba.AdapterRefusal:
    check("make_board refuses a github block with no project", True)


# ── trello, through a fake REST door ──
class FakeTrello:
    def __init__(self):
        self.cards, self.atts, self.labels, self.comments = {}, {}, {}, {}
        self.lists = [{"id": "L1", "name": "Backlog"}, {"id": "L2", "name": "To Do"}, {"id": "L3", "name": "Doing"},
                      {"id": "L4", "name": "Done"}]

    def __call__(self, method, url, headers, body=None):
        u = url.split("https://t.example/1", 1)[1]
        if u.startswith("/boards/B/lists"):
            return self.lists
        if u.startswith("/boards/B/labels"):
            return [{"id": i, "name": n} for n, i in self.labels.items()]
        if u.startswith("/boards/B/members"):
            return [{"id": "M1", "username": "ada", "fullName": "Ada"}]
        if u == "/labels":
            self.labels[body["name"]] = "lab" + str(len(self.labels))
            return {"id": self.labels[body["name"]]}
        if u.startswith("/boards/B/cards"):
            inv = {v: k for k, v in self.labels.items()}
            return [{**c, "labels": [{"name": inv[i]} for i in c.get("idLabels", "").split(",") if i],
                     "attachments": self.atts.get(c["id"], [])} for c in self.cards.values()]
        if method == "POST" and u == "/cards":
            n = len(self.cards) + 1
            self.cards[f"c{n}"] = {"id": f"c{n}", "idShort": n, "name": body["name"], "desc": body.get("desc", ""),
                                   "idList": body["idList"], "idLabels": body.get("idLabels", ""),
                                   "idMembers": body.get("idMembers", "").split(",") if body.get("idMembers") else [],
                                   "start": body.get("start"), "due": body.get("due"),
                                   "dueComplete": body.get("dueComplete", False), "shortUrl": f"https://trello.com/c/{n}"}
            return self.cards[f"c{n}"]
        if method == "PUT":
            c = self.cards[u.split("/")[2].split("?")[0]]
            c.update({k: v for k, v in body.items() if k not in ("name", "desc")})
            if "name" in body:
                c["name"] = body["name"]
            if "desc" in body:
                c["desc"] = body["desc"]
            return c
        if u.endswith("/attachments") and method == "POST":
            self.atts.setdefault(u.split("/")[2], []).append(body)
            return body
        if "/attachments" in u:
            return self.atts.get(u.split("/")[2], [])
        if u.endswith("/actions/comments"):
            self.comments.setdefault(u.split("/")[2], []).append(body["text"])
            return {}
        if "shortUrl" in u:
            return {"shortUrl": self.cards[u.split("/")[2].split("?")[0]]["shortUrl"]}
        raise AssertionError(f"unfaked trello call {method} {u}")


ft = FakeTrello()
tb = ba.TrelloBoard("B", http=ft, headers={}, base="https://t.example/1", people={"ada": "ada"})
contract("trello", tb)
check("trello: the done card is complete, with its due date", ft.cards["c1"]["dueComplete"] is True)
check("trello: closing writes the comment 'closed YYYY-MM-DD'", "closed 2026-11-20" in ft.comments["c1"])
check("trello: the owner is a member of the board", ft.cards["c1"]["idMembers"] == ["M1"])

# ── the DONE date, from the appended status ──
r = tempfile.mkdtemp()
env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.org", "GIT_COMMITTER_NAME": "t",
       "GIT_COMMITTER_EMAIL": "t@example.org", "HOME": r}


def git(*a, **e):
    subprocess.run(["git", "-C", r, *a], check=True, capture_output=True, env={**env, **e})


git("init", "-q")
f = os.path.join(r, "9-x.md")
open(f, "w").write("# 9 — x\n\n**Status:** open\n\nbody\n")
git("add", "9-x.md")
git("commit", "-qm", "a", GIT_AUTHOR_DATE="2026-11-01T10:00:00Z", GIT_COMMITTER_DATE="2026-11-01T10:00:00Z")
check("closed_date: an open plan with a status is dated by blame", ps.closed_date(f) == "2026-11-01", ps.closed_date(f))
open(f, "a").write("\n**Status:** done\n")
git("add", "9-x.md")
git("commit", "-qm", "b", GIT_AUTHOR_DATE="2026-11-15T10:00:00Z", GIT_COMMITTER_DATE="2026-11-15T10:00:00Z")
check("closed_date: the appended line's commit date", ps.closed_date(f) == "2026-11-15", ps.closed_date(f))
open(f, "a").write("\n**Status:** done 2026-11-18, built.\n")
check("closed_date: a date written in the line wins", ps.closed_date(f) == "2026-11-18", ps.closed_date(f))
open(os.path.join(r, "n.md"), "w").write("# n\nno status here\n")
check("closed_date: no status line, no invented date", ps.closed_date(os.path.join(r, "n.md")) is None)

# ── the diagram ──
src = ("```mermaid\nflowchart LR\n  S[(his sessions,<br/>on machines)] -->|nightly| HU[Huginn collects]\n"
       "  M[merged; the house<br/>(Gróa at night)]\n  VE{the Veil:<br>cited?}\n  A[\"ok<br/>x\"]\n```\n")
out = ps.fix_mermaid(src)
check("mermaid: a label with a line break is quoted", 'S[("his sessions,<br/>on machines")]' in out and
      'M["merged; the house<br/>(Gróa at night)"]' in out and 'VE{"the Veil:<br/>cited?"}' in out, out)
check("mermaid: a plain label and a quoted one are left alone", "HU[Huginn collects]" in out and 'A["ok<br/>x"]' in out)
check("mermaid: fixing twice changes nothing", ps.fix_mermaid(out) == out)
check("mermaid: text outside a block is untouched", ps.fix_mermaid("a [b: c]\n") == "a [b: c]\n")

print(f"{'FAIL' if fails else 'ok'}: {len(fails)} failed")
sys.exit(1 if fails else 0)
