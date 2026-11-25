#!/usr/bin/env python3
"""test_board_sync.py — the proofs for scripts/board_sync.py against a fake Plane served from memory.

  python3 bin/collab/tests/test_board_sync.py -v
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

KIT = Path(__file__).resolve().parents[1] / "kit"


class FakePlane(BaseHTTPRequestHandler):
    issues: list = []
    labels: list = []
    writes = 0
    other: list = []      # issues of the second project BETA
    comments: dict = {}   # issue id -> list of comments

    def log_message(self, *a):
        pass

    def _send(self, obj, code=200):
        raw = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        p = self.path.split("?")[0]
        if p.endswith("/members/"):
            return self._send([{"id": "u1", "email": "ada@example.org"}])
        if p.endswith("/states/"):
            grp = {"Cancelled": "cancelled", "Done": "completed"}
            return self._send({"results": [{"id": "s-" + n, "name": n, "group": grp.get(n, "")} for n in ("Backlog", "Todo", "In Progress", "Done", "Cancelled")]})
        if p.endswith("/labels/"):
            return self._send({"results": FakePlane.labels})
        if p.endswith("/comments/"):
            return self._send({"results": FakePlane.comments.get(p.split("/")[-3], [])})
        if p.endswith("/issues/"):
            return self._send({"results": FakePlane.other if "/p2/" in p else FakePlane.issues})
        if p.endswith("/projects/"):
            return self._send({"results": [{"id": "p1", "identifier": "ALPHA"}, {"id": "p2", "identifier": "BETA"}]})
        self._send({}, 404)

    def do_POST(self):
        b = self._body()
        FakePlane.writes += 1
        if self.path.endswith("/labels/"):
            lab = {"id": "l%d" % len(FakePlane.labels), "name": b["name"]}
            FakePlane.labels.append(lab)
            return self._send(lab)
        if self.path.endswith("/comments/"):
            FakePlane.comments.setdefault(self.path.split("/")[-3], []).append(b)
            return self._send(b)
        pool = FakePlane.other if "/p2/" in self.path else FakePlane.issues
        issue = {"id": ("o%d" if pool is FakePlane.other else "i%d") % len(pool), "sequence_id": len(pool) + 1, **b}
        pool.append(issue)
        self._send(issue)

    def do_PATCH(self):
        b = self._body()
        FakePlane.writes += 1
        iid = self.path.rstrip("/").split("/")[-1]
        for i in FakePlane.issues + FakePlane.other:
            if i["id"] == iid:
                i.update(b)
                return self._send(i)
        self._send({}, 404)


PLAN = """---
title: "The first plan"
id: "ALPHA-001"
product: "alpha"
type: "plan"
priority: "High"
status: "Proposed"
owner: "ada@example.org"
created: "2026-11-01"
updated: "2026-11-20"
---

# The first plan
"""

TICKET = """---
ticket: "ALPHA-001-T01"
plan: "ALPHA-001"
title: "Do the first thing"
product: "alpha"
status: "Open"
priority: "Medium"
created: "2026-11-02"
updated: "2026-11-02"
parent: "ALPHA-001"
---
"""


class BoardSync(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv = HTTPServer(("127.0.0.1", 0), FakePlane)
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()

    def setUp(self):
        FakePlane.issues, FakePlane.labels, FakePlane.writes = [], [], 0
        FakePlane.other, FakePlane.comments = [], {}
        self.repo = Path(tempfile.mkdtemp())
        (self.repo / "scripts").mkdir()
        for f in ("board_sync.py", "status.py"):
            shutil.copy(KIT / "scripts" / f, self.repo / "scripts" / f)
        (self.repo / "plans" / "tickets").mkdir(parents=True)
        (self.repo / "plans" / ".board.json").write_text(json.dumps(
            {"url": "http://127.0.0.1:%d" % self.srv.server_port, "workspace": "acme", "products": {"alpha": "ALPHA"}}))
        (self.repo / "plans" / "ALPHA-001-first.md").write_text(PLAN)
        (self.repo / "plans" / "tickets" / "ALPHA-001-T01-thing.md").write_text(TICKET)
        self.env = {**os.environ, "PLANE_API_TOKEN": "test"}

    def tearDown(self):
        shutil.rmtree(self.repo, ignore_errors=True)

    def run_sync(self, *args, env=None):
        return subprocess.run([sys.executable, "-I", str(self.repo / "scripts" / "board_sync.py"), *args],
                              capture_output=True, text=True, env=env or self.env)

    def test_dry_run_writes_nothing(self):
        r = self.run_sync()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(FakePlane.writes, 0)
        self.assertIn("2 to create", r.stdout)

    def test_apply_creates_cards_with_dates_and_parent(self):
        self.assertEqual(self.run_sync("--apply").returncode, 0)
        plan = next(i for i in FakePlane.issues if i["external_id"] == "plans/ALPHA-001-first.md")
        self.assertEqual(plan["state"], "s-Backlog")
        self.assertEqual(plan["priority"], "high")
        self.assertEqual(plan["assignees"], ["u1"])
        self.assertIn("2026-11-01", plan["description_html"])  # created
        ticket = next(i for i in FakePlane.issues if "tickets" in i["external_id"])
        self.assertEqual(ticket["parent"], plan["id"])

    def test_second_run_is_unchanged_and_a_rename_updates_in_place(self):
        self.run_sync("--apply")
        before = FakePlane.writes
        self.assertIn("2 unchanged", self.run_sync().stdout)
        (self.repo / "plans" / "ALPHA-001-first.md").write_text(PLAN.replace("The first plan", "The renamed plan", 1))
        self.assertIn("1 to update", self.run_sync().stdout)
        self.run_sync("--apply")
        self.assertEqual(len(FakePlane.issues), 2)  # renamed, not duplicated
        self.assertGreater(FakePlane.writes, before)

    def test_human_text_below_the_marker_is_kept(self):
        self.run_sync("--apply")
        plan = next(i for i in FakePlane.issues if i["external_id"] == "plans/ALPHA-001-first.md")
        plan["description_html"] += "<p>a note from a person</p>"
        (self.repo / "plans" / "ALPHA-001-first.md").write_text(PLAN.replace("2026-11-20", "2026-11-23"))
        self.run_sync("--apply")
        self.assertIn("a note from a person", plan["description_html"])
        self.assertIn("2026-11-23", plan["description_html"])

    def test_an_older_card_is_adopted_not_duplicated(self):
        FakePlane.issues.append({"id": "old1", "sequence_id": 7, "name": "ALPHA-001 — The first plan", "labels": []})
        self.assertIn("1 to create, 1 to update", self.run_sync().stdout)
        self.run_sync("--apply")
        self.assertEqual(len(FakePlane.issues), 2)
        self.assertEqual(FakePlane.issues[0]["external_id"], "plans/ALPHA-001-first.md")

    def test_move_copies_to_the_other_project_and_closes_the_original(self):
        shutil.copy(KIT / "scripts" / "board_move.py", self.repo / "scripts" / "board_move.py")
        self.run_sync("--apply")
        src = next(i for i in FakePlane.issues if i["external_id"] == "plans/ALPHA-001-first.md")
        FakePlane.comments[src["id"]] = [{"comment_html": "<p>hello</p>", "actor_detail": {"display_name": "ada"}}]
        run = lambda *a: subprocess.run([sys.executable, "-I", str(self.repo / "scripts" / "board_move.py"), *a],
                                        capture_output=True, text=True, env=self.env)
        dry = run("ALPHA-1", "--to", "BETA")
        self.assertEqual((dry.returncode, len(FakePlane.other)), (0, 0), dry.stderr)
        r = run("ALPHA-1", "--to", "BETA", "--apply")
        self.assertEqual(r.returncode, 0, r.stderr)
        new = FakePlane.other[0]
        self.assertEqual(new["name"], src["name"])
        self.assertEqual(new["external_id"], "plans/ALPHA-001-first.md")
        self.assertIn("Moved from ALPHA-1", new["description_html"])
        self.assertIn("hello", FakePlane.comments[new["id"]][0]["comment_html"])
        self.assertEqual(src["state"], "s-Cancelled")
        self.assertIsNone(src["external_id"])

    def test_no_token_is_refused(self):
        env = {k: v for k, v in os.environ.items() if k != "PLANE_API_TOKEN"}
        r = self.run_sync(env=env)
        self.assertEqual(r.returncode, 2)
        self.assertIn("PLANE_API_TOKEN", r.stderr)

    def test_unknown_product_is_a_warning_not_a_write(self):
        (self.repo / "plans" / "ALPHA-001-first.md").write_text(PLAN.replace('"alpha"', '"gamma"'))
        r = self.run_sync("--apply")
        self.assertIn("maps to no Plane project", r.stdout)


if __name__ == "__main__":
    unittest.main()
