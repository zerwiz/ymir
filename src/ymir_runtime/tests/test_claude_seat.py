"""claude_seat.py — a Claude worker starts with no human click (2026-11-20)."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from ymir_runtime import claude_seat, harness


class TrustTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.home = Path(self._tmp.name).resolve()
        self.env = {"HOME": str(self.home)}
        self.cfg = self.home / ".claude.json"
        self.cfg.write_text(json.dumps({"theme": "dark", "projects": {"/elsewhere": {"hasTrustDialogAccepted": True, "x": 1}}}))
        self.seat = self.home / "proj" / ".yggdrasil" / "errand"
        self.seat.mkdir(parents=True)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_marks_the_seat_and_keeps_every_other_key(self) -> None:
        self.assertEqual(claude_seat.trust(self.seat, self.env), "marked")
        data = json.loads(self.cfg.read_text())
        self.assertTrue(data["projects"][str(self.seat)]["hasTrustDialogAccepted"])
        self.assertEqual(data["theme"], "dark")
        self.assertEqual(data["projects"]["/elsewhere"], {"hasTrustDialogAccepted": True, "x": 1})
        self.assertEqual(claude_seat.trust(self.seat, self.env), "already")

    def test_never_trusts_the_home_or_above(self) -> None:
        for folder in (self.home, Path("/"), self.home.parent):
            with self.subTest(folder=folder), self.assertRaises(ValueError):
                claude_seat.trust(folder, self.env)
        self.assertNotIn(str(self.home), json.loads(self.cfg.read_text())["projects"])

    def test_refuses_a_relative_or_missing_folder(self) -> None:
        with self.assertRaises(ValueError):
            claude_seat.trust("proj", self.env)
        with self.assertRaises(ValueError):
            claude_seat.trust(self.home / "nope", self.env)


class SettingsTest(unittest.TestCase):
    def test_adds_one_allow_per_mcp_server_and_keeps_the_deny_list(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp).resolve()
            (home / ".claude.json").write_text(json.dumps({"mcpServers": {"ymir": {}, "well": {}}}))
            seat = home / "p"
            seat.mkdir()
            (seat / ".mcp.json").write_text(json.dumps({"mcpServers": {"gimle": {}}}))
            profile = harness.claude_worker_profile(None)
            data = claude_seat.settings(profile, seat, {"HOME": str(home)})
            allow, deny = data["permissions"]["allow"], data["permissions"]["deny"]
            for rule in ("mcp__ymir", "mcp__well", "mcp__gimle", "Bash", "Edit"):
                self.assertIn(rule, allow)
            self.assertIn("Bash(git push origin main:*)", deny)
            self.assertEqual(data["permissions"]["defaultMode"], "dontAsk")


class ClassifyTest(unittest.TestCase):
    def test_a_brief_that_quotes_the_faults_is_not_a_fault(self) -> None:
        brief = "> Fix it: Claude asks 'Yes, I trust this folder' and 'Yes, switch to Opus'\n  There's an issue with the selected model\n"
        self.assertEqual(claude_seat.classify(brief, "")[0], "empty")

    def test_the_trust_dialog(self) -> None:
        pane = " Do you trust the files in this folder?\n\n ❯ 1. Yes, I trust this folder\n   2. No, exit\n"
        self.assertEqual(claude_seat.classify(pane)[0], "trust")

    def test_a_switch_confirmation(self) -> None:
        pane = " Switch model?\n ❯ 1. Yes, switch to Opus\n   2. No\n"
        self.assertEqual(claude_seat.classify(pane)[0], "confirm")

    def test_a_permission_dialog(self) -> None:
        pane = " Bash command\n   rm x\n Do you want to proceed?\n ❯ 1. Yes\n   2. Yes, and don't ask again for rm\n   3. No\n"
        self.assertEqual(claude_seat.classify(pane)[0], "permission")

    def test_the_model_refusal(self) -> None:
        pane = "> do the errand\n⏺ There's an issue with the selected model (claude/claude-opus-5-5). Run /model to pick a different model.\n"
        self.assertEqual(claude_seat.classify(pane, "done")[0], "model")

    def test_a_working_seat(self) -> None:
        self.assertEqual(claude_seat.classify("⏺ Bash(git status)\n  ⎿ clean\n✻ Forging… (esc to interrupt)")[0], "ok")
        self.assertEqual(claude_seat.classify("", "working")[0], "ok")

    def test_an_empty_prompt(self) -> None:
        self.assertEqual(claude_seat.classify("╭──╮\n│ >  │\n╰──╯\n", "idle")[0], "empty")


class HarnessModelTest(unittest.TestCase):
    def test_a_claude_id_with_its_provider_is_normalised_not_refused(self) -> None:
        for spelling in ("claude/claude-opus-5-5", "anthropic/claude-opus-5-5", "claude-opus-5-5"):
            with self.subTest(spelling=spelling):
                selection = harness.resolve(harness="claude", model=spelling, catalog=lambda: [])
                self.assertEqual(selection.model, "claude-opus-5-5")
                self.assertEqual(selection.model_provenance, "explicit flag (--model)")


if __name__ == "__main__":
    unittest.main()
