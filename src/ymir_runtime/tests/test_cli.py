"""__main__.py — the door face, its exit codes, and the compat line."""

from __future__ import annotations

import contextlib
import io
import tempfile
import time
import unittest
from pathlib import Path

from ymir_runtime import __main__ as cli
from ymir_runtime.tests.support import Recorder, engine_env, make_repo, tmux_responses, write_brief


def available(name: str) -> str:
    return f"/usr/bin/{name}"


class CliTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.repo = make_repo(self.tmp / "repo")
        self.env = engine_env(self.tmp, repo=self.repo)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _run(self, argv: list[str], *, runner=None, probe=None) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = cli.main(argv, runner=runner, probe=probe, env=self.env)
        return code, out.getvalue(), err.getvalue()

    def test_version_verb(self) -> None:
        code, out, _ = self._run(["version"])
        self.assertEqual(code, cli.EXIT_OK)
        self.assertTrue(out.strip())

    def test_seat_refusal_exits_four_so_the_adapter_keeps_the_old_road(self) -> None:
        write_brief(self.tmp, "errand-utgard", "# Untrusted\nIsolation: utgard — untrusted input\n")
        code, _, err = self._run(
            [
                "seat", "errand-utgard",
                "--project", str(self.repo),
                "--isolation", "auto",
                "--harness", "pi",
            ],
            runner=Recorder(),
            probe=lambda name: "",
        )
        self.assertEqual(code, cli.EXIT_CANNOT_OWN)
        self.assertIn("engine-cannot-own", err)

    def test_seat_prints_the_old_door_compat_line(self) -> None:
        write_brief(self.tmp, "errand-one", "# Task\n\nForge it: write the artefact.\n\nIsolation: herdr — the ordinary road\n\nDelivery contract: mode=direct-PR\n")
        code, out, _ = self._run(
            [
                "seat", "errand-one",
                "--project", str(self.repo),
                "--harness", "pi",
                "--model", "llama-swap/qwen3.6-35b-a3b@iq3_s",
                "--backend", "tmux",
                "--compat",
            ],
            runner=Recorder(responses=tmux_responses()),
            probe=available,
        )
        self.assertEqual(code, cli.EXIT_OK, out)
        self.assertIn("spawned errand-one harness=pi kind=ship mode=direct-PR yolo=off backend=tmux", out)
        self.assertIn("target=@7", out)
        self.assertIn(f"worktree={self.repo / '.yggdrasil' / 'errand-one'}", out)
        self.assertIn("isolation=off", out)

    def test_status_reads_the_record(self) -> None:
        from ymir_runtime import heartbeat

        heartbeat.write_meta(
            Path(self.env["YMIR_STATE_DIR"]), "s1", {"launched": str(int(time.time()))}
        )
        code, out, _ = self._run(["status", "s1", "--toon"])
        self.assertEqual(code, cli.EXIT_FAILED, "a seat with no live pane answers idle, non-zero")
        self.assertIn("idle", out)

    def test_status_of_an_unknown_seat_exits_non_zero_but_prints_the_state(self) -> None:
        code, out, _ = self._run(["status", "nobody"])
        self.assertEqual(code, cli.EXIT_FAILED)
        self.assertEqual(out.strip(), "idle")

    def test_usage_error_is_two(self) -> None:
        with self.assertRaises(SystemExit) as caught:
            self._run(["nonsense"])
        self.assertEqual(caught.exception.code, cli.EXIT_USAGE)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
