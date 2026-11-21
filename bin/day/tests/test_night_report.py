#!/usr/bin/env python3
"""test_night_report — the night report on a fixture home (no network, no ssh, no board, no send).

Proves: done, not done, merged and waiting are counted right; his to-do is read from the board door
(a fixture stands in for bin/records/todo.sh) and a proven card is closed with `move <card> Done`;
the retired file is never written, not even when it is the fallback; a card whose PR merged before it
was written, or whose subject names several PRs, is not closed; an empty night says so in one line;
a written run appends a second section, never replaces.

Run: python3 bin/day/tests/test_night_report.py
"""
from __future__ import annotations

import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
import night_report as nr  # noqa: E402

NOW = dt.datetime(2026, 12, 2, 6, 30).astimezone().timestamp()
SINCE = dt.datetime(2026, 12, 1, 22, 0).astimezone().timestamp()

TODO_MD = """# A day — invented for the test

# His half — what only he can do

## Today

- [ ] **Merge PR #41 (the roof door)** — the gate was green. *(priority high)*
      A second line that belongs to it.
- [ ] **Triage Ada's PRs #50/#51** — two of the faults are ours.
- [ ] **Main is red on `roof-test`** — *Unblocks:* every PR's gate, #41 first.
- [ ] **Answer Ada about the shed** — no PR, no errand; it waits on him.

## Set at his word, 2026-11-30 — older things

- [ ] **Finish `paint-shed`** — the errand that paints it.
- [ ] **Decide PR 7** — an old number. 2026-11-30
- [x] **Send the invoice** — done already.

## Held, deliberately

- [ ] **The boat** — held until spring.

# The house-kept half — what his messages moved

- [ ] **Read the roof letter** — kept by the house.
"""

# the same list as the board holds it after the migration: titles lost their bold and backticks
CARDS = {"place": "home", "count": 9, "shown": 9, "cards": [
    {"card": 1, "title": "Merge PR #41 (the roof door)", "state": "Todo", "labels": ["Today", "his"]},
    {"card": 2, "title": "Triage Ada's PRs #50/#51", "state": "Todo", "labels": ["Today", "his"]},
    {"card": 3, "title": "Main is red on roof-test", "state": "Todo", "labels": ["Today", "his"]},
    {"card": 4, "title": "Answer Ada about the shed", "state": "Todo", "labels": ["Today", "his"]},
    {"card": 5, "title": "Finish paint-shed", "state": "Todo", "labels": ["Inbox", "his"]},
    {"card": 6, "title": "Decide PR 7", "state": "Todo", "labels": ["Inbox", "his"],
     "description": "- [ ] **Decide PR 7** — an old number.\n\nsource: todo.md · Set at his word, 2026-11-30"},
    {"card": 7, "title": "Send the invoice", "state": "Done", "labels": ["his"]},
    {"card": 8, "title": "The boat", "state": "Backlog", "labels": ["Someday", "his"]},
    {"card": 9, "title": "Read the roof letter", "state": "Todo", "labels": ["Inbox", "house-kept"]},
]}

FIXTURE = {
    "repos": {
        "example/house": {
            "merged": [
                {"number": 41, "title": "the roof door", "url": "https://github.com/example/house/pull/41",
                 "mergedAt": "2026-12-01T23:30:00Z"},
                {"number": 3, "title": "before the window", "url": "https://github.com/example/house/pull/3",
                 "mergedAt": "2026-11-29T10:00:00Z"},
            ],
            "open": [
                {"number": 42, "title": "red one", "url": "https://github.com/example/house/pull/42",
                 "statusCheckRollup": [{"name": "gates", "conclusion": "FAILURE"}]},
                {"number": 43, "title": "green one", "url": "https://github.com/example/house/pull/43",
                 "reviewDecision": "APPROVED", "statusCheckRollup": [{"name": "gates", "conclusion": "SUCCESS"}]},
                {"number": 44, "title": "draft one", "url": "https://github.com/example/house/pull/44",
                 "isDraft": True},
            ],
        }
    },
    "pr_state": {
        "example/house#41": {"state": "MERGED", "mergedAt": "2026-12-01T23:30:00Z"},
        "example/house#50": {"state": "MERGED", "mergedAt": "2026-12-01T23:30:00Z"},
        "example/house#51": {"state": "MERGED", "mergedAt": "2026-12-01T23:30:00Z"},
        "example/house#7": {"state": "MERGED", "mergedAt": "2026-10-01T10:00:00Z"},
        "example/house#99": {"state": "MERGED", "mergedAt": "2026-12-01T23:00:00Z"},
    },
}


def runes(rows):
    return "\n".join(json.dumps(r) for r in rows) + "\n"


class NightReport(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.home = Path(self.tmp.name)
        for d in ("state/eindri-reports", "life/personal/me", "hodd/memory/daily", "hodd/data"):
            (self.home / d).mkdir(parents=True)
        (self.home / "life/personal/me/todo.md").write_text(TODO_MD)
        self.fx = self.home / "gh.json"
        self.fx.write_text(json.dumps(FIXTURE))
        self.board = self.home / "board.json"
        self.board.write_text(json.dumps(CARDS))
        os.environ["YMIR_NIGHT_MACHINE"] = "host-a"

    def tearDown(self):
        self.tmp.cleanup()

    def status(self, eid, text, at):
        p = self.home / "state" / f"{eid}.status"
        p.write_text(text)
        os.utime(p, (at, at))

    def night(self):
        self.status("paint-shed", "working: launched\ndone: painted; opened PR https://github.com/example/house/pull/99\n",
                    NOW - 3600)
        self.status("fix-roof", "working: seated\nfailed: the ladder was missing\n", NOW - 3000)
        self.status("ask-ada", "working: seated\nneeds-decision: blue or red?\n", NOW - 2000)
        self.status("slow-one", "working: seated, still going\n", NOW - 5 * 3600)
        self.status("live-one", "working: seated, still going\n", NOW - 600)
        self.status("old-one", "done: long ago\n", SINCE - 86400)
        (self.home / "hodd/memory/runes_audit.md").write_text(runes([
            {"timestamp": "2026-12-01T23:10:00Z", "actor": "garmr", "event": "notify",
             "message": "[host-a · garmr/HIGH] the disk is full"},
            {"timestamp": "2026-12-01T23:20:00Z", "actor": "eir", "event": "mend", "message": "eir mended disk"},
            {"timestamp": "2026-12-01T23:25:00Z", "actor": "cron", "event": "notify",
             "message": "[host-a · cron/INFO] a quiet line"},
            {"timestamp": "2026-11-01T23:25:00Z", "actor": "eir", "event": "mend", "message": "before the window"},
        ]))

    def run_main(self, *extra):
        argv = ["--home", str(self.home), "--since", str(SINCE), "--now", str(NOW), "--no-fleet", "--no-board",
                "--no-sync", "--no-send", "--github-fixture", str(self.fx), "--default-repo", "example/house",
                "--board-fixture", str(self.board),
                *extra]
        return nr.main(argv)

    def collect(self):
        class A:  # the parsed arguments collect() reads
            no_fleet = no_board = True
            no_github = False
            github_fixture = str(self.fx)
            board_fixture = str(self.board)
            default_repo = "example/house"
            repo = None
        return nr.collect(A, self.home, NOW, SINCE)

    def test_counts(self):
        self.night()
        data, _ = self.collect()
        by = {e["id"]: e for e in data["errands"]}
        self.assertEqual(sorted(by), ["ask-ada", "fix-roof", "live-one", "paint-shed", "slow-one"])  # old-one is outside
        self.assertEqual(by["paint-shed"]["outcome"], "done")
        self.assertEqual(by["paint-shed"]["pr"], "https://github.com/example/house/pull/99")
        self.assertEqual({k for k, e in by.items() if e["outcome"] == "not-done"}, {"fix-roof", "ask-ada", "slow-one"})
        self.assertEqual(by["slow-one"]["state"], "stuck")
        self.assertEqual(by["live-one"]["outcome"], "running")
        self.assertEqual([p["number"] for p in data["merged"]], [41])  # #3 merged before the window
        why = {p["number"]: p["why"] for p in data["open"]}
        self.assertEqual(why[42], "red gate: gates")
        self.assertEqual(why[43], "green and approved — ready to merge")
        self.assertEqual(why[44], "draft")
        self.assertEqual(len(data["rang"]), 1)
        self.assertEqual(len(data["mended"]), 1)
        # waiting: his half only, held excluded, oldest first (the dated section leads)
        texts = [t["text"] for t in data["his"]]
        self.assertIn("Decide PR 7", texts)
        self.assertFalse(any("boat" in t for t in texts))
        self.assertFalse(any("roof letter" in t for t in texts))
        self.assertEqual(data["needs"][0], "decide `ask-ada`: blue or red?")
        # a card proven done tonight is closed, so it no longer waits on him
        self.assertEqual(sorted(t["card"] for t, _ in data["ticks"]), [1, 5])
        self.assertFalse(any(t["text"].startswith(("Merge PR #41", "Finish paint-shed")) for t in data["his"]))
        self.assertEqual(data["todo_source"], "the to-do board")

    def test_proven_cards_close_through_the_door_and_the_file_is_never_written(self):
        self.night()
        before = (self.home / "life/personal/me/todo.md").read_text()
        self.assertEqual(self.run_main(), 0)
        board = json.loads(self.board.read_text())
        # PR #41 merged in the window; errand paint-shed is done and its PR #99 merged
        self.assertEqual(board["moves"], [[1, "Done"], [5, "Done"]])
        state = {c["card"]: c["state"] for c in board["cards"]}
        self.assertEqual(state[2], "Todo")  # two PRs in its subject
        self.assertEqual(state[3], "Todo")  # names no PR of its own
        self.assertEqual(state[6], "Todo")  # PR 7 merged before the card's item was written (its description)
        self.assertEqual(before, (self.home / "life/personal/me/todo.md").read_text())  # retired: never written
        report = (self.home / "hodd/docs/status/2026-12-02-night-report.md").read_text()
        self.assertIn("## Closed on your to-do (2)", report)
        self.assertIn("source: the to-do board, card #1", report)
        self.assertRegex(report, r"done: 2026-12-02 06:30 — example/house#41 merged 2026-12-01; ticked by the night report")
        # a second run closes nothing again, and the report gains a section instead of being replaced
        self.assertEqual(self.run_main(), 0)
        self.assertEqual(json.loads(self.board.read_text())["moves"], [[1, "Done"], [5, "Done"]])
        report = (self.home / "hodd/docs/status/2026-12-02-night-report.md").read_text()
        self.assertEqual(report.count("# Night report — 2026-12-02"), 1)
        self.assertIn("## A later run, 06:30", report)
        self.assertIn("night report written on host-a", (self.home / "hodd/memory/daily/2026-12-02.md").read_text())

    def test_no_board_reads_the_file_and_closes_nothing(self):
        self.night()
        self.board.write_text(json.dumps({"verdict": "skip", "why": "no board configured"}))
        before = (self.home / "life/personal/me/todo.md").read_text()
        data, _ = self.collect()
        self.assertEqual(data["ticks"], [])
        self.assertTrue(data["his"])  # he still sees what waits
        self.assertTrue(any("read from the file" in p and "not configured" in p for p in data["problems"]))
        self.assertEqual(self.run_main(), 0)
        self.assertEqual(before, (self.home / "life/personal/me/todo.md").read_text())

    def test_every_line_names_its_source(self):
        self.night()
        data, _ = self.collect()
        text = nr.build(data)
        for line in text.splitlines():
            if line.startswith("- ") and "## What could not be read" not in text.split(line)[0][-40:]:
                self.assertIn("source:", line, line)
        self.assertIn("## Errands done (1)", text)
        self.assertIn("## Errands not done (3)", text)
        self.assertIn("## PRs merged (1)", text)
        tg = nr.telegram_lines(data)
        self.assertEqual(len(tg), 6)
        self.assertEqual(tg[1], "Errands: 1 done · 3 not done · 1 running")

    def test_empty_night_says_so_in_one_line(self):
        (self.home / "hodd/memory/runes_audit.md").write_text("")
        self.fx.write_text(json.dumps({"repos": {"example/house": {"merged": [], "open": []}}, "pr_state": {}}))
        data, _ = self.collect()
        text = nr.build(data)
        quiet = [l for l in text.splitlines() if l.startswith("A quiet night")]
        self.assertEqual(len(quiet), 1)
        self.assertNotIn("## Errands", text)
        self.assertNotIn("## PRs merged", text)
        self.assertIn("A quiet night: nothing ran, nothing merged, nothing rang.", nr.telegram_lines(data))

    def test_dry_run_writes_nothing(self):
        self.night()
        before = self.board.read_text()
        self.assertEqual(self.run_main("--dry-run"), 0)
        self.assertEqual(before, self.board.read_text())  # no card moved
        self.assertFalse((self.home / "hodd/docs/status").exists())
        self.assertFalse((self.home / "state/night-report.last").exists())

    def test_silent_failures_are_named(self):
        """No default repository, and a PR whose state cannot be read, are named under problems."""
        self.night()

        class A:
            no_fleet = no_board = True
            no_github = False
            github_fixture = str(self.fx)
            board_fixture = str(self.board)
            default_repo = ""
            repo = None
        orig = nr.origin_repo
        nr.origin_repo = lambda: ""
        try:
            data, _ = nr.collect(A, self.home, NOW, SINCE)
        finally:
            nr.origin_repo = orig
        self.assertTrue(any(p.startswith("no default repository") for p in data["problems"]), data["problems"])
        self.assertNotIn(1, [t["card"] for t, _ in data["ticks"]])  # bare #41 cannot be told without a repo

        gh = nr.GitHub()
        gh._gh = lambda args, tries=3: (_ for _ in ()).throw(RuntimeError("network down"))
        self.assertIsNone(gh.state("example/house", 41))
        self.assertEqual(gh.unread, [("example/house#41", "network down")])

    def test_a_failed_ship_is_not_green(self):
        self.night()
        calls = []

        def fake_sh(args, timeout=300):
            calls.append(args)
            return (1, "push refused") if "ship" in args else (0, "")
        orig = nr.sh
        nr.sh = fake_sh
        try:
            argv = ["--home", str(self.home), "--since", str(SINCE), "--now", str(NOW), "--no-fleet",
                    "--no-board", "--github-fixture", str(self.fx), "--default-repo", "example/house",
                    "--board-fixture", str(self.board)]
            self.assertEqual(nr.main(argv), 1)
        finally:
            nr.sh = orig
        sent = next(c for c in calls if any("send.sh" in x for x in c))
        msg = sent[sent.index("--message") + 1]
        self.assertIn("NOT shipped, only on host-a", msg.splitlines()[0])

    def test_buttons_fit_and_render_unclipped(self):
        """Every prompt fits Telegram's 64 bytes, so the rendered callback_data IS the prompt."""
        btns = nr.buttons("2026-12-02")
        self.assertEqual(len(btns), 3)
        for b in btns:
            label, prompt = b.split("|", 1)
            self.assertLessEqual(len(prompt.encode()), nr.CALLBACK_MAX_BYTES, prompt)
            self.assertIn("2026-12-02 night report", prompt)
        tool = nr.ROOT / "bin/notify/telegram-buttons.sh"
        if not shutil.which("node"):
            self.skipTest("node is not on this seat: the render is not run")
        args = ["bash", str(tool), "emit", "--format", "reply-markup"]
        for b in btns:
            args += ["--button", b]
        p = subprocess.run(args, capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        markup = json.loads(p.stdout)
        got = [k["callback_data"] for row in markup["inline_keyboard"] for k in row]
        self.assertEqual(got, [b.split("|", 1)[1] for b in btns])


if __name__ == "__main__":
    unittest.main(verbosity=2)
