"""status · send · stop — the other three verbs, read from the record."""

from __future__ import annotations

import os
import tempfile
import time
import unittest
from pathlib import Path

from ymir_runtime import heartbeat
from ymir_runtime.errors import SeatNotFound
from ymir_runtime.send import send as send_verb
from ymir_runtime.status import SeatState
from ymir_runtime.status import status as status_verb
from ymir_runtime.stop import stop as stop_verb
from ymir_runtime.tests.support import LiveSeatRunner, Recorder, completed, engine_env


class StatusTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.env = engine_env(self.tmp)
        self.state = Path(self.env["YMIR_STATE_DIR"])

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _seat(self, lines: list[str], *, age: int = 5) -> None:
        heartbeat.write_meta(self.state, "s1", {"launched": str(int(time.time()) - age), "backend": "tmux", "window": "@7"})
        for line in lines:
            path = heartbeat.append(self.state, "s1", line)
        if age:
            stamp = time.time() - age
            os.utime(path, (stamp, stamp))

    def test_an_unknown_seat_is_idle(self) -> None:
        self.assertEqual(status_verb("nobody", env=self.env, check_alive=False), SeatState.IDLE)

    def test_a_done_line_is_done(self) -> None:
        self._seat(["working: busy", "done: opened PR"])
        self.assertEqual(status_verb("s1", env=self.env, check_alive=False), SeatState.DONE)

    def test_a_failed_line_is_blocked(self) -> None:
        self._seat(["failed: died loudly"])
        self.assertEqual(status_verb("s1", env=self.env, check_alive=False), SeatState.BLOCKED)

    def test_a_blocked_line_is_blocked(self) -> None:
        self._seat(["blocked: waiting on a key"])
        self.assertEqual(status_verb("s1", env=self.env, check_alive=False), SeatState.BLOCKED)

    def test_silence_is_blocked(self) -> None:
        self._seat(["working: busy"], age=4000)
        self.assertEqual(status_verb("s1", env=self.env, check_alive=False), SeatState.BLOCKED)

    def test_a_fresh_live_seat_is_working(self) -> None:
        self._seat(["working: busy"])
        runner = Recorder(responses={"tmux list-windows -a -F": completed(0, "@3\n@7\n")})
        self.assertEqual(status_verb("s1", env=self.env, runner=runner), SeatState.WORKING)

    def test_a_fresh_seat_whose_pane_is_gone_is_idle(self) -> None:
        self._seat(["working: busy"])
        runner = Recorder(responses={"tmux list-windows -a -F": completed(0, "@3\n")})
        self.assertEqual(status_verb("s1", env=self.env, runner=runner), SeatState.IDLE)

    def test_the_four_states_are_the_whole_interface(self) -> None:
        self.assertEqual([state.value for state in SeatState], ["working", "blocked", "done", "idle"])


class SendTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.env = engine_env(self.tmp)
        self.state = Path(self.env["YMIR_STATE_DIR"])

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_messages_are_numbered_and_written_before_they_are_spoken(self) -> None:
        first = send_verb("s1", "first word", env=self.env, poke=False)
        second = send_verb("s1", "second word", env=self.env, poke=False)
        self.assertEqual(first.message.name, "001.msg")
        self.assertEqual(second.message.name, "002.msg")
        self.assertEqual(first.message.read_text(encoding="utf-8"), "first word\n")
        self.assertFalse(first.poked)

    def test_a_live_target_is_poked(self) -> None:
        heartbeat.write_meta(self.state, "s1", {"backend": "tmux", "window": "@7"})
        runner = Recorder(responses={"tmux send-keys": completed(0, "", "")})
        result = send_verb("s1", "steer left", env=self.env, runner=runner)
        self.assertTrue(result.poked)
        self.assertTrue(runner.saw("tmux send-keys -t @7 -l"))

    def test_a_seat_with_no_live_target_still_receives_the_message(self) -> None:
        heartbeat.write_meta(self.state, "s1", {"backend": "tmux", "window": "@7"})
        runner = Recorder(responses={"tmux send-keys": completed(1, "", "no window")})
        result = send_verb("s1", "filed anyway", env=self.env, runner=runner)
        self.assertFalse(result.poked)
        self.assertTrue(result.message.is_file())


class StopTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.env = engine_env(self.tmp)
        self.state = Path(self.env["YMIR_STATE_DIR"])

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_an_unknown_seat_is_not_found(self) -> None:
        with self.assertRaises(SeatNotFound):
            stop_verb("ghost", env=self.env, runner=Recorder())

    def test_a_seated_worker_is_reaped_and_recorded(self) -> None:
        heartbeat.write_meta(
            self.state,
            "s1",
            {
                "launched": str(int(time.time())),
                "backend": "tmux",
                "window": "@7",
                "worktree": str(self.tmp / "wt"),
                "project": str(self.tmp / "repo"),
            },
        )
        runner = LiveSeatRunner()
        result = stop_verb("s1", env=self.env, runner=runner)
        self.assertTrue(result.reaped)
        self.assertEqual(result.target, "@7")
        self.assertTrue(heartbeat.last_line(self.state, "s1").startswith("done: stopped "))
        self.assertEqual(status_verb("s1", env=self.env, check_alive=False), SeatState.DONE)

    def test_a_close_that_did_not_take_is_reported_not_hidden(self) -> None:
        heartbeat.write_meta(self.state, "s1", {"launched": str(int(time.time())), "backend": "tmux", "window": "@7"})
        runner = LiveSeatRunner(fail_kill=True)
        result = stop_verb("s1", env=self.env, runner=runner)
        self.assertFalse(result.reaped)
        self.assertIn("still answers", result.detail)


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
