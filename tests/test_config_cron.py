#!/usr/bin/env python3
"""The proofs for the cron loader — a row the SCHEDULER reads must be a row the LOADER reads.

`src/ymir_runtime/config/load.py` parses the operator's `config/cron.yaml` into the document
`config/cron.schema.json` describes, and its refusal is the loud one: a line it cannot read is a
line it names. That makes a disagreement with `bin/time/nornir-cron-start.sh` a false alarm, and
richer still — the loader refused `@daily` and `@hourly` rows while the scheduler and the schema
both accepted them, so the same file was legal to the clock and illegal to the validator.

The DAY gate (`@heart Mon 09:15 …`, plan 305) is the newest shape, so what is proved here is that
the gates are found by what they ARE and not by where they sit:

  · `@heart Mon 09:15 cmd`        role first, day next, shape last
  · `Mon,Fri 09:15 @dev cmd`      a day list, no leading role gate
  · `09:15 @heart cmd`            the older shape-first form still parses
  · `@hourly:MM` / `@every:N`     the shapes the schedule genuinely uses
  · `Funday 09:15 cmd`            a day the calendar does not have is REFUSED by name
  · a row with no command         refused, because it is a job that would never run

    python3 tests/test_config_cron.py
"""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from ymir_runtime.config.load import _parse_cron  # noqa: E402
from ymir_runtime.config.schema import ConfigError  # noqa: E402


def parse(text: str) -> list[dict]:
    path = Path(tempfile.mkdtemp(prefix="cron-load-")) / "cron.yaml"
    path.write_text(text, encoding="utf-8")
    return _parse_cron(path)["jobs"]


class DayGate(unittest.TestCase):
    def test_a_weekly_row_parses_with_its_day_and_role(self):
        jobs = parse("@heart Mon 09:15 bin/mail/draft-age.sh --weekly\n")
        self.assertEqual(jobs, [{"time": "09:15", "command": "bin/mail/draft-age.sh --weekly",
                                 "day": ["Mon"], "roles": ["heart"]}])

    def test_a_day_list_before_an_ungated_shape(self):
        jobs = parse("Mon,Fri 09:15 @dev bin/x --flag\n")
        self.assertEqual(jobs[0]["day"], ["Mon", "Fri"])
        self.assertEqual(jobs[0]["roles"], ["dev"])
        self.assertEqual(jobs[0]["command"], "bin/x --flag")

    def test_the_older_shape_first_form_still_parses(self):
        jobs = parse("09:15 @heart bin/y\n")
        self.assertEqual(jobs, [{"time": "09:15", "command": "bin/y", "roles": ["heart"]}])


class Shapes(unittest.TestCase):
    def test_the_shapes_the_schedule_uses_all_parse(self):
        jobs = parse("@daily a\n@hourly b\n@hourly:20 c\n@every:5 d\n06:00 e\n")
        self.assertEqual([j["time"] for j in jobs], ["@daily", "@hourly", "@hourly:20", "@every:5", "06:00"])
        self.assertEqual([j["command"] for j in jobs], ["a", "b", "c", "d", "e"])
        self.assertTrue(all("roles" not in j for j in jobs), "@daily is a SHAPE, never a role gate")


class Refused(unittest.TestCase):
    def test_a_day_the_calendar_does_not_have_is_refused_by_name(self):
        with self.assertRaises(ConfigError) as caught:
            parse("Funday 09:15 x\n")
        self.assertIn("Funday", str(caught.exception))

    def test_a_row_with_no_command_is_refused(self):
        with self.assertRaises(ConfigError):
            parse("@heart Mon 09:15\n")

    def test_a_row_with_no_shape_is_refused(self):
        with self.assertRaises(ConfigError):
            parse("bin/mail/draft-age.sh --weekly\n")

    def test_a_bad_minute_is_refused(self):
        with self.assertRaises(ConfigError):
            parse("Mon 09:75 x\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
