"""allow.py — the operator's model allow-list, its grants, and the use log."""

from __future__ import annotations

import datetime as dt
import tempfile
import unittest
from pathlib import Path

from ymir_runtime import allow

LIST = """\
version: 1
allow:
  - opencode-go/deepseek-v4.1-flash
  - llama-swap/*
  - llamacpp-*/*
  - claude/claude-opus-5-5
defaults:
  claude: claude-opus-5-5
grants: []
"""

NOW = dt.datetime(2026, 11, 12, 12, 0, tzinfo=dt.timezone.utc)


class AllowTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        (root / "config").mkdir()
        (root / "state").mkdir()
        self.list = root / "config" / allow.FILENAME
        self.list.write_text(LIST, encoding="utf-8")
        self.env = {"YMIR_HOME": str(root), "YMIR_SETTINGS_DIR": str(root / "config"),
                    "YMIR_STATE_DIR": str(root / "state")}

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def check(self, model: str, harness: str = "pi", **kw) -> allow.Verdict:
        return allow.check(model, harness=harness, env=self.env, now=NOW, **kw)

    def grant(self, extra: str) -> None:
        self.list.write_text(LIST.replace("grants: []\n", "grants:\n" + extra), encoding="utf-8")

    # ── the list ──
    def test_flash_and_local_rail_are_allowed(self) -> None:
        for model in ("opencode-go/deepseek-v4.1-flash", "llama-swap/qwen3.6-35b-a3b@iq3_s", "llamacpp-whynot/q@q4"):
            self.assertEqual(self.check(model).verdict, "allowed", model)

    def test_pro_is_refused_with_the_remedy(self) -> None:
        verdict = self.check("opencode-go/deepseek-v4-pro")
        self.assertEqual(verdict.verdict, "refused")
        self.assertIn("opencode-go/deepseek-v4-pro", verdict.reason)
        self.assertIn("grant", verdict.remedy)

    def test_no_environment_variable_allows_a_model(self) -> None:
        env = dict(self.env, YMIR_MODEL_ALLOW="1", YMIR_ALLOW_ANY="1", YMIR_SKIP_MODEL_ALLOW="1")
        self.assertEqual(allow.check("opencode-go/deepseek-v4-pro", harness="pi", env=env, now=NOW).verdict, "refused")

    def test_an_unreadable_list_fails_closed(self) -> None:
        self.list.write_text("allow: [unclosed\n", encoding="utf-8")
        self.assertEqual(self.check("llama-swap/q@iq3").verdict, "refused")

    def test_no_list_is_unpoliced_and_says_so(self) -> None:
        self.list.unlink()
        verdict = self.check("opencode-go/deepseek-v4-pro")
        self.assertEqual(verdict.verdict, "unpoliced")
        self.assertTrue(verdict.ok)

    # ── Claude ──
    def test_claude_defaults_to_the_lists_opus(self) -> None:
        verdict = self.check("", harness="claude")
        self.assertEqual((verdict.verdict, verdict.model), ("allowed", "claude-opus-5-5"))

    def test_claude_alias_opus_resolves_to_the_allowed_id(self) -> None:
        self.assertEqual(self.check("opus", harness="claude").model, "claude-opus-5-5")

    def test_claude_refuses_sonnet_haiku_fable(self) -> None:
        for model in ("sonnet", "haiku", "fable", "claude-sonnet-5-5", "claude-haiku-5-5", "claude-fable-5-2"):
            self.assertEqual(self.check(model, harness="claude").verdict, "refused", model)

    def test_claude_never_takes_another_harness_model(self) -> None:
        verdict = self.check("opencode-go/deepseek-v4.1-flash", harness="claude")
        self.assertEqual(verdict.verdict, "refused")
        self.assertIn("another harness", verdict.reason)

    # ── grants ──
    GRANT = ("  - model: opencode-go/deepseek-v4-pro\n    reason: one hard migration\n"
             "    granted_by: the operator\n    granted_at: 2026-11-12\n    expires: {exp}\n{uses}")

    def test_a_dated_grant_allows_and_is_logged_once_per_errand(self) -> None:
        self.grant(self.GRANT.format(exp="2026-11-13", uses=""))
        first = allow.enforce("opencode-go/deepseek-v4-pro", harness="pi", task="t1", env=self.env)
        self.assertEqual(first.verdict, "granted")
        allow.enforce("opencode-go/deepseek-v4-pro", harness="pi", task="t1", env=self.env)  # the engine asks again
        log = (Path(self.env["YMIR_STATE_DIR"]) / allow.USE_LOG).read_text(encoding="utf-8").splitlines()
        self.assertEqual(len([ln for ln in log if '"granted"' in ln]), 1)
        self.assertIn('"t1"', log[0])

    def test_an_expired_grant_is_refused(self) -> None:
        self.grant(self.GRANT.format(exp="2026-11-11", uses=""))
        verdict = self.check("opencode-go/deepseek-v4-pro")
        self.assertEqual(verdict.verdict, "refused")
        self.assertIn("expired", verdict.reason)

    def test_a_grant_missing_a_field_is_invalid(self) -> None:
        self.grant("  - model: opencode-go/deepseek-v4-pro\n    expires: 2026-12-01\n")
        verdict = self.check("opencode-go/deepseek-v4-pro")
        self.assertEqual(verdict.verdict, "refused")
        self.assertIn("invalid", verdict.reason)

    def test_uses_caps_distinct_errands(self) -> None:
        self.grant(self.GRANT.format(exp="2026-11-30", uses="    uses: 1\n"))
        self.assertEqual(allow.enforce("opencode-go/deepseek-v4-pro", harness="pi", task="a", env=self.env).verdict, "granted")
        self.assertEqual(allow.enforce("opencode-go/deepseek-v4-pro", harness="pi", task="a", env=self.env).verdict, "granted")
        spent = allow.enforce("opencode-go/deepseek-v4-pro", harness="pi", task="b", env=self.env)
        self.assertEqual(spent.verdict, "refused")
        self.assertIn("spent", spent.reason)

    # ── the audit ──
    def test_audit_names_a_live_seat_on_a_refused_model(self) -> None:
        state = Path(self.env["YMIR_STATE_DIR"])
        (state / "hot.meta").write_text("id=hot\nharness=pi\nmodel=opencode-go/deepseek-v4-pro\n", encoding="utf-8")
        (state / "cold.meta").write_text("id=cold\nharness=pi\nmodel=opencode-go/deepseek-v4-pro\n", encoding="utf-8")
        (state / "cold.status").write_text("done: shipped\n", encoding="utf-8")
        (state / "ok.meta").write_text("id=ok\nharness=claude\nmodel=claude-opus-5-5\n", encoding="utf-8")
        env = dict(self.env, PI_CODING_AGENT_DIR=str(state / "no-pi"))
        rows = allow.audit([state], env=env)
        self.assertEqual([r[0] for r in rows], ["seat:hot"])


if __name__ == "__main__":
    unittest.main()
