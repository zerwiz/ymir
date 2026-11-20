"""backend.py — herdr first, tmux the verified fallback, nothing assumed."""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from ymir_runtime import backend
from ymir_runtime.tests.support import Recorder, completed, tmux_responses


def no_server() -> Recorder:
    return Recorder(responses={"pgrep -f herdr server": completed(1, "", "")})


def available(name: str) -> str:
    return f"/usr/bin/{name}"


class ChooseTest(unittest.TestCase):
    def test_explicit_backend_wins(self) -> None:
        chosen = backend.choose(requested="tmux", runner=no_server(), probe=available)
        self.assertEqual(chosen.name, "tmux")
        self.assertEqual(chosen.reason, "explicit --backend")

    def test_unsupported_backend_is_refused(self) -> None:
        with self.assertRaises(ValueError):
            backend.choose(requested="zellij", runner=no_server(), probe=available)

    def test_env_declaration_is_honoured(self) -> None:
        chosen = backend.choose(env={"BROKK_BACKEND": "herdr"}, runner=no_server(), probe=available)
        self.assertEqual(chosen.name, "herdr")
        self.assertIn("BROKK_BACKEND", chosen.reason)

    def test_config_file_is_honoured(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "backend").write_text("tmux\n", encoding="utf-8")
            chosen = backend.choose(config_dir=tmp, runner=no_server(), probe=available)
            self.assertEqual(chosen.name, "tmux")

    def test_herdr_wins_when_the_server_answers(self) -> None:
        runner = Recorder(responses={"pgrep -f herdr server": completed(0, "1 herdr server", "")})
        chosen = backend.choose(runner=runner, probe=available)
        self.assertEqual(chosen.name, "herdr")
        self.assertIn("herdr server answers", chosen.reason)

    def test_tmux_is_the_fallback_when_no_server_answers(self) -> None:
        chosen = backend.choose(runner=no_server(), probe=available)
        self.assertEqual(chosen.name, "tmux")
        self.assertIn("tmux is the fallback", chosen.reason)

    def test_no_backend_at_all_is_a_plain_refusal(self) -> None:
        with self.assertRaises(RuntimeError):
            backend.choose(runner=no_server(), probe=lambda name: "")


class LaunchTmuxTest(unittest.TestCase):
    def test_launch_builds_the_window_and_returns_its_id(self) -> None:
        runner = Recorder(responses=tmux_responses())
        seat = backend.launch(
            backend.Backend("tmux", "test"),
            seat_id="errand",
            pane_cmd="bash /state/errand.launch.sh",
            cwd="/wt",
            seat_state_dir="/seat-state",
            runner=runner,
            probe=available,
        )
        self.assertEqual(seat.backend, "tmux")
        self.assertEqual(seat.target, "@7")
        self.assertTrue(runner.saw("tmux new-window"))
        sent = runner.saw("tmux send-keys -t @7 -l")
        self.assertEqual(len(sent), 1)
        self.assertIn("BROKK_MACHINE_STATE_DIR='/seat-state'", sent[0][-1])
        self.assertIn("bash /state/errand.launch.sh", sent[0][-1])

    def test_an_existing_window_is_refused_never_stolen(self) -> None:
        runner = Recorder(
            responses={
                "tmux has-session": completed(0, "", ""),
                "tmux list-windows -t brokk -F": completed(0, "eindri-errand\n"),
            }
        )
        with self.assertRaises(RuntimeError) as caught:
            backend.launch(
                backend.Backend("tmux", "test"),
                seat_id="errand",
                pane_cmd="bash x",
                cwd="/wt",
                runner=runner,
                probe=available,
            )
        self.assertIn("already exists", str(caught.exception))

    def test_send_text_types_each_line_and_enters_it(self) -> None:
        runner = no_server()
        ok = backend.send_text(
            backend.Seat("tmux", "@7"), "one\ntwo", runner=runner, probe=available
        )
        self.assertTrue(ok)
        literals = runner.saw("tmux send-keys -t @7 -l")
        self.assertEqual([call[-1] for call in literals], ["one", "two"])
        self.assertEqual(len(runner.saw("tmux send-keys -t @7 Enter")), 2)

    def test_alive_reads_the_window_list(self) -> None:
        runner = Recorder(responses={"tmux list-windows -a -F": completed(0, "@3\n@7\n")})
        self.assertTrue(backend.alive(backend.Seat("tmux", "@7"), runner=runner, probe=available))
        self.assertFalse(backend.alive(backend.Seat("tmux", "@9"), runner=runner, probe=available))

    def test_kill_closes_the_window(self) -> None:
        runner = Recorder(
            responses={
                "tmux kill-window": completed(0, "", ""),
                "tmux list-windows -a -F": completed(0, "@3\n"),
            }
        )
        self.assertTrue(backend.kill(backend.Seat("tmux", "@7"), runner=runner, probe=available))
        self.assertTrue(runner.saw("tmux kill-window -t @7"))


class LaunchHerdrTest(unittest.TestCase):
    def test_launch_parses_the_workspace_and_pane(self) -> None:
        runner = Recorder(
            responses={
                "herdr workspace create": completed(0, '{"workspace_id": "wZ"}', ""),
                "herdr pane list --workspace wZ": completed(0, '[{"pane_id": "wZ:p1"}]', ""),
            }
        )
        seat = backend.launch(
            backend.Backend("herdr", "test"),
            seat_id="errand",
            pane_cmd="bash /state/errand.launch.sh",
            cwd="/wt",
            seat_state_dir="/seat-state",
            runner=runner,
            probe=available,
        )
        self.assertEqual(seat.target, "wZ:p1")
        self.assertEqual(seat.workspace, "wZ")
        create = runner.saw("herdr workspace create")[0]
        self.assertIn("BROKK_STATE_OVERRIDE=/seat-state", create)

    def test_herdr_send_prefers_the_agent_prompt_road(self) -> None:
        runner = Recorder(responses={"herdr agent prompt": completed(0, "", "")})
        self.assertTrue(backend.send_text(backend.Seat("herdr", "wZ:p1", "wZ"), "go", runner=runner, probe=available))
        self.assertTrue(runner.saw("herdr agent prompt wZ:p1 go"))

    def test_herdr_send_falls_back_to_the_pane_when_no_agent_is_seated(self) -> None:
        runner = Recorder(
            responses={
                "herdr agent prompt": completed(1, "", "no agent"),
                "herdr pane send-text": completed(0, "", ""),
            }
        )
        self.assertTrue(backend.send_text(backend.Seat("herdr", "wZ:p1", "wZ"), "go", runner=runner, probe=available))
        self.assertTrue(runner.saw("herdr pane send-text wZ:p1 go"))

    def test_kill_prefers_closing_the_whole_workspace(self) -> None:
        runner = Recorder(responses={"herdr workspace close": completed(0, "", "")})
        self.assertTrue(backend.kill(backend.Seat("herdr", "wZ:p1", "wZ"), runner=runner, probe=available))
        self.assertTrue(runner.saw("herdr workspace close --workspace wZ"))


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
