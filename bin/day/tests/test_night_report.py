#!/usr/bin/env python3
"""test_night_report — the night report on a fixture home (no network, no ssh, no board, no send).

Proves: done, not done, merged and waiting are counted right; a ticked item is appended to, never
rewritten; an item whose PR merged before it was written, or whose subject names several PRs, is not
ticked; an empty night says so in one line; a written run appends a second section, never replaces.

Run: python3 bin/day/tests/test_night_report.py
"""
from __future__ import annotations

import datetime as dt
import json
import os
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
                *extra]
        return nr.main(argv)

    def collect(self):
        class A:  # the parsed arguments collect() reads
            no_fleet = no_board = True
            no_github = False
            github_fixture = str(self.fx)
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
        self.assertTrue(texts[0].startswith("Decide PR 7"))
        self.assertFalse(any("boat" in t for t in texts))
        self.assertFalse(any("roof letter" in t for t in texts))
        self.assertEqual(data["needs"][0], "decide `ask-ada`: blue or red?")
        # an item proven done tonight is ticked, so it no longer waits on him
        self.assertEqual(len(data["ticks"]), 2)
        self.assertFalse(any(t["text"].startswith(("Merge PR #41", "Finish paint-shed")) for t in data["his"]))

    def test_ticks_are_appended_not_rewritten(self):
        self.night()
        before = (self.home / "life/personal/me/todo.md").read_text().splitlines()
        self.assertEqual(self.run_main(), 0)
        after = (self.home / "life/personal/me/todo.md").read_text().splitlines()
        self.assertEqual(len(before), len(after))
        changed = [(b, a) for b, a in zip(before, after) if b != a]
        ticked = {b for b, _ in changed if b.startswith("- [ ]")}
        # PR #41 merged in the window; errand paint-shed is done and its PR #99 merged
        self.assertIn("- [ ] **Merge PR #41 (the roof door)** — the gate was green. *(priority high)*", ticked)
        self.assertIn("- [ ] **Finish `paint-shed`** — the errand that paints it.", ticked)
        for b, a in changed:
            body = b[len("- [ ] "):] if b.startswith("- [ ] ") else b
            self.assertTrue(a.replace("- [x] ", "", 1).startswith(body), f"rewritten: {b!r} → {a!r}")
            if "(done:" in a:
                self.assertRegex(a, r"\(done: 2026-12-02 06:30 — .*ticked by the night report\)$")
        self.assertEqual(sum("(done: 2026-12-02" in a for _, a in changed), 2)
        # the multi-line item: the mark on its first line, the note on its last
        i = before.index("- [ ] **Merge PR #41 (the roof door)** — the gate was green. *(priority high)*")
        self.assertTrue(after[i].startswith("- [x] **Merge PR #41"))
        self.assertTrue(after[i + 1].endswith("example/house#41 merged 2026-12-01; ticked by the night report)"))
        text = "\n".join(after)
        self.assertIn("- [ ] **Triage Ada's PRs #50/#51**", text)  # two PRs in its subject
        self.assertIn("- [ ] **Main is red on `roof-test`**", text)  # #41 is only its reason
        self.assertIn("- [ ] **Decide PR 7**", text)  # merged before the item was written
        # a second run ticks nothing again, and the report gains a section instead of being replaced
        self.assertEqual(self.run_main(), 0)
        self.assertEqual(after, (self.home / "life/personal/me/todo.md").read_text().splitlines())
        report = (self.home / "hodd/docs/status/2026-12-02-night-report.md").read_text()
        self.assertEqual(report.count("# Night report — 2026-12-02"), 1)
        self.assertIn("## A later run, 06:30", report)
        self.assertIn("night report written on host-a", (self.home / "hodd/memory/daily/2026-12-02.md").read_text())

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
        before = (self.home / "life/personal/me/todo.md").read_text()
        self.assertEqual(self.run_main("--dry-run"), 0)
        self.assertEqual(before, (self.home / "life/personal/me/todo.md").read_text())
        self.assertFalse((self.home / "hodd/docs/status").exists())
        self.assertFalse((self.home / "state/night-report.last").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
