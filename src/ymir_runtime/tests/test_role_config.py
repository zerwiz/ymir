"""role_config.py — the role lists, the first servable choice, and yolo made real (2026-11-21)."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from ymir_runtime import claude_seat, figure_card, harness, role_config
from ymir_runtime.role_config import Choice, Refused

TREE = Path(__file__).resolve().parents[3]


def write(dirpath: Path, name: str, text: str) -> None:
    (dirpath / name).write_text(text, encoding="utf-8")


class ListTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_the_first_choice_this_seat_can_serve_wins_and_skips_are_named(self) -> None:
        write(self.dir, "agents.yaml", "roles:\n  judge: [claude:opus, pi:local/model, pi:hosted/model]\n")
        cfg = role_config.load(self.dir)
        served = {"pi:hosted/model"}
        res = role_config.resolve(cfg, "judge", lambda c: (str(c) in served, "not served here"))
        self.assertEqual(res.choice, Choice("pi", "hosted/model"))
        self.assertEqual(res.index, 2)
        self.assertEqual([c for c, _ in res.skipped], ["claude:opus", "pi:local/model"])
        self.assertTrue(all(why == "not served here" for _, why in res.skipped))

    def test_a_list_with_nothing_servable_is_a_refusal_naming_every_choice(self) -> None:
        write(self.dir, "agents.yaml", "roles:\n  coder: [claude:sonnet, pi:a/b]\n")
        cfg = role_config.load(self.dir)
        with self.assertRaises(Refused) as ctx:
            role_config.resolve(cfg, "coder", lambda c: (False, "no"))
        self.assertIn("claude:sonnet", str(ctx.exception))
        self.assertIn("pi:a/b", str(ctx.exception))

    def test_a_role_the_home_does_not_declare_is_refused_by_name(self) -> None:
        write(self.dir, "agents.yaml", "roles:\n  judge: [claude:opus]\n")
        with self.assertRaises(Refused) as ctx:
            role_config.choices(role_config.load(self.dir), "scout")
        self.assertIn("scout", str(ctx.exception))

    def test_a_choice_without_a_harness_is_not_a_choice(self) -> None:
        for bad in ("opus", "gpt:model", "pi:", ":model"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                role_config.parse_choice(bad)

    def test_the_machine_overlay_replaces_a_role_and_leaves_the_others(self) -> None:
        write(self.dir, "agents.yaml", "roles:\n  judge: [claude:opus]\n  coder: [claude:sonnet]\n")
        write(self.dir, "agents.box.yaml", "roles:\n  coder: {choose: ['pi:llamacpp-box/m'], yolo: off}\n")
        cfg = role_config.load(self.dir, "box")
        self.assertEqual([str(c) for c in role_config.choices(cfg, "coder")], ["pi:llamacpp-box/m"])
        self.assertEqual([str(c) for c in role_config.choices(cfg, "judge")], ["claude:opus"])
        self.assertEqual(role_config.resolve_yolo(cfg, "coder")[0], False)


class YoloTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_the_house_default_is_on_for_the_coder_and_off_for_the_rest(self) -> None:
        cfg = role_config.load(self.dir)
        self.assertTrue(role_config.resolve_yolo(cfg, "coder")[0])
        for role in ("judge", "scout", "helm"):
            self.assertFalse(role_config.resolve_yolo(cfg, role)[0], role)

    def test_order_of_authority_flag_then_overlay_then_fleet_then_default(self) -> None:
        write(self.dir, "agents.yaml", "yolo: {default: on}\nroles:\n  coder: {choose: ['claude:sonnet'], yolo: off}\n")
        cfg = role_config.load(self.dir)
        self.assertEqual(role_config.resolve_yolo(cfg, "coder")[0], False)          # the role's row beats the house
        self.assertEqual(role_config.resolve_yolo(cfg, "coder", "on")[0], True)     # the flag beats the row
        self.assertEqual(role_config.resolve_yolo(cfg, "judge")[0], True)           # yolo.default reaches a role with none
        write(self.dir, "agents.box.yaml", "roles:\n  coder: {yolo: on}\n")
        cfg = role_config.load(self.dir, "box")
        self.assertEqual(role_config.resolve_yolo(cfg, "coder")[0], True)           # the overlay beats the fleet row

    def test_the_posture_line_says_which_mode_took_effect(self) -> None:
        self.assertIn("bypassPermissions", role_config.posture("claude", True))
        self.assertIn("dontAsk", role_config.posture("claude", False))
        self.assertIn("allow-all", role_config.posture("pi", False))
        self.assertIn("allow-all", role_config.posture("opencode", True))


class DenyStillBitesTest(unittest.TestCase):
    """yolo on removes the prompts, never the fence."""

    def test_the_claude_launch_line_carries_the_mode_of_the_posture(self) -> None:
        sel = harness.HarnessSelection(name="claude", model="sonnet", effort="", provenance="t", model_provenance="t") \
            if "model_provenance" in harness.HarnessSelection.__dataclass_fields__ else None
        if sel is None:
            self.skipTest("HarnessSelection shape differs")
        for yolo, mode in ((True, "bypassPermissions"), (False, "dontAsk")):
            line = harness.build_launch_command(sel, "/nonexistent/brief.md", launch_cwd=TREE, yolo=yolo)
            self.assertIn(f"--permission-mode {mode}", line)

    def test_every_deny_rule_survives_in_bypass_mode_and_the_mode_is_set(self) -> None:
        for role in ("coder", "forseti"):
            profile = claude_seat.profile_for(TREE, role)
            base = json.loads(profile.read_text())["permissions"]["deny"]
            for mode in ("dontAsk", "bypassPermissions"):
                with self.subTest(role=role, mode=mode):
                    merged = claude_seat.settings(profile, TREE, mode=mode)
                    self.assertEqual(merged["permissions"]["defaultMode"], mode)
                    self.assertEqual(merged["permissions"]["deny"], base)
                    self.assertTrue(base, "a profile with no deny list fences nothing")

    def test_the_worker_profile_still_denies_a_merge_and_a_push_to_main(self) -> None:
        deny = " ".join(json.loads(claude_seat.profile_for(TREE, "coder").read_text())["permissions"]["deny"])
        for needle in ("pr merge", "git push origin main", "GITHUB_TOKEN"):
            self.assertIn(needle, deny)


class FigureCardTest(unittest.TestCase):
    def test_every_role_has_a_card_that_opens_the_prompt(self) -> None:
        for role, figure in figure_card.ROLE_FIGURE.items():
            with self.subTest(role=role):
                card = figure_card.card_for(TREE, role)
                self.assertTrue(card.startswith(f"# Your card — {figure}"), card[:60])
                self.assertNotIn("permission:", card.split("\n---", 1)[0], "the YAML header is not the card")

    def test_a_figure_named_directly_wins_and_a_prompt_is_opened_once(self) -> None:
        self.assertEqual(figure_card.figure_of("forseti"), "forseti")
        self.assertEqual(figure_card.figure_of("judge"), "forseti")
        once = figure_card.with_card(TREE, "judge", "the brief")
        self.assertTrue(once.startswith("# Your card — forseti"))
        self.assertEqual(figure_card.with_card(TREE, "judge", once), once)

    def test_an_unknown_figure_adds_nothing(self) -> None:
        self.assertEqual(figure_card.with_card(TREE, "nobody-at-all", "the brief"), "the brief")
        self.assertEqual(figure_card.figure_of("../etc/passwd"), "")


if __name__ == "__main__":
    unittest.main()
