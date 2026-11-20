"""plan-sync against a stub board: first run creates N cards, the second creates none, a status flip moves one."""
import json
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
                   and (not a.get("query") or a["query"] in c["title"])]
            return {"cards": [{k: c[k] for k in ("card", "title", "state", "labels")} for c in out]}
        if name == "get_card":
            return next(c for c in self.cards if str(c["card"]) == a["card"])
        if name == "create_card":
            self.seq += 1
            self.cards.append(dict(card=self.seq, title=a["title"], state=a["state"], labels=a["labels"],
                                   description=a["description"]))
            return {"card": self.seq}
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
            body = json.dumps({"jsonrpc": "2.0", "id": msg["id"], "result": {
                "content": [{"type": "text", "text": json.dumps(board.tool(p["name"], p["arguments"]))}]}}).encode()
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
            open(os.path.join(led, f"{n:03d}-{name}.md"), "w").write(f"# Plan {n} — Title {name}\n\nprivate text\n")
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
        env = dict(os.environ, YMIR_HOME=self.home, PS_TOKEN="s3cret")
        r = subprocess.run([DOOR, "--project", "demo", *extra], capture_output=True, text=True, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("s3cret", r.stdout + r.stderr)
        return r.stdout

    def plan_cards(self):
        return {c["title"]: c for c in self.board.cards if "plan" in c["labels"]}

    def test_first_run_creates_second_creates_none_flip_moves_one(self):
        out = self.sync()
        self.assertIn("created=3 updated=0 unchanged=0", out)
        cards = self.plan_cards()
        self.assertEqual({t: c["state"] for t, c in cards.items()},
                         {"001 · Title one": "Icebox", "002 · Title two": "Doing", "003 · Title three": "Shipped"})
        desc = cards["001 · Title one"]["description"]
        self.assertIn("001-one.md", desc)
        self.assertNotIn("private text", desc)
        self.assertIn("plan", self.board.labels)
        self.assertEqual(len(self.board.cards), 5)  # the two strangers stand untouched

        self.assertIn("created=0 updated=0 unchanged=3", self.sync())

        self.write_readme({1: "opened", 2: "built", 3: "built (v0)"})
        self.assertIn("created=0 updated=1 unchanged=2", self.sync())
        self.assertEqual(self.plan_cards()["002 · Title two"]["state"], "Shipped")

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

    def test_a_missing_board_block_is_refused(self):
        p = os.path.join(self.home, "hodd", "identity", "projects.yaml")
        open(p, "w").write("projects:\n- id: demo\n  realm: acme\n")
        r = subprocess.run([DOOR, "--project", "demo"], capture_output=True, text=True,
                           env=dict(os.environ, YMIR_HOME=self.home))
        self.assertEqual(r.returncode, 1)
        self.assertIn("no board", r.stderr)


if __name__ == "__main__":
    unittest.main()
