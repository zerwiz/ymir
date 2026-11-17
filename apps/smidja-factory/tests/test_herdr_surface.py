"""The herdr surface and the memory bound — the parts that can be tested offline.

Three things here are worth a test, because each of them was WRONG at least once
while it was being built:

  1. `extract_envelope` — a pane renders; a JSON object pulled out of a render
     can arrive with a token split across a wrap, or surrounded by box borders.
  2. `budget` — the arithmetic that refuses a team, which must refuse with the
     number it would have needed and must never refuse on a clean machine.
  3. the seat name — the board matches a run's team to its panes by this string
     (`smj-<run8>-<agent>`), so a change to it silently empties the team strip.

Run:  uv run --with pydantic --with pyyaml --with rich --with python-dotenv \
        python -m unittest apps/smidja-factory/tests/test_herdr_surface.py -v
"""

import os
import sys
import unittest
from pathlib import Path

MODULES = Path(__file__).resolve().parents[2] / "smidja" / "smidja_modules"
sys.path.insert(0, str(MODULES.parent))

from smidja_modules import agent_herdr, budget                    # noqa: E402
from smidja_modules.data_types import AgentConfig, PiRequest, PromptEngineering, smidjaConfig, ConfigDefaults  # noqa: E402


class ExtractEnvelope(unittest.TestCase):
    def test_plain_json(self):
        text = 'Here is my report:\n{"status": "success", "summary": "done", "artifacts": []}'
        self.assertEqual(agent_herdr.extract_envelope(text),
                         '{"status": "success", "summary": "done", "artifacts": []}')

    def test_fenced_json(self):
        text = 'Work done.\n```json\n{"status": "success", "summary": "ok"}\n```\n'
        self.assertIn('"summary": "ok"', agent_herdr.extract_envelope(text))

    def test_a_token_split_across_a_wrap_still_parses(self):
        # A TUI wraps mid-token: the path below was rendered as "proo\nf1".
        text = '{"status": "success", "summary": "x",\n "artifacts": ["/tmp/proo\nf1/plan.md"]}'
        found = agent_herdr.extract_envelope(text)
        # The wrap is gone and the token is whole; the space before the comma is
        # the space that was there, which JSON does not care about.
        self.assertIn('/tmp/proof1/plan.md', found)
        self.assertNotIn('proo\n', found)

    def test_box_drawn_borders_are_ignored(self):
        text = "│ Report:  │\n│ {\"status\": \"success\", \"summary\": \"ok\"} │\n│ footer   │"
        self.assertIn('"status": "success"', agent_herdr.extract_envelope(text))

    def test_prose_is_not_an_envelope(self):
        self.assertEqual(agent_herdr.extract_envelope("I could not finish; no JSON here."), "")

    def test_the_last_object_wins(self):
        text = '{"status": "fail"}\n…after a correction…\n{"status": "success", "summary": "fixed"}'
        self.assertIn('"success"', agent_herdr.extract_envelope(text))


class Budget(unittest.TestCase):
    def _cfg(self, count: int, model: str = "opencode-go/deepseek-v4.1-flash"):
        agents = [
            AgentConfig(name=f"a{i}", model=model,
                        prompt_engineering=PromptEngineering(system="s", user="u"))
            for i in range(count)
        ]
        return smidjaConfig(defaults=ConfigDefaults(model=model), agents=agents)

    def test_a_small_team_fits_a_real_machine(self):
        verdict = budget.check(self._cfg(3))
        if not verdict["ram_mb"]:
            self.skipTest("this machine cannot report its memory")
        self.assertTrue(verdict["ok"], budget.refusal(verdict))

    def test_a_team_bigger_than_the_line_is_refused_with_the_number(self):
        # Force the line down to nothing, without touching the machine.
        old = budget.DESK_RESERVE_MB
        try:
            budget.DESK_RESERVE_MB = 10 ** 9
            verdict = budget.check(self._cfg(3))
            self.assertFalse(verdict["ok"])
            sentence = budget.refusal(verdict)
            self.assertIn("3 seats", sentence)
            self.assertIn("at most 0 seat(s)", sentence)
        finally:
            budget.DESK_RESERVE_MB = old

    def test_a_local_model_is_counted_once_not_per_seat(self):
        local = self._cfg(3, model="llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp")
        verdict = budget.seat_cost_mb(local)
        self.assertTrue(verdict["local"])
        self.assertEqual(verdict["local_resident_mb"], budget.LOCAL_RESIDENT_MB)
        self.assertEqual(verdict["needed_mb"],
                         3 * budget.SEAT_FLOOR_MB + budget.LOCAL_RESIDENT_MB)


class SeatName(unittest.TestCase):
    def test_the_seat_name_is_what_the_board_matches(self):
        request = PiRequest(
            prompt="x", system_prompt="y", model="m", session_id="s",
            session_dir="/tmp/run/planner/pi_sessions",
            raw_output_path="/tmp/run/planner/raw_output.jsonl",
            agent="planner", smidja_id="proof1234",
        )
        self.assertEqual(agent_herdr._seat_name(request), "smj-proof123-planner")

    def test_a_missing_agent_name_falls_back_to_the_directory(self):
        request = PiRequest(
            prompt="x", system_prompt="y", model="m", session_id="s",
            session_dir="/tmp/run/builder/pi_sessions",
            raw_output_path="/tmp/run/builder/raw_output.jsonl",
            smidja_id="abcdef12345",
        )
        self.assertEqual(agent_herdr._seat_name(request), "smj-abcdef12-builder")


class Footer(unittest.TestCase):
    def test_tokens_and_occupancy_are_read_from_the_footer(self):
        foot = agent_herdr.read_footer(
            "some output\n↑197k ↓130k R42M CH99.8% $0.233 31.4%/1.0M (auto)")
        self.assertEqual(foot["input_tokens"], 197_000)
        self.assertEqual(foot["output_tokens"], 130_000)
        self.assertAlmostEqual(foot["cost"], 0.233)
        self.assertEqual(foot["context_tokens"], 314_000)

    def test_no_footer_is_all_zeros_not_a_crash(self):
        self.assertEqual(agent_herdr.read_footer("nothing here")["context_tokens"], 0)


if __name__ == "__main__":
    unittest.main()
