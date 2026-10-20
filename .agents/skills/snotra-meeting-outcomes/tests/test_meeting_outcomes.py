#!/usr/bin/env python3
"""Tests for the meeting-outcomes engine. Run: python3 tests/test_meeting_outcomes.py"""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
SKILL = HERE.parent
SCRIPT = SKILL / "scripts" / "meeting-outcomes.py"
FIXTURE = HERE / "fixtures" / "standup.txt"

spec = importlib.util.spec_from_file_location("meeting_outcomes", SCRIPT)
mo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mo)


def golden_record() -> dict:
    return {
        "meeting": {
            "meeting_id": "M-20261020",
            "title": "Standup",
            "started_at": "2026-10-20T09:00:00+03:00",
            "source": "manual",
            "classification": "internal",
        },
        "participants": [
            {"name": "Sam Okafor", "present": True},
            {"name": "Alex Rivera", "present": True},
        ],
        "decisions": [{
            "decision_id": "DEC-20261020-01",
            "statement": "Sign the agreement this week.",
            "decided_by": "Sam Okafor",
            "evidence": {"timestamp": "0:10", "quote": "We decided to sign the agreement this week."},
            "status": "decided",
        }],
        "actions": [{
            "action_id": "ACT-20261020-01",
            "verb": "send",
            "deliverable": "Send the capability matrix.",
            "owner": "Sam Okafor",
            "due_at": "2026-10-23",
            "date_unresolved": False,
            "evidence": {"timestamp": "0:20", "quote": "I will send the capability matrix by Friday."},
            "status": "accepted",
        }],
        "questions": [],
        "risks": [],
    }


class ParseTests(unittest.TestCase):
    def test_segments_and_speakers(self):
        raw = FIXTURE.read_text()
        segments = mo.parse_segments(raw)
        self.assertGreaterEqual(len(segments), 4)
        self.assertEqual(segments[0]["speaker"], "Alex Rivera")
        self.assertEqual(segments[0]["timestamp"], "0:10")
        speakers = mo.infer_participants(segments)
        self.assertEqual(len(speakers), 4)
        self.assertIn("Sam Okafor", speakers)
        self.assertNotIn("That is good.", speakers)

    def test_docx_reader_shape(self):
        # A docx is a zip with word/document.xml; the reader must not need python-docx.
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "m.docx"
            import zipfile
            with zipfile.ZipFile(path, "w") as z:
                z.writestr("word/document.xml",
                           "<w:document><w:body><w:p><w:r><w:t>Hello</w:t></w:r></w:p></w:body></w:document>")
            self.assertIn("Hello", mo.read_transcript(path))


class DateTests(unittest.TestCase):
    def setUp(self):
        self.base = date(2026, 10, 20)  # Tuesday

    def test_tomorrow(self):
        self.assertEqual(mo.resolve_date("I will do it tomorrow", self.base)[0], "2026-10-21")

    def test_next_week(self):
        self.assertEqual(mo.resolve_date("next week, same time", self.base)[0], "2026-10-26")

    def test_this_week(self):
        self.assertEqual(mo.resolve_date("we sign this week", self.base)[0], "2026-10-23")

    def test_weekday(self):
        self.assertEqual(mo.resolve_date("I will send it by Friday", self.base)[0], "2026-10-23")
        self.assertEqual(mo.resolve_date("on Thursday", self.base)[0], "2026-10-22")

    def test_explicit_day_month(self):
        self.assertEqual(mo.resolve_date("it ends 27th of November", self.base)[0], "2026-11-27")

    def test_iso(self):
        self.assertEqual(mo.resolve_date("due 2026-11-27", self.base)[0], "2026-11-27")

    def test_unresolved(self):
        self.assertEqual(mo.resolve_date("sometime soon", self.base)[0], None)


class ExtractionTests(unittest.TestCase):
    def setUp(self):
        segments = mo.parse_segments(FIXTURE.read_text())
        participants = [{"name": n} for n in mo.infer_participants(segments)]
        self.aliases = mo.build_aliases(participants)
        self.cands = mo.extract_candidates(segments, date(2026, 10, 20), self.aliases)

    def test_decision_found(self):
        statements = " ".join(d["statement"] for d in self.cands["decisions"]).lower()
        self.assertIn("sign the agreement", statements)

    def test_action_has_owner_and_due(self):
        sends = [a for a in self.cands["actions"] if "capability matrix" in a["deliverable"].lower()]
        self.assertTrue(sends)
        self.assertEqual(sends[0]["owner"], "Sam Okafor")
        self.assertEqual(sends[0]["due_at"], "2026-10-23")

    def test_action_has_evidence(self):
        for a in self.cands["actions"]:
            self.assertTrue(a["evidence"]["quote"])
            self.assertTrue(a["evidence"]["timestamp"])

    def test_negative_is_not_an_action(self):
        blob = " ".join(a["deliverable"].lower() for a in self.cands["actions"])
        self.assertNotIn("don't have to", blob)


class AliasTests(unittest.TestCase):
    def test_aliases_come_from_the_review_not_the_code(self):
        aliases = mo.build_aliases(
            [{"name": "Lena Fischer"}],
            {"Lena Fischer": ["Len", "L. Fischer"]},
        )
        self.assertEqual(aliases["Len"], "Lena Fischer")
        self.assertEqual(aliases["L. Fischer"], "Lena Fischer")
        self.assertEqual(aliases["Lena"], "Lena Fischer")


class ValidationTests(unittest.TestCase):
    def test_golden_passes(self):
        errors, _ = mo.validate_record(golden_record())
        self.assertEqual(errors, [])

    def test_missing_owner_fails(self):
        rec = golden_record()
        rec["actions"][0]["owner"] = "we"
        errors, _ = mo.validate_record(rec)
        self.assertTrue(any("owner" in e for e in errors))

    def test_missing_evidence_fails(self):
        rec = golden_record()
        rec["actions"][0]["evidence"] = {"timestamp": "", "quote": ""}
        errors, _ = mo.validate_record(rec)
        self.assertTrue(any("evidence" in e for e in errors))

    def test_null_due_needs_decide_by(self):
        rec = golden_record()
        rec["actions"][0]["due_at"] = None
        rec["actions"][0]["date_unresolved"] = True
        errors, _ = mo.validate_record(rec)
        self.assertTrue(any("decide_by" in e for e in errors))

    def test_done_needs_definition(self):
        rec = golden_record()
        rec["actions"][0]["status"] = "done"
        errors, _ = mo.validate_record(rec)
        self.assertTrue(any("definition_of_done" in e for e in errors))


class RenderTests(unittest.TestCase):
    def test_render_all(self):
        rec = golden_record()
        with tempfile.TemporaryDirectory() as tmp:
            written = mo.render_all(rec, Path(tmp))
            names = {p.name for p in written}
            self.assertIn("minutes.md", names)
            self.assertIn("actions.md", names)
            self.assertIn("decisions.md", names)
            self.assertIn("followup-email.md", names)
            minutes = (Path(tmp) / "minutes.md").read_text()
            self.assertIn("Sign the agreement this week.", minutes)
            self.assertIn("Sam Okafor", minutes)
            self.assertIn("0:10", minutes)
            brief = Path(tmp) / "briefs" / "sam-okafor.md"
            self.assertTrue(brief.exists())
            self.assertIn("Send the capability matrix.", brief.read_text())

    def test_cards_one_per_action(self):
        cards = mo.render_cards(golden_record())
        self.assertEqual(len(cards), 1)
        self.assertEqual(cards[0]["list"], "Inbox")
        self.assertEqual(cards[0]["members"], ["Sam Okafor"])

    def test_merge_curated_wins(self):
        review = {
            "meeting": {"meeting_id": "M", "title": "T", "started_at": "2026-10-20T09:00:00",
                        "source": "manual", "classification": "internal"},
            "participants": [{"name": "Sam Okafor", "present": True}],
            "decisions": [], "actions": [{
                "action_id": "ACT-20261020-01",
                "verb": "send", "deliverable": "Send the matrix.", "owner": "Sam Okafor",
                "due_at": "2026-10-23", "date_unresolved": False,
                "evidence": {"timestamp": "0:20", "quote": "I will send the matrix."},
                "status": "accepted",
            }],
        }
        rec = mo.merge_record({"actions": [], "decisions": []}, review, date(2026, 10, 20))
        self.assertEqual(len(rec["actions"]), 1)
        self.assertEqual(rec["actions"][0]["source"], "curated")


if __name__ == "__main__":
    unittest.main(verbosity=2)
