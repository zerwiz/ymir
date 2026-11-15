#!/usr/bin/env python3
"""test_brief.py — Skírnir's DATABASE (plan 227 §S1.5): one dated briefing, four verbs, and the bound.

The acceptance line the plan sets:

  > He says *"update Skírnir's database"*, then asks *"what did we decide about the microphone"* — and
  > Skírnir answers with the plan number, the actual decision, and the date, without a document title
  > in sight.

So the tests are about SHAPE and BOUND, in that order: an answer that carries the date and a plan
number, and a refusal for anyone who is not the Allfather.

Run: python3 -m unittest discover -s systems/skirnir/services -p 'test_*.py'
"""
import io
import os
import re
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import assistant_brief as brief                                      # noqa: E402

BRIEFING = """<!-- briefing refresh 2026-11-09T05:40:00+0100 -->

# Briefing — 2026-11-09

stamp: 2026-11-09T05:40:00+0100 · window: 2026-11-02 → 2026-11-09 · tag: `assistant-briefing`

## What is in flight
- 1 errand(s) alive: `skirnir-mind` (w45:p1)

## What shipped this week
- #599 fix(voice,snotra,runtime): the microphone is never taken — merged 2026-11-09 · plan 224 (The session's ledger) — «the voice host refuses to take the mic from a live call»

## Decisions
- 2026-11-09 · plan 224 · the ear listens to the sink monitor only, never a microphone
"""


class Shelf(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {"YMIR_HOME": self.home.name})
        self.env.start()
        os.makedirs(os.path.join(self.home.name, "hodd", "memory", "assistant", "briefing"))
        with open(brief.briefing_path("2026-11-09"), "w") as fh:
            fh.write(BRIEFING)

    def tearDown(self):
        self.env.stop()
        self.home.cleanup()

    def run_verb(self, verb, arg=""):
        out = io.StringIO()
        try:
            with redirect_stdout(out):
                code = brief.main(["assistant-brief.sh", verb] + ([arg] if arg else []))
        except SystemExit as err:
            code = err.code
        return code, out.getvalue()


class TheAcceptance(Shelf):
    def test_a_decision_question_answers_with_the_plan_the_decision_and_the_date(self):
        with patch.object(brief, "well_recall", return_value=[]):
            code, out = self.run_verb("recall", "what did we decide about the microphone")
        self.assertEqual(code, 0)
        self.assertIn("2026-11-09", out, "the briefing's date must be cited")
        self.assertIn("plan 224", out, "the plan number must be cited")
        self.assertIn("microphone", out, "the decision itself must be there")
        self.assertNotIn("(no title)", out)

    def test_the_well_is_asked_first(self):
        asked = []

        def recall(question, tag="", k=3):
            asked.append(tag)
            return [{"score": 0.9, "source": "well", "store": "episodic",
                     "title": "Briefing 2026-11-09 — the house's state"}]

        with patch.object(brief, "well_recall", side_effect=recall):
            code, out = self.run_verb("recall", "what did we decide about the microphone")
        self.assertEqual(asked[0], brief.TAG, "the FIRST ask must carry the briefing's stable tag")
        self.assertIn("2026-11-09", out)

    def test_show_prints_the_briefing(self):
        code, out = self.run_verb("show")
        self.assertEqual(code, 0)
        self.assertIn("# Briefing — 2026-11-09", out)

    def test_status_says_what_is_known(self):
        with patch.object(brief, "run", return_value='"WARM",220,"online","true"'):
            code, out = self.run_verb("status")
        self.assertEqual(code, 0)
        self.assertIn("2026-11-09", out)
        self.assertIn("briefing_status[1]", out)


class StaleSaysSoOutLoud(unittest.TestCase):
    def test_an_empty_database_says_so(self):
        with tempfile.TemporaryDirectory() as home, \
                patch.dict(os.environ, {"YMIR_HOME": home}), \
                patch.object(brief, "run", return_value=""):
            out = io.StringIO()
            with redirect_stdout(out):
                brief.main(["assistant-brief.sh", "status"])
        text = out.getvalue()
        self.assertIn("no briefing yet", text)
        self.assertIn('"yes"', text, "an absent database is stale by definition")

    def test_an_old_briefing_is_named_stale(self):
        with tempfile.TemporaryDirectory() as home, \
                patch.dict(os.environ, {"YMIR_HOME": home}), \
                patch.object(brief, "run", return_value='"WARM",220,"online","true"'):
            os.makedirs(os.path.join(home, "hodd", "memory", "assistant", "briefing"))
            path = brief.briefing_path("2026-11-01")
            open(path, "w").write(BRIEFING)
            three_days = brief.time.time() - 3 * 86400
            os.utime(path, (three_days, three_days))
            out = io.StringIO()
            with redirect_stdout(out):
                brief.main(["assistant-brief.sh", "status"])
        text = out.getvalue()
        self.assertIn("STALE", text)
        self.assertIn("2026-11-01", text)


class TheBound(unittest.TestCase):
    """plan 227 §S1.5.4: the briefing is the house's internal state and never leaves for a colleague."""

    def test_a_collaborator_is_refused_and_told_why(self):
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {"YMIR_HOME": home}):
            for verb in (("refresh",), ("show",), ("status",), ("recall", "what did we decide")):
                out = io.StringIO()
                with redirect_stdout(out), self.assertRaises(SystemExit) as stop:
                    brief.main(["assistant-brief.sh", *verb, "--tier", "collaborator"])
                self.assertEqual(stop.exception.code, 3, verb)
                self.assertIn("does not", out.getvalue().lower(), verb)


class TheTextItCompiles(unittest.TestCase):
    """`render` — every line names a record, and nothing private is written into a briefing."""

    def test_a_merged_pr_is_traced_to_its_plan_and_its_decision(self):
        plans = {"ok": True, "shelf": "/ledger", "plans": {
            "224": {"number": "224", "file": "224-ledger.md", "title": "The session's ledger",
                    "status": "opened 2026-11-09",
                    "change_log": [{"date": "2026-11-09", "what": "the microphone fault", "raw": ""}],
                    "text": '| "S8" | the ear | MERGED #599 — refuses and names the holder |'}}}
        prs = {"ok": True, "why": "", "merged": [
            {"number": "599", "title": "fix(voice): the microphone is never taken", "date": "2026-11-09",
             "branch": "eindri/voice", "url": ""}], "open": []}
        errands = {"ok": True, "why": "", "alive": [], "unreadable": [], "dead": [], "total": 0}
        decisions = {"ok": True, "why": "", "daily": [], "plan": [], "days": []}
        runes = {"ok": False, "why": "none in the window", "rows": [], "path": "/runes"}
        text, counts = brief.render("2026-11-09", "stamp", "2026-11-02", plans, errands, prs,
                                    decisions, runes)
        self.assertIn("#599", text)
        self.assertIn("plan 224", text)
        self.assertIn("2026-11-09", text)
        self.assertIn("the ear", text, "the line that names the PR is quoted, not invented")
        self.assertEqual(counts["merged"], 1)

    def test_no_vault_or_nda_shelf_is_ever_read(self):
        source = open(os.path.abspath(brief.__file__), encoding="utf-8").read()
        for forbidden in ("hodd/secrets", "platform.env.age", "hodd/identity/confidential",
                          "svartalfaheim/example-realm", "svartalfaheim/example-client"):
            self.assertNotIn(forbidden, source,
                             f"the briefing door must not even name {forbidden}")

    def test_every_briefing_is_tagged_for_the_well(self):
        source = open(os.path.abspath(brief.__file__), encoding="utf-8").read()
        self.assertIn('TAG = "assistant-briefing"', source)
        self.assertRegex(source, r'"--tags", f"\{TAG\},briefing:\{day\},domain:skirnir"')
        self.assertIn('"--privacy", "internal"', source)


if __name__ == "__main__":
    unittest.main()
