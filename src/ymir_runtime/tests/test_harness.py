"""harness.py — the choice, the provenance, and the exact launch line."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from ymir_runtime import harness
from ymir_runtime.tests.support import Recorder


class ResolveTest(unittest.TestCase):
    def test_explicit_flag_wins(self) -> None:
        selection = harness.resolve(harness="pi", model="llama-swap/qwen3.6-35b-a3b@iq3_s", catalog=lambda: [])
        self.assertEqual(selection.name, "pi")
        self.assertEqual(selection.provenance, "explicit flag (--harness)")
        self.assertEqual(selection.model_provenance, "explicit flag (--model)")
        self.assertTrue(selection.is_verified)
        self.assertTrue(selection.is_local)

    def test_config_file_names_the_harness_when_no_flag_does(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            (config / "eindri-harness").write_text("# the seat's choice\nopencode gpt-5 low\n", encoding="utf-8")
            selection = harness.resolve(config_dir=config, catalog=lambda: [])
            self.assertEqual(selection.name, "opencode")
            self.assertEqual(selection.model, "gpt-5")
            self.assertEqual(selection.effort, "low")
            self.assertEqual(selection.provenance, "config/eindri-harness (this machine)")

    def test_config_file_ignores_comments_and_default(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            (config / "eindri-harness").write_text("default\n", encoding="utf-8")
            logger = Recorder(catalog=["llama-swap/qwen3.6-35b-a3b@iq3_s"])
            selection = harness.resolve(config_dir=config, runner=logger)
            self.assertEqual(selection.name, "pi")
            self.assertEqual(selection.model, "llama-swap/qwen3.6-35b-a3b@iq3_s")
            self.assertIn("first served local model", selection.model_provenance)

    def test_fleet_law_prefers_pi_when_a_local_catalog_exists(self) -> None:
        selection = harness.resolve(catalog=lambda: ["llama-swap/q@iq3"])
        self.assertEqual(selection.name, "pi")
        self.assertIn("local -> pi", selection.provenance)

    def test_fleet_law_falls_to_opencode_with_no_local_catalog(self) -> None:
        selection = harness.resolve(catalog=lambda: [])
        self.assertEqual(selection.name, "opencode")
        self.assertIn("hosted -> opencode", selection.provenance)

    def test_a_raw_launch_is_carried_verbatim(self) -> None:
        selection = harness.resolve(harness="bash -lc 'echo hi'")
        self.assertEqual(selection.raw_launch, "bash -lc 'echo hi'")
        self.assertEqual(selection.name, "bash")
        self.assertFalse(selection.is_verified)
        self.assertIn("escape hatch", selection.provenance)

    def test_claude_drops_a_machine_model_meant_for_pi_or_opencode(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp)
            (config / "eindri-harness").write_text("opencode opencode-go/deepseek-v4.1-flash\n", encoding="utf-8")
            selection = harness.resolve(harness="claude", config_dir=config, catalog=lambda: [])
        self.assertEqual(selection.name, "claude")
        self.assertEqual(selection.model, "sonnet")

    def test_a_simple_claude_errand_runs_on_sonnet(self) -> None:
        for effort in ("", "low", "medium"):
            selection = harness.resolve(harness="claude", effort=effort, catalog=lambda: [])
            self.assertEqual(selection.model, "sonnet", effort)
            self.assertIn("errand weight", selection.model_provenance)

    def test_a_heavy_claude_errand_runs_on_opus(self) -> None:
        for effort in ("high", "xhigh", "max"):
            selection = harness.resolve(harness="claude", effort=effort, catalog=lambda: [])
            self.assertEqual(selection.model, "opus", effort)

    def test_an_explicit_claude_model_beats_the_weight(self) -> None:
        selection = harness.resolve(harness="claude", model="haiku", effort="max", catalog=lambda: [])
        self.assertEqual(selection.model, "haiku")

    def test_claude_refuses_an_explicit_provider_model_token(self) -> None:
        with self.assertRaises(ValueError) as caught:
            harness.resolve(harness="claude", model="llama-swap/qwen@iq3", catalog=lambda: [])
        self.assertIn("cannot serve model", str(caught.exception))

    def test_claude_keeps_an_explicit_anthropic_alias(self) -> None:
        selection = harness.resolve(harness="claude", model="sonnet", catalog=lambda: [])
        self.assertEqual(selection.model, "sonnet")

    def test_an_unservable_model_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            harness.resolve(harness="pi", model="openai/not-in-catalog", catalog=lambda: ["llama-swap/q@iq3"])


class BuildLaunchCommandTest(unittest.TestCase):
    """The pi shape is COMPOSED BY THE GENERATOR — asserted through it, not guessed."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.cwd = Path(self._tmp.name)
        demo = self.cwd / ".pi" / "extensions" / "demo"
        demo.mkdir(parents=True)
        (demo / "index.ts").write_text("// a door\n", encoding="utf-8")
        flat = self.cwd / ".pi" / "extensions" / "flat.ts"
        flat.write_text("// another door\n", encoding="utf-8")
        # A deterministic settings file: the machine's real npm packages would make
        # this assertion depend on one operator's harness settings.
        settings = self.cwd / "settings.json"
        settings.write_text('{"packages":["npm:@example/one"]}', encoding="utf-8")
        self.env = mock.patch.dict(
            os.environ, {"YMIR_PI_SETTINGS": str(settings)}, clear=False
        )
        self.env.start()

    def tearDown(self) -> None:
        self.env.stop()
        self._tmp.cleanup()

    def test_pi_shape_is_discovery_off_and_names_every_extension_once(self) -> None:
        selection = harness.HarnessSelection("pi", "llama-swap/q@iq3", "high", "", "")
        shape = harness.build_launch_command(selection, "/d/prompt.md", self.cwd)
        self.assertEqual(
            shape,
            "pi --model 'llama-swap/q@iq3' --thinking 'high' -ne"
            f" -e '{self.cwd}/.pi/extensions/demo/index.ts'"
            f" -e '{self.cwd}/.pi/extensions/flat.ts'"
            " -e 'npm:@example/one'"
            ' "$(cat \'/d/prompt.md\')"',
        )

    def test_pi_without_model_or_effort(self) -> None:
        selection = harness.HarnessSelection("pi", "", "", "", "")
        shape = harness.build_launch_command(selection, "/d/prompt.md", self.cwd)
        self.assertTrue(shape.startswith("pi -ne -e "), shape)
        self.assertIn('"$(cat \'/d/prompt.md\')"', shape)

    def test_a_cwd_without_an_extension_tree_is_refused(self) -> None:
        selection = harness.HarnessSelection("pi", "", "", "", "")
        empty = self.cwd / "empty"
        empty.mkdir()
        with self.assertRaises(ValueError):
            harness.build_launch_command(selection, "/d/prompt.md", empty)

    def test_opencode_shape_matches_the_shell_road(self) -> None:
        selection = harness.HarnessSelection("opencode", "openai/gpt-5", "", "", "")
        self.assertEqual(
            harness.build_launch_command(selection, "/d/prompt.md"),
            "env OPENCODE_CONFIG_CONTENT='{\"permission\":{\"*\":\"allow\"}}' opencode "
            "run --model 'openai/gpt-5' --auto \"$(cat '/d/prompt.md')\"",
        )

    def test_opencode_shape_matches_its_launcher_door(self) -> None:
        """Two copies of one shape killed every engine-seated OpenCode seat (2026-11-12)."""
        import subprocess
        selection = harness.HarnessSelection("opencode", "openai/gpt-5", "", "", "")
        door = subprocess.run(
            [str(harness.opencode_launcher_door()), "print", "--model", "openai/gpt-5", "--brief", "/d/prompt.md"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        self.assertEqual(harness.build_launch_command(selection, "/d/prompt.md"), door)

    def test_free_resolves_through_the_free_model_door(self) -> None:
        calls = []

        def runner(argv):
            calls.append(argv)
            return subprocess.CompletedProcess(argv, 0, "opencode/glm-5.3-flash-free\n", "")

        selection = harness.resolve(harness="opencode", model="free", catalog=lambda: [], runner=runner)
        self.assertEqual(selection.model, "opencode/glm-5.3-flash-free")
        self.assertEqual(calls[0][1:], ["pick", "opencode"])
        self.assertIn("free", selection.model_provenance)

    def test_claude_refuses_free(self) -> None:
        with self.assertRaises(ValueError):
            harness.resolve(harness="claude", model="free", catalog=lambda: [])

    def test_every_launch_shape_survives_the_exec_prefix(self) -> None:
        """The seat writer prefixes `exec ` to any shape that lacks it.

        `exec NAME=value cmd` is not runnable shell: bash looks for a command
        literally named `NAME=value`. That killed every opencode seat on 2026-09-30
        with "exec: OPENCODE_CONFIG_CONTENT=…: not found". This guard holds the
        CONTRACT rather than the string — any shape that fails to parse after the
        prefix is a shape that cannot seat an agent.
        """
        for name, model in (("opencode", "openai/gpt-5"), ("pi", None), ("pi-signed", None), ("claude", "sonnet")):
            # claude reads its worker profile from the Ymir tree, pi its pins from self.cwd
            shape = harness.build_launch_command(
                harness.HarnessSelection(name, model or "", "", "", ""),
                "/d/prompt.md",
                None if name == "claude" else self.cwd,
            )
            with self.subTest(harness=name):
                proc_ok = subprocess.run(
                    ["bash", "-n"], input=f"exec {shape}\n", text=True, capture_output=True
                )
                self.assertEqual(proc_ok.returncode, 0, f"unparseable after exec: {shape}")
                bare_ok = subprocess.run(
                    ["bash", "-n"], input=f"{shape}\n", text=True, capture_output=True
                )
                self.assertEqual(bare_ok.returncode, 0, f"unparseable on its own: {shape}")

    def test_claude_is_a_verified_harness(self) -> None:
        self.assertIn("claude", harness.VERIFIED)

    def test_claude_shape_carries_the_worker_profile_and_the_brief(self) -> None:
        selection = harness.HarnessSelection("claude", "sonnet", "", "", "")
        shape = harness.build_launch_command(selection, "/d/prompt.md")
        profile = harness.claude_worker_profile(None)
        self.assertEqual(
            shape,
            f"claude --permission-mode acceptEdits --settings '{profile}' "
            "--model 'sonnet' \"$(cat '/d/prompt.md')\"",
        )

    def test_the_shipped_claude_profile_denies_the_allfathers_moves(self) -> None:
        import json

        profile = json.loads(harness.claude_worker_profile(None).read_text(encoding="utf-8"))
        deny = profile["permissions"]["deny"]
        for rule in ("Bash(git push origin main:*)", "Bash(gh pr merge:*)", "Bash(git add -A:*)",
                     "Bash(git push --force:*)", "Bash(git reset --hard:*)"):
            with self.subTest(rule=rule):
                self.assertIn(rule, deny)

    def test_a_claude_seat_without_its_profile_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as empty:
            with self.assertRaises(ValueError) as caught:
                harness.build_launch_command(
                    harness.HarnessSelection("claude", "", "", "", ""), "/d/prompt.md", empty
                )
        self.assertIn("worker profile is missing", str(caught.exception))

    def test_raw_launch_substitutes_the_brief_reference(self) -> None:
        selection = harness.HarnessSelection("bash", "", "", "", "", "bash -c 'run __BRIEF__'")
        self.assertEqual(
            harness.build_launch_command(selection, "/d/prompt.md"),
            "bash -c 'run '/d/prompt.md''",
        )

    def test_shell_quote_survives_an_apostrophe(self) -> None:
        selection = harness.HarnessSelection("pi", "prov/it's", "", "", "")
        self.assertIn(
            "'prov/it'\\''s'",
            harness.build_launch_command(selection, "/d/p.md", self.cwd),
        )


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
