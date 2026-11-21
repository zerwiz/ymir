"""plan-sync against a stub board: whole cards with their phases as sub-items; a second run changes nothing,
a status flip moves one, a short card of the first pass is upgraded in place, and a board that cannot page is refused."""
import json
import re
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DOOR = os.path.join(ROOT, "bin", "boards", "plan-sync.sh")


class Board:
    """A fake board place: cards, labels, and the calls it was given."""

    def __init__(self):
        self.cards, self.labels, self.calls, self.seq = [], [], [], 0
        self.agents = []
        self.pages = True  # the board answers `offset` (the contract); False plays an older door
        self.blink = set()  # cards a full listing misses while the door reloads; a search by name still finds them

    def schemas(self):
        props = {"list_cards": ["place", "label", "state", "query", "limit"] + (["offset"] if self.pages else []),
                 "create_card": ["place", "title", "description", "state", "labels", "parent", "source",
                                 "description_format"],
                 "update_card": ["place", "card", "title", "description", "state", "description_format"]}
        return [{"name": k, "inputSchema": {"properties": {p: {} for p in v}}} for k, v in props.items()]

    @staticmethod
    def stamp(c):
        m = re.findall(r"\[stamp: ([^\]\s]+)\]", c.get("description") or "")
        return m[-1] if m else None

    def tool(self, name, a):
        self.calls.append(name)
        if name == "list_states":
            return {"states": [{"name": "Icebox", "group": "backlog"}, {"name": "Next", "group": "unstarted"},
                               {"name": "Doing", "group": "started"}, {"name": "Shipped", "group": "completed"},
                               {"name": "Dropped", "group": "cancelled"}]}
        if name == "list_labels":
            return {"labels": [{"name": x} for x in self.labels]}
        if name == "create_label":
            self.labels.append(a["name"])
            return {}
        if name == "list_cards":
            out = [c for c in self.cards if (not a.get("label") or a["label"] in c["labels"])
                   and (not a.get("state") or a["state"] == c["state"])
                   and (not a.get("query") or a["query"] in c["title"])
                   and (a.get("query") or c["card"] not in self.blink)]
            out.sort(key=lambda c: -c["card"])
            rows = [dict({k: c.get(k) for k in ("card", "title", "state", "labels", "parent")}, stamp=self.stamp(c))
                    for c in out]
            if not self.pages:
                return {"cards": rows[:100], "count": len(rows)}
            off, lim = int(a.get("offset") or 0), int(a.get("limit") or 50)
            return {"cards": rows[off:off + lim], "count": len(rows), "offset": off}
        if name == "get_card":
            c = next(c for c in self.cards if str(c["card"]) == a["card"])
            return dict(c, links=c.get("links", []), children=[
                {"card": k["card"], "title": k["title"], "stamp": self.stamp(k)} for k in self.cards
                if k.get("parent") == c["card"]])
        if name == "create_card":
            self.seq += 1
            self.cards.append(dict(card=self.seq, title=a["title"], state=a["state"], labels=a["labels"],
                                   description=a["description"], fmt=a.get("description_format"),
                                   parent=int(a["parent"]) if a.get("parent") else None, source=a.get("source")))
            return {"created": {"card": self.seq}}
        if name == "add_link":
            c = next(c for c in self.cards if str(c["card"]) == a["card"])
            c.setdefault("links", []).append({"url": a["url"], "title": a["title"]})
            return {}
        if name == "update_card":
            c = next(c for c in self.cards if str(c["card"]) == a["card"])
            for k in ("title", "state", "description"):
                if k in a:
                    c[k] = a[k]
            return {}
        raise AssertionError(name)


def serve(board):
    class H(BaseHTTPRequestHandler):
        def do_POST(self):
            msg = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            assert self.headers["Authorization"] == "Bearer s3cret"
            assert "ymir" in self.headers["User-Agent"]  # a Cloudflare 1010 means no User-Agent
            p = msg["params"]
            if msg["method"] == "tools/list":
                result = {"tools": board.schemas()}
            else:
                result = {"content": [{"type": "text", "text": json.dumps(board.tool(p["name"], p["arguments"]))}]}
            body = json.dumps({"jsonrpc": "2.0", "id": msg["id"], "result": result}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass

    srv = HTTPServer(("127.0.0.1", 0), H)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


class PlanSync(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = self.tmp.name
        self.board = Board()
        # a stranger's card, and a hand-made card with the number shape but no plan label: both must survive
        self.board.cards += [dict(card=90, title="Fix the lamp", state="Todo", labels=[], description=""),
                             dict(card=91, title="007 · not a plan card", state="Todo", labels=["idea"], description="")]
        self.board.seq = 91
        self.srv = serve(self.board)
        led = os.path.join(self.home, "svartalfaheim", "acme", "projects", "demo", "plans")
        os.makedirs(os.path.join(led, "old-plans"))
        self.led = led
        for n, name, st in ((1, "one", "opened"), (2, "two", "partial — audit"), (3, "three", "built (v0)")):
            open(os.path.join(led, f"{n:03d}-{name}.md"), "w").write(f"# Plan {n} — Title {name}\n\nthe plan's text\n")
        open(os.path.join(led, "001-one.md"), "a").write(
            "\n## The phases\n\n| # | Phase | Accept line |\n|---|---|---|\n| **0** | **Lay the floor** | it holds |\n"
            "| 1 | Raise the wall | `wall.sh` stands |\n\n```mermaid\nflowchart LR\n  A-->B\n```\n")
        open(os.path.join(led, "old-plans", "004-old.md"), "w").write("# 4 — Old\n")
        self.write_readme({1: "opened", 2: "partial — audit", 3: "built (v0)"})
        os.makedirs(os.path.join(self.home, "hodd", "identity"))
        open(os.path.join(self.home, "hodd", "identity", "projects.yaml"), "w").write(
            f"projects:\n- id: demo\n  name: Demo\n  realm: acme\n  board:\n    adapter: mcp\n    place: acme/Demo\n"
            f"    mcp:\n      url: http://127.0.0.1:{self.srv.server_port}/mcp\n      token_from: env:PS_TOKEN\n")

    def tearDown(self):
        self.srv.shutdown()
        self.tmp.cleanup()

    def write_readme(self, status):
        rows = "".join(f"| {n:03d} | [Title {nm}](00{n}-{nm}.md) | area | {status[n]} |\n"
                       for n, nm in ((1, "one"), (2, "two"), (3, "three")))
        open(os.path.join(self.led, "README.md"), "w").write("# Index\n\n" + rows)

    def sync(self, *extra):
        env = dict(os.environ, YMIR_HOME=self.home, PS_TOKEN="s3cret", YMIR_BOARD_PACE="0")
        r = subprocess.run([DOOR, "--project", "demo", *extra], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("s3cret", r.stdout + r.stderr)
        return r.stdout

    def plan_cards(self):
        return {c["title"]: c for c in self.board.cards if "plan" in c["labels"]}

    def test_first_run_makes_whole_cards_second_changes_nothing_flip_moves_one(self):
        out = self.sync()
        self.assertIn("created=3 upgraded=0 updated=0 unchanged=0 steps=2 found=0 failed=0", out)
        self.assertIn("count acme/Demo: ledger=3 plans · board=3 plan cards", out)
        cards = self.plan_cards()
        self.assertEqual({t: c["state"] for t, c in cards.items()},
                         {"001 · Title one": "Icebox", "002 · Title two": "Doing", "003 · Title three": "Shipped"})
        one = cards["001 · Title one"]
        self.assertTrue(one["description"].startswith("🔒 generated from the file — edit the file, not this card"))
        self.assertIn("the plan's text", one["description"])  # the whole plan rides on the card now
        self.assertIn("```mermaid", one["description"])
        self.assertEqual(one["fmt"], "markdown")
        self.assertIn("[stamp: backlog.", one["description"])
        steps = sorted((c["title"], c["description"].split("\n")[0]) for c in self.board.cards if c.get("parent") == one["card"])
        self.assertEqual(steps, [("1.0 · Lay the floor", "Done means: it holds"),
                                 ("1.1 · Raise the wall", "Done means: wall.sh stands")])
        self.assertIn("plan", self.board.labels)
        self.assertEqual(len(self.board.cards), 7)  # 3 plans + 2 steps + the two strangers, untouched

        before = len(self.board.calls)
        self.assertIn("created=0 upgraded=0 updated=0 unchanged=3 steps=0", self.sync())
        writes = [c for c in self.board.calls[before:] if c in ("create_card", "update_card", "add_link")]
        self.assertEqual(writes, [])

        self.write_readme({1: "opened", 2: "built", 3: "built (v0)"})
        self.assertIn("created=0 upgraded=0 updated=1 unchanged=2", self.sync())
        self.assertEqual(self.plan_cards()["002 · Title two"]["state"], "Shipped")

    def test_a_short_listing_never_doubles_a_card(self):
        # 2026-11-21: while the board's door reloaded, the listing came back short and two runs left four cards for
        # one plan. A plan the listing misses is asked for by name before it is made.
        self.sync()
        n = len(self.board.cards)
        self.board.blink = {c["card"] for c in self.board.cards}
        out = self.sync()
        self.assertIn("created=0", out)
        self.assertIn("found=3", out)
        self.assertEqual(len(self.board.cards), n)
        self.board.blink = set()
        self.assertIn("created=0 upgraded=0 updated=0 unchanged=3 steps=0", self.sync())

    def test_a_short_card_of_the_first_pass_is_upgraded_in_place(self):
        self.board.labels.append("plan")
        self.board.seq += 1
        self.board.cards.append(dict(card=self.board.seq, title="001 · Title one", state="Icebox", labels=["plan"],
                                     description="Plan 1. File: x\nplan-status: backlog (opened)\nMirrored by plan-sync"))
        out = self.sync("--plan", "1")
        self.assertIn("created=0 upgraded=1", out)
        cards = [c for c in self.board.cards if c["title"] == "001 · Title one"]
        self.assertEqual(len(cards), 1)  # the same card, never a second
        self.assertIn("the plan's text", cards[0]["description"])
        self.assertEqual(len([c for c in self.board.cards if c.get("parent") == cards[0]["card"]]), 2)
        self.assertIn("unchanged=1", self.sync("--plan", "1"))

    def test_a_file_names_its_own_project(self):
        env = dict(os.environ, YMIR_HOME=self.home, PS_TOKEN="s3cret", YMIR_BOARD_PACE="0")
        r = subprocess.run([DOOR, "--file", os.path.join(self.led, "003-three.md")], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("created=1", r.stdout)
        r = subprocess.run([DOOR, "--file", os.path.join(self.led, "003-three.md"), "--road"], capture_output=True,
                           text=True, env=dict(env, PS_TOKEN=""))
        self.assertEqual(r.returncode, 1)
        self.assertIn("no road to the board", r.stderr)

    def test_the_after_hook_names_its_road_or_its_absence(self):
        after = os.path.join(ROOT, "bin", "boards", "plan-card-after.sh")
        log = os.path.join(self.home, "sync.log")
        env = dict(os.environ, YMIR_HOME=self.home, PS_TOKEN="", YMIR_PLAN_CARD_LOG=log)
        plan = os.path.join(self.led, "002-two.md")
        r = subprocess.run([after, plan, "hodd/not-a-plan.md"], capture_output=True, text=True, env=env)
        self.assertIn("plan 2: no road to the board on this seat", r.stdout)  # never a silent skip
        stray = os.path.join(self.home, "elsewhere", "plans")
        os.makedirs(stray)
        open(os.path.join(stray, "005-lost.md"), "w").write("# 5 — Lost\n")
        r = subprocess.run([after, os.path.join(stray, "005-lost.md")], capture_output=True, text=True, env=env)
        self.assertIn("no project with a board", r.stdout)
        r = subprocess.run([after, plan], capture_output=True, text=True, env=dict(env, YMIR_PLAN_CARD="0"))
        self.assertIn("off on this seat", r.stdout)
        r = subprocess.run([after, plan], capture_output=True, text=True,
                           env=dict(env, PS_TOKEN="s3cret", YMIR_BOARD_PACE="0"))
        self.assertIn("plan 2 → acme/Demo: syncing in the background", r.stdout)
        import time
        for _ in range(50):
            if any(c["title"] == "002 · Title two" for c in self.board.cards):
                break
            time.sleep(0.2)
        self.assertTrue(any(c["title"] == "002 · Title two" for c in self.board.cards))

    def test_a_card_moved_by_hand_stays_until_the_ledger_changes(self):
        self.sync()
        self.plan_cards()["001 · Title one"]["state"] = "Next"  # the board moved it
        self.assertIn("updated=0 unchanged=3", self.sync())
        self.assertEqual(self.plan_cards()["001 · Title one"]["state"], "Next")

    def test_dry_run_writes_nothing_and_old_plans_are_left_out(self):
        out = self.sync("--dry-run")
        self.assertIn("created=3", out)
        self.assertEqual(len(self.board.cards), 2)
        self.assertNotIn("create_card", self.board.calls)
        self.assertNotIn("Old", out)

    def test_a_board_that_cannot_page_is_refused_a_write(self):
        self.board.pages = False  # an older door: it shows a window, and says nothing of what lies past it
        env = dict(os.environ, YMIR_HOME=self.home, PS_TOKEN="s3cret")
        r = subprocess.run([DOOR, "--project", "demo"], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 1)
        self.assertIn("older cards may be hidden", r.stderr)
        self.assertNotIn("create_card", self.board.calls)

    def test_a_missing_board_block_is_refused(self):
        p = os.path.join(self.home, "hodd", "identity", "projects.yaml")
        open(p, "w").write("projects:\n- id: demo\n  realm: acme\n")
        r = subprocess.run([DOOR, "--project", "demo"], capture_output=True, text=True,
                           env=dict(os.environ, YMIR_HOME=self.home))
        self.assertEqual(r.returncode, 1)
        self.assertIn("no board", r.stderr)


if __name__ == "__main__":
    unittest.main()
