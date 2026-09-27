"""watch.py — the arm's behaviour, read from the record it writes."""

from __future__ import annotations

import hashlib
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

from ymir_runtime import proc, watch
from ymir_runtime.tests.support import Recorder, completed, engine_env


def dead_signal_zero(_pid: int) -> None:
    raise ProcessLookupError("gone")


class ArmTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.env = engine_env(self.tmp)
        self.paths = watch.arm_paths(self.env)
        self.paths.state.mkdir(parents=True, exist_ok=True)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def lease(self, **fields: str) -> None:
        pid = fields.get("pid", str(os.getpid()))
        base = {
            "pid": pid,
            "starttime": watch.proc.proc_starttime(int(pid)) if pid.isdigit() else "",
            "gen": "1",
            "mode": "daemon",
            "session": "none",
            "heartbeat": str(int(time.time())),
            "state": str(self.paths.state),
        }
        base.update(fields)
        body = " ".join(f"{key}={value}" for key, value in base.items()) + "\n"
        self.paths.lease.write_text(body, encoding="utf-8")


class PathsTest(ArmTestCase):
    def test_thresholds_come_from_the_named_environment(self) -> None:
        env = dict(self.env)
        env.update(
            BROKK_WATCH_POLL_SECONDS="1",
            BROKK_WATCH_HEARTBEAT_STALE_SECONDS="7",
            SYN_WATCH_UNIT="a-unit",
        )
        paths = watch.arm_paths(env)
        self.assertEqual(paths.poll_seconds, 1)
        self.assertEqual(paths.stale_seconds, 7)
        self.assertEqual(paths.unit, "a-unit")

    def test_a_zero_or_junk_threshold_falls_back_to_the_default(self) -> None:
        env = dict(self.env)
        env["BROKK_WATCH_POLL_SECONDS"] = "0"
        self.assertEqual(watch.arm_paths(env).poll_seconds, watch.DEFAULT_POLL_SECONDS)


class LeaseTest(ArmTestCase):
    def test_no_lease_is_not_alive(self) -> None:
        self.assertFalse(watch.lease_alive(self.paths))

    def test_a_lease_for_this_state_and_a_live_pid_is_alive(self) -> None:
        self.lease()
        self.assertTrue(watch.lease_alive(self.paths))

    def test_a_lease_for_another_state_does_not_hold_ours(self) -> None:
        self.lease(state="/somewhere/else")
        self.assertFalse(watch.lease_alive(self.paths))

    def test_a_dead_pid_is_not_alive(self) -> None:
        self.lease(pid="4000000")
        self.assertFalse(
            watch.lease_alive(
                self.paths,
                stat_reader=lambda pid: "",
                signal_zero=dead_signal_zero,
            )
        )

    def test_a_recycled_pid_is_death_not_a_holder(self) -> None:
        self.lease(starttime="1")
        stat = f"({os.getpid()}) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 99 20 21\n"
        self.assertFalse(
            watch.lease_alive(self.paths, stat_reader=lambda pid: stat, signal_zero=lambda pid: None)
        )

    def test_write_then_release_only_drops_our_own(self) -> None:
        self.assertTrue(watch.write_lease(self.paths, pid=os.getpid(), mode="daemon", session="none", generation=3))
        self.assertTrue(watch.lease_alive(self.paths))
        watch.release_lease(self.paths, pid=os.getpid() + 1)
        self.assertTrue(watch.lease_alive(self.paths), "another pid's release must not drop our lease")
        watch.release_lease(self.paths, pid=os.getpid())
        self.assertFalse(watch.lease_alive(self.paths))


class HeartbeatTest(ArmTestCase):
    def test_touch_then_age_is_inside_the_window(self) -> None:
        watch.heartbeat_touch(self.paths, now=1000.0)
        self.assertEqual(watch.heartbeat_age(self.paths, now=1004.0), 4)

    def test_no_beat_is_negative_one(self) -> None:
        self.assertEqual(watch.heartbeat_age(self.paths), -1)


class RaiseTest(ArmTestCase):
    def test_a_changed_queue_signals_once_then_holds(self) -> None:
        self.paths.wake_queue.write_text("wake\n", encoding="utf-8")
        self.assertEqual(watch.raise_line(self.paths), "signal: wake queue")
        self.assertEqual(watch.raise_line(self.paths), "", "an unchanged queue must not re-inject")

    def test_a_changed_queue_signals_again(self) -> None:
        self.paths.wake_queue.write_text("wake one\n", encoding="utf-8")
        self.assertEqual(watch.raise_line(self.paths), "signal: wake queue")
        self.paths.wake_queue.write_text("wake two\n", encoding="utf-8")
        self.assertEqual(watch.raise_line(self.paths), "signal: wake queue")

    def test_the_hash_is_the_content_hash(self) -> None:
        self.paths.wake_queue.write_bytes(b"payload")
        watch.raise_line(self.paths)
        self.assertEqual(
            self.paths.wake_hash.read_text(encoding="utf-8"),
            hashlib.md5(b"payload").hexdigest(),  # noqa: S324 - the door's own dedup key
        )

    def test_a_signal_trigger_is_consumed_and_named(self) -> None:
        (self.paths.state / "42.signal").write_text("", encoding="utf-8")
        self.assertEqual(watch.raise_line(self.paths), "signal: 42")
        self.assertFalse((self.paths.state / "42.signal").exists())
        self.assertEqual(watch.raise_line(self.paths), "")

    def test_a_check_trigger_is_consumed_and_named(self) -> None:
        (self.paths.state / "pr-9.check").write_text("", encoding="utf-8")
        self.assertEqual(watch.raise_line(self.paths), "check: pr-9")

    def test_the_operator_stop_is_a_stale_line(self) -> None:
        self.paths.stop_marker.touch()
        self.assertEqual(watch.raise_line(self.paths), "stale: watcher stopped by operator")
        self.assertFalse(self.paths.stop_marker.exists())

    def test_nothing_due_raises_nothing(self) -> None:
        self.assertEqual(watch.raise_line(self.paths), "")

    def test_publish_leaves_one_line_in_the_slot_and_journals_it(self) -> None:
        watch.publish(self.paths, "signal: first")
        watch.publish(self.paths, "signal: second")
        self.assertEqual(self.paths.event.read_text(encoding="utf-8"), "signal: first\n")
        self.assertEqual(
            self.paths.wake.read_text(encoding="utf-8").splitlines(),
            ["signal: first"],
            "an undelivered line is not overwritten, and the journal is append-only",
        )


class StatusTest(ArmTestCase):
    def test_no_lease_is_down(self) -> None:
        self.assertEqual(watch.status_state(self.paths), watch.DOWN)

    def test_a_live_lease_with_an_empty_helm_is_idle(self) -> None:
        self.lease(session="none")
        watch.heartbeat_touch(self.paths)
        self.paths.armed.touch()
        self.assertEqual(watch.status_state(self.paths), watch.IDLE)

    def test_a_live_lease_with_a_session_is_up(self) -> None:
        self.lease(session=str(os.getpid()))
        watch.heartbeat_touch(self.paths)
        self.paths.armed.touch()
        self.assertEqual(watch.status_state(self.paths), watch.UP)

    def test_an_old_beat_is_stale(self) -> None:
        self.lease(session="none")
        watch.heartbeat_touch(self.paths, now=1000.0)
        self.paths.armed.touch()
        self.assertEqual(watch.status_state(self.paths, now=1000.0 + self.paths.stale_seconds + 1), watch.STALE)

    def test_a_missing_armed_marker_is_stale(self) -> None:
        self.lease(session="none")
        watch.heartbeat_touch(self.paths)
        self.assertEqual(watch.status_state(self.paths), watch.STALE)

    def test_status_reports_healthy_with_rc_zero_and_a_gap_with_rc_one(self) -> None:
        body, code = watch.status_lines(self.paths, env=self.env)
        self.assertEqual(code, 1)
        self.assertTrue(body.startswith("syn-watch[1]{state,mode,unit,pid,heartbeat_age,stale_seconds,session,armed,state_dir}:\n"))
        self.assertIn('"down","none"', body)

    def test_the_toon_row_has_nine_fields(self) -> None:
        self.lease(session="none")
        watch.heartbeat_touch(self.paths)
        self.paths.armed.touch()
        row = watch.status_row(self.paths, env=self.env, runner=Recorder())
        self.assertEqual(row.count('"'), 18)


class SessionOwnerTest(ArmTestCase):
    def setUp(self) -> None:
        super().setUp()
        # The lock law is Gleipnir's, so the door must resolve a tree that really
        # holds it; the runner is a double, so nothing executes.
        self.env["YMIR_ENGINE_ROOT"] = str(Path(__file__).resolve().parents[3])
        self.env["BROKK_ROOT_OVERRIDE"] = str(Path(__file__).resolve().parents[3])
        self.paths = watch.arm_paths(self.env)
    def test_a_live_owner_from_the_lock_library_is_used(self) -> None:
        runner = Recorder(responses={"bash -c": completed(0, f"{os.getpid()}\n")})
        self.assertEqual(watch.session_owner(self.paths, env=self.env, runner=runner), str(os.getpid()))

    def test_an_empty_lock_is_none(self) -> None:
        runner = Recorder(responses={"bash -c": completed(0, "")})
        self.assertEqual(watch.session_owner(self.paths, env=self.env, runner=runner), "none")

    def test_a_dead_owner_is_none(self) -> None:
        runner = Recorder(responses={"bash -c": completed(0, "4000000")})
        self.assertEqual(
            watch.session_owner(self.paths, env=self.env, runner=runner, stat_reader=lambda pid: ""),
            "none",
        )


class CycleTest(ArmTestCase):
    def test_a_cycle_beats_leases_and_raises_nothing_when_nothing_is_due(self) -> None:
        line = watch.cycle(self.paths, env=self.env, runner=Recorder(responses={"bash -c": completed(0, "")}))
        self.assertEqual(line, "")
        self.assertTrue(self.paths.heartbeat.exists())
        self.assertTrue(self.paths.armed.exists())
        lease = watch.read_lease(self.paths.lease)
        self.assertEqual(lease["pid"], str(os.getpid()))
        self.assertEqual(lease["session"], "none")

    def test_emit_returns_the_line_and_leaves_the_slot_empty(self) -> None:
        self.paths.wake_queue.write_text("wake\n", encoding="utf-8")
        line = watch.cycle(
            self.paths, env=self.env, runner=Recorder(responses={"bash -c": completed(0, "")}), emit=True
        )
        self.assertEqual(line, "signal: wake queue")
        self.assertFalse(self.paths.event.exists())
        self.assertIn("signal: wake queue", self.paths.wake.read_text(encoding="utf-8"))

    def test_a_standalone_cycle_publishes_to_the_slot(self) -> None:
        self.paths.wake_queue.write_text("wake\n", encoding="utf-8")
        watch.cycle(self.paths, env=self.env, runner=Recorder(responses={"bash -c": completed(0, "")}))
        self.assertEqual(self.paths.event.read_text(encoding="utf-8"), "signal: wake queue\n")


class RunDaemonTest(ArmTestCase):
    def test_the_daemon_refuses_when_another_arm_holds_the_state(self) -> None:
        self.lease(pid="4000000")
        code = watch.run_daemon(
            self.paths,
            env=dict(self.env),
            sleep=lambda seconds: None,
            stat_reader=lambda pid: "",
            signal_zero=lambda pid: None,
            signal_installer=lambda release: None,
        )
        self.assertEqual(code, 0)
        self.assertEqual(watch.read_lease(self.paths.lease)["pid"], "4000000")

    def test_the_emit_loop_prints_one_line_and_returns(self) -> None:
        self.paths.wake_queue.write_text("wake\n", encoding="utf-8")
        code = watch.run_daemon(
            self.paths,
            env=dict(self.env),
            sleep=lambda seconds: None,
            emit=True,
            signal_installer=lambda release: None,
        )
        self.assertEqual(code, 0)
        self.assertFalse(self.paths.lease.exists(), "the emit shape releases its lease before it ends")
        self.assertEqual(self.paths.generation.read_text(encoding="utf-8").strip(), "1")


class StartStopTest(ArmTestCase):
    def test_start_seats_a_detached_daemon_and_waits_for_its_lease(self) -> None:
        spawned: list[list[str]] = []

        def spawn(argv, **kwargs):  # noqa: ANN001 - the proc.spawn_detached shape
            spawned.append([str(part) for part in argv])
            self.lease(session="none")
            return 4242

        code = watch.start_service(
            self.paths,
            env=dict(self.env),
            runner=Recorder(responses={"systemctl --user show --property=Version": completed(1, "", "no systemd")}),
            sleep=lambda seconds: None,
            spawn=spawn,
        )
        self.assertEqual(code, 0)
        self.assertEqual(len(spawned), 1)
        self.assertTrue(spawned[0][0].endswith("bash"))
        self.assertEqual(Path(spawned[0][1]).name, "syn-watch.sh")
        self.assertEqual(spawned[0][2], "run")

    def test_stop_signals_the_lease_holder_and_proves_it_let_go(self) -> None:
        child = subprocess.Popen(["sleep", "30"])  # noqa: S603,S607 - a real holder, so the proof is real
        try:
            self.lease(pid=str(child.pid))
            self.assertTrue(watch.lease_alive(self.paths))
            code = watch.stop_service(
                self.paths,
                runner=Recorder(responses={"systemctl --user show --property=Version": completed(1, "", "no systemd")}),
                sleep=lambda seconds: None,
            )
            self.assertEqual(code, 0)
            self.assertIsNotNone(child.poll(), "the stop must actually reap the holder")
            self.assertFalse(watch.lease_alive(self.paths))
        finally:
            child.kill()
            child.wait()


class ProcTest(unittest.TestCase):
    def test_starttime_is_field_22(self) -> None:
        stat = "(comm) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 4242 20\n"
        self.assertEqual(proc.proc_starttime(1, stat_reader=lambda pid: stat), "4242")

    def test_a_zombie_is_not_alive(self) -> None:
        stat = "(comm) Z 1 2\n"
        self.assertFalse(proc.pid_alive(1, stat_reader=lambda pid: stat, signal_zero=lambda pid: None))

    def test_a_recycled_pid_is_not_alive(self) -> None:
        stat = "(comm) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 999 20\n"
        self.assertFalse(
            proc.pid_alive(1, "4242", stat_reader=lambda pid: stat, signal_zero=lambda pid: None)
        )

    def test_a_live_pid_matching_its_starttime_is_alive(self) -> None:
        stat = "(comm) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 4242 20\n"
        self.assertTrue(proc.pid_alive(1, "4242", stat_reader=lambda pid: stat, signal_zero=lambda pid: None))

    def test_a_non_numeric_pid_is_not_alive(self) -> None:
        self.assertFalse(proc.pid_alive("none"))


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
