"""heartbeat.py — the silence judgement, identical to the shell condition's."""

from __future__ import annotations

import os
import tempfile
import time
import unittest
from pathlib import Path

from ymir_runtime import heartbeat


class MetaTest(unittest.TestCase):
    def test_roundtrip_keeps_values_with_equals_and_spaces(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            heartbeat.write_meta(tmp, "s1", {"id": "s1", "note": "a=b and c"})
            meta = heartbeat.read_meta(tmp, "s1")
            self.assertEqual(meta["id"], "s1")
            self.assertEqual(meta["note"], "a=b and c")

    def test_absent_meta_reads_empty(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(heartbeat.read_meta(tmp, "nobody"), {})


class StatusLineTest(unittest.TestCase):
    def test_baseline_is_the_line_the_old_door_writes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            heartbeat.baseline(tmp, "s1", "2026-09-27T11:00:00Z")
            self.assertEqual(
                heartbeat.last_line(tmp, "s1"),
                "working: launched 2026-09-27T11:00:00Z (heartbeat baseline)",
            )

    def test_classify_maps_every_state_the_grammar_allows(self) -> None:
        cases = {
            "working: doing it": "working",
            "done: opened PR #1": "done",
            "failed: could not build": "failed",
            "blocked: waiting on a key": "blocked",
            "needs-decision: which door?": "blocked",
            "paused: waiting out a rate limit": "blocked",
            "": "",
            "something else": "",
        }
        for line, expected in cases.items():
            self.assertEqual(heartbeat.classify(line), expected, line)


class VerdictTest(unittest.TestCase):
    def _launched(self, tmp: str, seat: str, *, age: int) -> None:
        heartbeat.write_meta(tmp, seat, {"launched": str(int(time.time()) - age)})
        path = heartbeat.append(tmp, seat, "working: busy")
        stamp = time.time() - age
        os.utime(path, (stamp, stamp))

    def test_absent_when_no_launch_record_exists(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(heartbeat.verdict(tmp, "ghost"), "absent")

    def test_terminal_on_a_done_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            heartbeat.write_meta(tmp, "s1", {"launched": str(int(time.time()))})
            heartbeat.append(tmp, "s1", "done: opened PR")
            self.assertEqual(heartbeat.verdict(tmp, "s1"), "terminal")

    def test_terminal_on_a_failed_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            heartbeat.write_meta(tmp, "s1", {"launched": str(int(time.time()))})
            heartbeat.append(tmp, "s1", "failed: died loudly")
            self.assertEqual(heartbeat.verdict(tmp, "s1"), "terminal")

    def test_terminal_on_a_filed_report_even_with_no_terminal_line(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self._launched(tmp, "s1", age=5)
            reports = Path(tmp) / "eindri-reports"
            reports.mkdir()
            (reports / "s1.md").write_text("the report\n", encoding="utf-8")
            self.assertEqual(heartbeat.verdict(tmp, "s1"), "terminal")

    def test_fresh_inside_the_window(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self._launched(tmp, "s1", age=5)
            self.assertEqual(heartbeat.verdict(tmp, "s1", window=1800), "fresh")

    def test_silent_outside_the_window(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            self._launched(tmp, "s1", age=4000)
            self.assertEqual(heartbeat.verdict(tmp, "s1", window=1800), "silent")

    def test_silent_when_no_status_file_was_ever_written(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            heartbeat.write_meta(tmp, "s1", {"launched": str(int(time.time()) - 4000)})
            self.assertEqual(heartbeat.verdict(tmp, "s1", window=1800), "silent")

    def test_age_is_exact_against_a_supplied_clock(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = heartbeat.append(tmp, "s1", "working: busy")
            stamp = time.time() - 42
            os.utime(path, (stamp, stamp))
            self.assertEqual(heartbeat.age(tmp, "s1", now=stamp + 42), 42)
            self.assertIsNone(heartbeat.age(tmp, "ghost"))

    def test_iso_is_the_fleet_timestamp_shape(self) -> None:
        self.assertEqual(heartbeat.iso(0), "1970-01-01T00:00:00Z")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
