"""harness.py — the choice, the provenance, and the exact launch line."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

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

    def test_an_unservable_model_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            harness.resolve(harness="pi", model="openai/not-in-catalog", catalog=lambda: ["llama-swap/q@iq3"])


class CodexHarnessTest(unittest.TestCase):
    def test_native_default_does_not_query_pi_catalog(self):
        def forbidden():
            raise AssertionError("Codex must not query Pi")
        selected = harness.resolve(harness="codex", catalog=forbidden)
        self.assertTrue(selected.is_verified)
        self.assertEqual(selected.model, "")

    def test_native_model_is_not_checked_against_pi(self):
        selected = harness.resolve(harness="codex", model="native-model", catalog=lambda: ["other/provider"])
        self.assertEqual(selected.model, "native-model")
        with self.assertRaises(ValueError):
            harness.resolve(harness="codex", model="provider/model", catalog=lambda: [])

    def test_no_daemon_is_an_explicit_distribution_option(self):
        selected = harness.resolve(harness="codex", env={"YMIR_CODEX_NO_DAEMON": "1"}, catalog=lambda: [])
        self.assertIn("codex --no-daemon ", harness.build_launch_command(selected, "/brief.md"))
        selected = harness.resolve(harness="codex", env={}, catalog=lambda: [])
        self.assertNotIn("--no-daemon", harness.build_launch_command(selected, "/brief.md"))

    def test_codex_prompt_stays_data_after_shell_expansion(self):
        import os
        import json
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            brief = root / "brief with spaces.md"
            text = 'quoted "brief" $(touch should-not-exist) `false` ; newline\nnext'
            brief.write_text(text)
            stub = root / "codex"
            stub.write_text("#!/usr/bin/env python3\nimport json,sys;print(json.dumps(sys.argv[1:]))\n")
            stub.chmod(0o755)
            selected = harness.resolve(harness="codex", model="native-model", effort="high", catalog=lambda: [])
            cmd = harness.build_launch_command(selected, str(brief))
            result = subprocess.run(["bash", "-c", "exec " + cmd], env={**os.environ, "PATH": str(root)+os.pathsep+os.environ["PATH"]}, text=True, capture_output=True, cwd=root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), ["--model", "native-model", "-c", 'model_reasoning_effort="high"', text])
            self.assertFalse((root / "should-not-exist").exists())


class BuildLaunchCommandTest(unittest.TestCase):
    def test_pi_shape_matches_the_shell_road(self) -> None:
        selection = harness.HarnessSelection("pi", "llama-swap/q@iq3", "high", "", "")
        self.assertEqual(
            harness.build_launch_command(selection, "/d/prompt.md"),
            "pi --model 'llama-swap/q@iq3' --thinking 'high' \"$(cat '/d/prompt.md')\"",
        )

    def test_pi_without_model_or_effort(self) -> None:
        selection = harness.HarnessSelection("pi", "", "", "", "")
        self.assertEqual(
            harness.build_launch_command(selection, "/d/prompt.md"),
            "pi \"$(cat '/d/prompt.md')\"",
        )

    def test_opencode_shape_matches_the_shell_road(self) -> None:
        selection = harness.HarnessSelection("opencode", "openai/gpt-5", "", "", "")
        self.assertEqual(
            harness.build_launch_command(selection, "/d/prompt.md"),
            "env OPENCODE_CONFIG_CONTENT='{\"permission\":{\"*\":\"allow\"}}' opencode "
            "--model 'openai/gpt-5' --prompt \"$(cat '/d/prompt.md')\"",
        )

    def test_every_launch_shape_survives_the_exec_prefix(self) -> None:
        """The seat writer prefixes `exec ` to any shape that lacks it.

        `exec NAME=value cmd` is not runnable shell: bash looks for a command
        literally named `NAME=value`. That killed every opencode seat on 2026-09-30
        with "exec: OPENCODE_CONFIG_CONTENT=…: not found". This guard holds the
        CONTRACT rather than the string — any shape that fails to parse after the
        prefix is a shape that cannot seat an agent.
        """
        for name, model in (("opencode", "openai/gpt-5"), ("pi", None), ("pi-signed", None)):
            shape = harness.build_launch_command(
                harness.HarnessSelection(name, model or "", "", "", ""), "/d/prompt.md"
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

    def test_raw_launch_substitutes_the_brief_reference(self) -> None:
        selection = harness.HarnessSelection("bash", "", "", "", "", "bash -c 'run __BRIEF__'")
        self.assertEqual(
            harness.build_launch_command(selection, "/d/prompt.md"),
            "bash -c 'run '/d/prompt.md''",
        )

    def test_shell_quote_survives_an_apostrophe(self) -> None:
        selection = harness.HarnessSelection("pi", "prov/it's", "", "", "")
        self.assertIn("'prov/it'\\''s'", harness.build_launch_command(selection, "/d/p.md"))


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
