"""watch.py — the arm's behaviour, read from the record it writes."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import tempfile
import time
import unittest
import unittest.mock
from pathlib import Path

from ymir_runtime import identity, proc, watch
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

    def test_write_lease_records_the_declared_role(self) -> None:
        self.assertTrue(
            watch.write_lease(self.paths, pid=os.getpid(), mode="daemon", role="rodd", session="none", generation=1)
        )
        self.assertEqual(watch.read_lease(self.paths.lease)["role"], "rodd")

    def test_write_lease_records_the_pins_currency(self) -> None:
        # H6/H8 (plan 257): the lease carries pin=<sha> pin_behind=<n> so a stale pin
        # is a NUMBER any door can read.
        self.assertTrue(
            watch.write_lease(
                self.paths, pid=os.getpid(), mode="daemon", role="counsellor",
                session="none", generation=1, pin="4b09c4a1", pin_behind="162",
            )
        )
        lease = watch.read_lease(self.paths.lease)
        self.assertEqual(lease["pin"], "4b09c4a1")
        self.assertEqual(lease["pin_behind"], "162")

    def test_write_lease_omits_the_pin_when_none_is_given(self) -> None:
        self.assertTrue(
            watch.write_lease(self.paths, pid=os.getpid(), mode="daemon", session="none", generation=1)
        )
        lease = watch.read_lease(self.paths.lease)
        self.assertNotIn("pin", lease)
        self.assertNotIn("pin_behind", lease)

    def test_pin_facts_reads_sha_and_behind_from_git(self) -> None:
        def runner(argv, **kwargs):
            if "rev-parse" in argv:
                return completed(0, "4b09c4a1\n")
            if "rev-list" in argv:
                return completed(0, "162\n")
            return completed(1, "", "not scripted")

        with tempfile.TemporaryDirectory() as pin:
            env = {"YMIR_RUNTIME_DIR": pin}
            self.assertEqual(watch.pin_facts(env, runner=runner), ("4b09c4a1", "162"))

    def test_pin_facts_is_empty_when_no_pin_is_configured(self) -> None:
        env = {"YMIR_HOME": "/tmp/no-home"}
        self.assertEqual(watch.pin_facts(env, runner=lambda argv, **k: completed(0, "")), ("", ""))


    def test_a_lease_with_no_role_reads_unknown(self) -> None:
        self.lease()  # the helper writes no role= field
        self.assertEqual(watch.read_lease(self.paths.lease).get("role", "unknown"), "unknown")

    def test_role_never_overloads_mode(self) -> None:
        self.lease(mode="systemd", role="rodd")
        lease = watch.read_lease(self.paths.lease)
        self.assertEqual(lease["mode"], "systemd")
        self.assertEqual(lease["role"], "rodd")


class HelmIdentityTest(ArmTestCase):
    """Plans 254 B1b/B1c and 257 H8: the lease says whose hand, what for, which machine, which pin."""

    def setUp(self) -> None:
        super().setUp()
        identity.reset_cache()
        self.seat = self.tmp / "ext" / ".ymir-seat"
        self.seat.parent.mkdir(parents=True)
        self.env.update(
            {
                "PI_EXT_HOME": str(self.seat.parent),
                "YMIR_RUNTIME_DIR": str(self.tmp / "no-pin"),
                "YMIR_SEATS_FILE": str(self.tmp / "seats.yaml"),
            }
        )

    def tearDown(self) -> None:
        identity.reset_cache()
        super().tearDown()

    def helm(self, **env: str) -> identity.Helm:
        return identity.resolve({**self.env, **env}, ttl=0)

    def test_every_field_is_written_into_the_lease(self) -> None:
        self.seat.write_text("host=seat-host\nprimary=Hoenir\nrole=counsellor\n", encoding="utf-8")
        (self.tmp / "seats.yaml").write_text(
            "fleet:\n  name: the Ymir fleet\nseats:\n  seat-host:\n    machine:\n      host: seat-host\n",
            encoding="utf-8",
        )
        helm = self.helm(YMIR_ROLE="dev")
        watch.write_lease(
            self.paths, pid=os.getpid(), mode="systemd", role="counsellor", session="none", generation=40, helm=helm
        )
        lease = watch.read_lease(self.paths.lease)
        for key in ("pid", "starttime", "gen", "mode", "role", "session", "heartbeat", "state"):
            self.assertIn(key, lease)
        self.assertEqual(lease["seat"], "Hoenir")
        self.assertEqual(lease["charter"], identity.CHARTER)
        self.assertEqual(lease["host"], "seat-host")
        self.assertEqual(lease["machine"], "seat-host")
        self.assertEqual(lease["fleetrole"], "dev")
        self.assertEqual(lease["fleet"], "the-ymir-fleet")
        self.assertEqual(lease["pin"], "none")
        self.assertEqual(lease["pin_behind"], "none")
        self.assertEqual(lease["identity"], "held")
        self.assertEqual(lease["missing"], "none")

    def test_no_sealed_name_is_rendered_unnamed_never_invented(self) -> None:
        self.seat.write_text("host=seat-host\n", encoding="utf-8")
        helm = self.helm(YMIR_ROLE="dev")
        self.assertEqual(helm.seat, identity.UNNAMED)
        self.assertEqual(helm.identity, "held", "an unnamed seat still holds the helm (Rule 44)")

    def test_the_host_is_the_seat_record_else_this_machine(self) -> None:
        self.seat.write_text("host=elsewhere\n", encoding="utf-8")
        self.assertEqual(self.helm(YMIR_ROLE="dev").host, "elsewhere")
        self.seat.unlink()
        with unittest.mock.patch("socket.gethostname", return_value="newbox.example.net"):
            self.assertEqual(self.helm(YMIR_ROLE="dev").host, "newbox", "a copied lease is re-taken with the NEW host")

    def test_an_unresolvable_fleet_role_stands_read_only_and_names_it(self) -> None:
        self.seat.write_text("host=seat-host\n", encoding="utf-8")
        helm = self.helm()  # no YMIR_ROLE and the temp repo carries no bin/skuld/role.sh
        self.assertEqual(helm.identity, "readonly")
        self.assertEqual(helm.missing, ("fleetrole",))
        self.assertIn("missing=fleetrole", helm.lease_tokens())

    def test_an_unresolvable_host_stands_read_only(self) -> None:
        with unittest.mock.patch("socket.gethostname", return_value=""):
            helm = self.helm(YMIR_ROLE="dev")
        self.assertIn("host", helm.missing)

    def test_the_pin_reports_its_sha_and_how_far_behind(self) -> None:
        pin = self.tmp / "pin"
        git = lambda *a: subprocess.run(["git", *a], cwd=pin, check=True, capture_output=True)  # noqa: E731
        pin.mkdir()
        git("init", "-q", "-b", "main")
        git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "one")
        git("update-ref", "refs/remotes/origin/main", "HEAD")
        git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "two")
        git("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "three")
        git("update-ref", "refs/remotes/origin/main", "HEAD")
        git("reset", "-q", "--hard", "HEAD~2")
        helm = self.helm(YMIR_ROLE="dev", YMIR_RUNTIME_DIR=str(pin))
        self.assertRegex(helm.pin, r"^[0-9a-f]{7,}$")
        self.assertEqual(helm.pin_behind, "2")

    def test_the_lease_tokens_carry_no_whitespace(self) -> None:
        self.seat.write_text("host=seat-host\nprimary=Hœnir\n", encoding="utf-8")
        tokens = self.helm(YMIR_ROLE="dev").lease_tokens().split(" ")
        self.assertTrue(all("=" in token for token in tokens))
        self.assertEqual(identity.render_charter(identity.CHARTER), "planning · mail · the work in hand · dispatch on")


class RoleResolutionTest(ArmTestCase):
    def test_a_declared_role_wins(self) -> None:
        env = dict(self.env, BROKK_ARM_ROLE="rodd")
        self.assertEqual(watch.resolve_role(self.paths, env, session=str(os.getpid())), "rodd")

    def test_no_session_is_unknown(self) -> None:
        self.assertEqual(watch.resolve_role(self.paths, self.env, session="none"), "unknown")
        self.assertEqual(watch.resolve_role(self.paths, self.env, session=""), "unknown")

    def test_the_sidecar_names_the_holder_only_for_its_own_session(self) -> None:
        self.paths.role.write_text("role=rodd session=424242\n", encoding="utf-8")
        self.assertEqual(watch.resolve_role(self.paths, self.env, session="424242"), "rodd")
        # a different live session must not inherit the stale sidecar
        self.assertNotEqual(watch.resolve_role(self.paths, self.env, session=str(os.getpid())), "rodd")

    def test_a_pi_comm_derives_counsellor(self) -> None:
        with unittest.mock.patch.object(watch, "_session_comm", return_value="pi"):
            self.assertEqual(watch.resolve_role(self.paths, self.env, session="424242"), "counsellor")

    def test_a_known_harness_comm_keeps_its_name(self) -> None:
        with unittest.mock.patch.object(watch, "_session_comm", return_value="claude"):
            self.assertEqual(watch.resolve_role(self.paths, self.env, session="424242"), "claude")

    def test_an_unreadable_comm_is_unknown_never_guessed(self) -> None:
        with unittest.mock.patch.object(watch, "_session_comm", return_value=""):
            self.assertEqual(watch.resolve_role(self.paths, self.env, session="424242"), "unknown")


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

    def test_a_terminal_status_line_wakes_once(self) -> None:
        # H3 (plan 257): a worker that writes only `done:` wakes the arm by the record
        # itself — no acclaim, no sweep — and the per-id cursor makes it exactly once.
        (self.paths.state / ".arm.terminal-epoch").write_text("1\n", encoding="utf-8")
        status = self.paths.state / "errand-x.status"
        status.write_text("working: launched\n", encoding="utf-8")
        os.utime(status, (1000.0, 1000.0))
        self.assertEqual(watch.raise_line(self.paths), "")

        status.write_text("working: launched\ndone: opened PR 1\n", encoding="utf-8")
        os.utime(status, (2000.0, 2000.0))
        self.assertEqual(watch.raise_line(self.paths), "signal: errand-x done: opened PR 1")
        self.assertEqual(watch.raise_line(self.paths), "", "a second poll must not re-wake the same line")

    def test_a_newer_terminal_line_is_still_news_once(self) -> None:
        (self.paths.state / ".arm.terminal-epoch").write_text("1\n", encoding="utf-8")
        status = self.paths.state / "errand-x.status"
        status.write_text("done: first\n", encoding="utf-8")
        os.utime(status, (2000.0, 2000.0))
        self.assertEqual(watch.raise_line(self.paths), "signal: errand-x done: first")
        status.write_text("done: first\ndone: merged\n", encoding="utf-8")
        os.utime(status, (3000.0, 3000.0))
        self.assertEqual(watch.raise_line(self.paths), "signal: errand-x done: merged")
        self.assertEqual(watch.raise_line(self.paths), "")

    def test_terminal_lines_older_than_the_epoch_are_seeded_not_raised(self) -> None:
        # the first poll after an upgrade must not re-present every old done: line
        old = self.paths.state / "errand-old.status"
        old.write_text("done: long ago\n", encoding="utf-8")
        os.utime(old, (1000.0, 1000.0))
        self.assertEqual(watch.raise_line(self.paths), "")
        self.assertTrue((self.paths.state / "errand-old.woke").exists())
        self.assertTrue((self.paths.state / ".arm.terminal-epoch").exists())
        fresh = self.paths.state / "errand-new.status"
        fresh.write_text("working: x\ndone: just now\n", encoding="utf-8")
        future = time.time() + 5
        os.utime(fresh, (future, future))
        self.assertEqual(watch.raise_line(self.paths), "signal: errand-new done: just now")
        self.assertEqual(watch.raise_line(self.paths), "")

    def test_blocked_and_working_lines_never_raise_by_the_record(self) -> None:
        (self.paths.state / ".arm.terminal-epoch").write_text("1\n", encoding="utf-8")
        for name, line in (("a", "working: busy"), ("b", "blocked: stuck")):
            status = self.paths.state / f"errand-{name}.status"
            status.write_text(line + "\n", encoding="utf-8")
            os.utime(status, (2000.0, 2000.0))
        self.assertEqual(watch.raise_line(self.paths), "")

    def test_an_acclaimed_line_is_not_woken_twice(self) -> None:
        # eindri-acclaim.sh writes the cursor when it delivers the loud wake
        (self.paths.state / ".arm.terminal-epoch").write_text("1\n", encoding="utf-8")
        status = self.paths.state / "errand-y.status"
        status.write_text("done: opened PR 2\n", encoding="utf-8")
        os.utime(status, (2000.0, 2000.0))
        (self.paths.state / "errand-y.woke").write_text("2000.0\n", encoding="utf-8")
        self.assertEqual(watch.raise_line(self.paths), "")

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
        self.assertTrue(body.startswith("syn-watch[1]{state,mode,role,unit,pid,heartbeat_age,stale_seconds,session,armed,state_dir}:\n"))
        self.assertIn('"down","none"', body)

    def test_the_toon_row_has_ten_fields(self) -> None:
        self.lease(session="none")
        watch.heartbeat_touch(self.paths)
        self.paths.armed.touch()
        row = watch.status_row(self.paths, env=self.env, runner=Recorder())
        self.assertEqual(row.count('"'), 20)


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
        self.assertTrue(
            Path(spawned[0][1]).as_posix().endswith("bin/pi/syn-watch.sh"),
            f"the engine must spawn the door that actually exists; it spawned {spawned[0][1]}",
        )
        self.assertEqual(spawned[0][2], "run")

    def test_the_door_the_engine_spawns_really_exists(self) -> None:
        root = Path(__file__).resolve().parents[3]
        door = root.joinpath(*watch.WATCH_DOOR)
        self.assertTrue(door.is_file(), f"the arm door the engine spawns does not exist: {door}")

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


class CadenceTest(ArmTestCase):
    """The cadence law: one line per transition, a floor, and a ceiling."""

    def test_the_same_line_is_not_repeated_inside_the_floor(self) -> None:
        line = "stale: arm service is down"
        self.assertEqual(watch.brake_line(self.paths, line, now=1000.0), line)
        self.assertEqual(watch.brake_line(self.paths, line, now=1000.0 + 60), "")
        self.assertEqual(
            watch.brake_line(self.paths, line, now=1000.0 + watch.RAISE_FLOOR_SECONDS + 1), line
        )

    def test_a_different_line_passes_immediately(self) -> None:
        self.assertEqual(watch.brake_line(self.paths, "stale: a", now=1000.0), "stale: a")
        self.assertEqual(watch.brake_line(self.paths, "stale: b", now=1000.1), "stale: b")

    def test_the_queue_signal_is_never_braked_here(self) -> None:
        self.assertEqual(watch.brake_line(self.paths, "signal: wake queue", now=1000.0), "signal: wake queue")
        self.assertEqual(watch.brake_line(self.paths, "signal: wake queue", now=1000.1), "signal: wake queue")

    def test_the_hourly_ceiling_reports_its_own_rate_once(self) -> None:
        raised = [watch.brake_line(self.paths, f"stale: fault {n}", now=1000.0 + n) for n in range(4)]
        self.assertEqual(raised[:3], ["stale: fault 0", "stale: fault 1", "stale: fault 2"])
        self.assertEqual(raised[3], "check: the arm has raised 3 lines in the last hour")
        self.assertEqual(watch.brake_line(self.paths, "stale: fault 9", now=1000.0 + 10), "")


if __name__ == "__main__":  # pragma: no cover
    unittest.main()


class ErrandWakeTest(ArmTestCase):
    """The errands the house dispatched: a dead pane, a false done, a stalled worker."""

    def herdr(self, panes: dict[str, str] | None) -> Recorder:
        if panes is None:
            return Recorder(responses={"herdr agent list": completed(1, "", "no server")})
        body = {"result": {"agents": [{"pane_id": p, "agent_status": s} for p, s in panes.items()]}}
        return Recorder(responses={"herdr agent list": completed(0, json.dumps(body))})

    def errand(self, seat_id: str, status: str, *, age: float = 0, **meta: str) -> None:
        fields = {"id": seat_id, "backend": "herdr", "mode": "batch"}
        fields.update(meta)
        meta_file = self.paths.state / f"{seat_id}.meta"
        meta_file.write_text("".join(f"{k}={v}\n" for k, v in fields.items()), encoding="utf-8")
        status_file = self.paths.state / f"{seat_id}.status"
        status_file.write_text(status + "\n", encoding="utf-8")
        stamp = time.time() - age
        os.utime(meta_file, (stamp, stamp))
        os.utime(status_file, (stamp, stamp))

    def repo(self, *, commits: int, push: bool, branch: str = "eindri/probe") -> Path:
        origin = self.tmp / "origin.git"
        work = self.tmp / "work"
        run = lambda *a, cwd=None: subprocess.run(a, cwd=cwd, check=True, capture_output=True)  # noqa: E731
        run("git", "init", "-q", "--bare", "-b", "main", str(origin))
        run("git", "init", "-q", "-b", "main", str(work))
        git = ("git", "-c", "user.name=t", "-c", "user.email=t@example.org")
        run(*git, "commit", "-q", "--allow-empty", "-m", "base", cwd=work)
        run("git", "remote", "add", "origin", str(origin), cwd=work)
        run("git", "push", "-q", "origin", "main", cwd=work)
        run("git", "checkout", "-q", "-b", branch, cwd=work)
        for n in range(commits):
            run(*git, "commit", "-q", "--allow-empty", "-m", f"work {n}", cwd=work)
        if push:
            run("git", "push", "-q", "origin", branch, cwd=work)
        return work

    def test_a_pane_with_no_agent_is_stale_once(self) -> None:
        self.errand("probe", "working: busy", window="wX:p1")
        runner = self.herdr({"wA:p1": "working"})
        self.assertEqual(
            watch.raise_line(self.paths, runner=runner),
            "stale: errand probe has no agent in wX:p1 (status: working: busy)",
        )
        self.assertEqual(watch.raise_line(self.paths, runner=runner), "", "the same fact never wakes twice")

    def test_an_ended_errand_with_no_agent_is_quiet(self) -> None:
        self.errand("probe", "failed: gave up", window="wX:p1")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")

    def test_a_silent_herdr_judges_no_worker(self) -> None:
        self.errand("probe", "working: busy", window="wX:p1")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr(None)), "")

    def test_a_healthy_errand_is_quiet(self) -> None:
        self.errand("probe", "working: busy", window="wX:p1")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({"wX:p1": "working"})), "")

    def test_an_errand_older_than_the_horizon_is_not_judged(self) -> None:
        self.errand("probe", "working: busy", age=watch.DEFAULT_ERRAND_HORIZON_SECONDS + 60, window="wX:p1")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")

    def test_a_quiet_idle_worker_is_stalled(self) -> None:
        self.errand("probe", "working: thinking", age=45 * 60, window="wX:p1")
        runner = self.herdr({"wX:p1": "idle"})
        self.assertEqual(
            watch.raise_line(self.paths, runner=runner), "stale: errand probe has said nothing for 45 minutes"
        )
        self.assertEqual(watch.raise_line(self.paths, runner=runner), "")

    def test_a_quiet_but_working_agent_is_not_stalled(self) -> None:
        self.errand("probe", "working: thinking", age=45 * 60, window="wX:p1")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({"wX:p1": "working"})), "")

    def test_a_done_over_an_empty_branch_is_a_check(self) -> None:
        (self.paths.state / ".arm.errand-epoch").write_text("1\n", encoding="utf-8")
        work = self.repo(commits=0, push=False)
        self.errand("probe", "done: committed on eindri/probe", worktree=str(work))
        runner = self.herdr({})
        self.assertEqual(
            watch.raise_line(self.paths, runner=runner), "check: errand probe false-done — reported done with nothing committed"
        )
        self.assertEqual(watch.raise_line(self.paths, runner=runner), "")

    def test_a_batch_done_with_commits_is_quiet(self) -> None:
        (self.paths.state / ".arm.errand-epoch").write_text("1\n", encoding="utf-8")
        work = self.repo(commits=1, push=False)
        self.errand("probe", "done: committed", worktree=str(work), mode="batch")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")

    def test_a_lone_done_with_no_branch_pushed_is_a_check(self) -> None:
        (self.paths.state / ".arm.errand-epoch").write_text("1\n", encoding="utf-8")
        work = self.repo(commits=1, push=False)
        self.errand("probe", "done: opened PR", worktree=str(work), mode="pr")
        self.assertEqual(
            watch.raise_line(self.paths, runner=self.herdr({})),
            "check: errand probe false-done — reported done with no branch pushed",
        )

    def test_a_lone_done_pushed_is_quiet(self) -> None:
        (self.paths.state / ".arm.errand-epoch").write_text("1\n", encoding="utf-8")
        work = self.repo(commits=2, push=True)
        self.errand("probe", "done: opened PR", worktree=str(work), mode="pr")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")

    def test_a_done_older_than_the_epoch_is_seeded_not_judged(self) -> None:
        work = self.repo(commits=0, push=False)
        self.errand("probe", "done: long ago", age=3600, worktree=str(work))
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")

    def test_errand_lines_pass_the_hourly_brake(self) -> None:
        for n in range(watch.RAISE_HOURLY_CEILING + 2):
            line = f"stale: errand e{n} has no agent in w:p1 (status: working: x)"
            self.assertEqual(watch.brake_line(self.paths, line), line)

    def test_a_full_slot_holds_the_next_raise(self) -> None:
        self.paths.event.write_text("signal: undelivered\n", encoding="utf-8")
        (self.paths.state / "42.signal").write_text("", encoding="utf-8")
        watch.cycle(self.paths, env=self.env, runner=self.herdr({}), helm=identity.Helm())
        self.assertTrue((self.paths.state / "42.signal").exists(), "a trigger is not consumed into a full slot")

    def test_a_false_done_is_checked_before_it_is_signalled(self) -> None:
        watch.raise_line(self.paths, runner=self.herdr({}))  # the first scan stamps both epochs
        time.sleep(0.05)
        work = self.repo(commits=0, push=False)
        self.errand("probe", "done: committed", worktree=str(work))
        runner = self.herdr({})
        self.assertEqual(
            watch.raise_line(self.paths, runner=runner), "check: errand probe false-done — reported done with nothing committed"
        )
        # the status now reads false-done: the false claim is never celebrated as a finish
        self.assertEqual(watch.raise_line(self.paths, runner=runner), "")
        last = (self.paths.state / "probe.status").read_text(encoding="utf-8").splitlines()[-1]
        self.assertTrue(last.startswith("false-done: "), last)


class HonestReportTest(ArmTestCase):
    """Plan 339.2: a report counts only with its record, and the arm checks the record."""

    herdr = ErrandWakeTest.herdr
    errand = ErrandWakeTest.errand
    repo = ErrandWakeTest.repo

    def report(self, seat_id: str, body: str) -> None:
        shelf = self.paths.state / "eindri-reports"
        shelf.mkdir(exist_ok=True)
        (shelf / f"{seat_id}.md").write_text(body, encoding="utf-8")

    def head(self, work: Path) -> str:
        return subprocess.run(
            ["git", "-C", str(work), "rev-parse", "--short", "HEAD"], capture_output=True, text=True, check=True
        ).stdout.strip()

    def status_tail(self, seat_id: str) -> str:
        return (self.paths.state / f"{seat_id}.status").read_text(encoding="utf-8").splitlines()[-1]

    def setUp(self) -> None:
        super().setUp()
        (self.paths.state / ".arm.errand-epoch").write_text("1\n", encoding="utf-8")

    def test_parse_record_reads_the_block_and_a_bare_oneline(self) -> None:
        rec = watch.parse_record("## Record\n- commit: `abc1234 fix it`\n- where: pushed\n- machine: host-a\n")
        self.assertEqual((rec["sha"], rec["where"], rec["machine"]), ("abc1234", "pushed", "host-a"))
        self.assertEqual(watch.parse_record("done.\n\n  9f8e7d6c a commit subject\n")["sha"], "9f8e7d6c")
        self.assertEqual(watch.parse_record("where: not pushed\n")["where"], "local")
        self.assertEqual(watch.parse_record("Nothing committed: a scout\n").get("nothing"), "1")

    def test_a_true_record_is_quiet(self) -> None:
        work = self.repo(commits=1, push=False, branch="eindri/probe")
        self.errand("probe", "done: committed", worktree=str(work), mode="batch")
        self.report("probe", f"## Record\ncommit: {self.head(work)} work 0\nbranch: eindri/probe\nwhere: local only\n")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")
        self.assertTrue(self.status_tail("probe").startswith("done:"))

    def test_a_sha_the_repo_does_not_hold_is_false_done(self) -> None:
        work = self.repo(commits=1, push=False, branch="eindri/probe")
        self.errand("probe", "done: committed", worktree=str(work), mode="batch")
        self.report("probe", "## Record\ncommit: deadbeef1 invented\nwhere: local only\n")
        line = watch.raise_line(self.paths, runner=self.herdr({}))
        self.assertEqual(line, f"check: errand probe false-done — reported done with commit deadbeef1, which {work} does not hold")
        self.assertTrue(self.status_tail("probe").startswith("false-done: "), "the status names it by name")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "", "one wake per claim")

    def test_the_base_commit_pasted_as_the_record_is_nothing_committed(self) -> None:
        work = self.repo(commits=0, push=False, branch="eindri/probe")
        self.errand("probe", "done: committed", worktree=str(work), mode="batch")
        self.report("probe", f"{self.head(work)} base\n")
        self.assertIn("nothing committed (commit", watch.raise_line(self.paths, runner=self.herdr({})))

    def test_a_claim_of_pushed_that_origin_lacks_is_false_done(self) -> None:
        work = self.repo(commits=1, push=False, branch="eindri/probe")
        self.errand("probe", "done: committed", worktree=str(work), mode="batch")
        self.report("probe", f"commit: {self.head(work)}\nwhere: pushed\n")
        self.assertEqual(
            watch.raise_line(self.paths, runner=self.herdr({})),
            "check: errand probe false-done — reported done with a claim of pushed, but origin holds no refs/heads/eindri/probe",
        )

    def test_a_claim_of_pushed_that_origin_holds_is_quiet(self) -> None:
        work = self.repo(commits=2, push=True, branch="eindri/probe")
        self.errand("probe", "done: opened PR", worktree=str(work), mode="pr")
        self.report("probe", f"commit: {self.head(work)}\nwhere: pushed\n")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")

    def test_a_claim_of_parked_needs_the_parking_ref(self) -> None:
        work = self.repo(commits=1, push=False, branch="eindri/probe")
        self.errand("probe", "done: parked", worktree=str(work), mode="batch")
        self.report("probe", f"commit: {self.head(work)}\nwhere: parked\n")
        self.assertIn("origin holds no refs/parked/probe", watch.raise_line(self.paths, runner=self.herdr({})))
        subprocess.run(["git", "-C", str(work), "push", "-q", "origin", "HEAD:refs/parked/probe2"], check=True)
        self.errand("probe2", "done: parked", worktree=str(work), mode="batch")
        self.report("probe2", f"commit: {self.head(work)}\nbranch: eindri/probe\nwhere: parked\n")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")

    def test_a_commit_on_another_machine_is_asked_there(self) -> None:
        self.errand("probe", "done: committed in the other repo", mode="batch")
        self.report("probe", "commit: 0123abcd x\nrepo: /srv/other\nbranch: eindri/probe\nmachine: host-far\nwhere: local\n")
        ssh = Recorder(responses={
            "herdr agent list": completed(0, json.dumps({"result": {"agents": []}})),
            "ssh -o BatchMode=yes -o ConnectTimeout=5 host-far git -C /srv/other cat-file": completed(1, "", "bad object"),
        })
        self.assertEqual(
            watch.raise_line(self.paths, runner=ssh),
            "check: errand probe false-done — reported done with commit 0123abcd, which /srv/other on host-far does not hold",
        )

    def test_an_unreachable_machine_proves_nothing(self) -> None:
        self.errand("probe", "done: committed far away", mode="batch")
        self.report("probe", "commit: 0123abcd x\nrepo: /srv/other\nmachine: host-far\n")
        ssh = Recorder(responses={"ssh ": completed(255, "", "no route")})
        self.assertEqual(watch.raise_line(self.paths, runner=ssh), "")

    def test_a_scout_that_committed_nothing_is_honest(self) -> None:
        work = self.repo(commits=0, push=False, branch="eindri/probe")
        self.errand("probe", "done: the report is filed", worktree=str(work), mode="scout")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")

    def test_a_report_that_says_nothing_committed_is_honest(self) -> None:
        work = self.repo(commits=0, push=False, branch="eindri/probe")
        self.errand("probe", "done: found nothing to change", worktree=str(work), mode="batch")
        self.report("probe", "Nothing committed: the fault was already mended on main.\n")
        self.assertEqual(watch.raise_line(self.paths, runner=self.herdr({})), "")


class QuestionWakeTest(ArmTestCase):
    """Plan 339.3: a question an errand filed and nobody answered."""

    def ask(self, seat_id: str, text: str, *, age: float, pane: str = "wQ:p1") -> Path:
        shelf = self.paths.questions
        shelf.mkdir(exist_ok=True)
        question = shelf / f"{seat_id}.md"
        question.write_text(text, encoding="utf-8")
        (self.paths.state / f"{seat_id}.meta").write_text(f"id={seat_id}\nseat_pane={pane}\n", encoding="utf-8")
        status = self.paths.state / f"{seat_id}.status"
        status.write_text("needs-decision: which way?\n", encoding="utf-8")
        stamp = time.time() - age
        for path in (question, status):
            os.utime(path, (stamp, stamp))
        return question

    def hotline(self, rc: int = 0) -> Recorder:
        return Recorder(responses={"send.sh": completed(rc, "", "")})

    def door(self) -> None:
        door = self.paths.root / "bin" / "notify" / "send.sh"
        door.parent.mkdir(parents=True, exist_ok=True)
        door.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        door.chmod(0o755)

    def test_a_fresh_question_is_quiet(self) -> None:
        self.ask("probe", "Which branch?\n", age=5 * 60)
        self.assertEqual(watch.raise_line(self.paths, runner=self.hotline()), "")

    def test_a_question_unanswered_past_fifteen_minutes_wakes_the_helm_once(self) -> None:
        question = self.ask("probe", "# Which branch should I base on?\n", age=20 * 60)
        line = watch.raise_line(self.paths, runner=self.hotline())
        self.assertEqual(
            line, f"check: errand probe question unanswered for 20 minutes ({question}): Which branch should I base on?"
        )
        self.assertEqual(watch.raise_line(self.paths, runner=self.hotline()), "", "one wake per question")

    def test_an_answer_line_in_the_file_clears_it(self) -> None:
        self.ask("probe", "Which branch?\n\nanswer: base on main\n", age=20 * 60)
        self.assertEqual(watch.raise_line(self.paths, runner=self.hotline()), "")

    def test_a_send_into_the_pane_after_the_question_clears_it(self) -> None:
        question = self.ask("probe", "Which branch?\n", age=20 * 60)
        log = self.paths.message_log
        log.parent.mkdir(parents=True, exist_ok=True)
        row = {"epoch": int(question.stat().st_mtime) + 60, "from": "the helm", "to": "wQ:p1", "text": "main"}
        log.write_text(json.dumps(row) + "\n", encoding="utf-8")
        self.assertEqual(watch.raise_line(self.paths, runner=self.hotline()), "")

    def test_the_worker_writing_on_clears_it(self) -> None:
        self.ask("probe", "Which branch?\n", age=20 * 60)
        with (self.paths.state / "probe.status").open("a", encoding="utf-8") as handle:
            handle.write("working: carrying on with main\n")
        self.assertEqual(watch.raise_line(self.paths, runner=self.hotline()), "")

    def test_a_moved_question_is_answered(self) -> None:
        question = self.ask("probe", "Which branch?\n", age=20 * 60)
        (self.paths.questions / "answered").mkdir()
        question.rename(self.paths.questions / "answered" / "probe.md")
        self.assertEqual(watch.raise_line(self.paths, runner=self.hotline()), "")

    def test_past_an_hour_it_reaches_the_operator_once(self) -> None:
        self.door()
        question = self.ask("probe", "Which branch?\n", age=70 * 60)
        runner = self.hotline()
        self.assertTrue(watch.raise_line(self.paths, runner=runner).startswith("check: errand probe question unanswered for 70 minutes ("))
        self.assertEqual(
            watch.raise_line(self.paths, runner=runner),
            "check: errand probe question unanswered for 70 minutes — sent to the operator",
        )
        sent = [c for c in runner.calls if c[0].endswith("send.sh")]
        self.assertEqual(len(sent), 1)
        argv = sent[0]
        self.assertEqual(argv[argv.index("--severity") + 1], "HIGH")
        self.assertIn(f"question:probe:{int(question.stat().st_mtime)}", argv)
        self.assertGreaterEqual(argv.count("--button"), 2)
        self.assertEqual(watch.raise_line(self.paths, runner=runner), "", "once to the operator")

    def test_an_answer_before_the_hour_spares_the_operator(self) -> None:
        self.door()
        question = self.ask("probe", "Which branch?\n", age=20 * 60)
        runner = self.hotline()
        watch.raise_line(self.paths, runner=runner)
        with question.open("a", encoding="utf-8") as handle:
            handle.write("answer: main\n")
        stamp = time.time() - 70 * 60
        os.utime(question, (stamp, stamp))
        self.assertEqual(watch.raise_line(self.paths, runner=runner), "")
        self.assertFalse([c for c in runner.calls if c[0].endswith("send.sh")])

    def test_a_question_past_the_horizon_is_left_to_the_ledger(self) -> None:
        self.ask("probe", "old\n", age=watch.DEFAULT_ERRAND_HORIZON_SECONDS + 60)
        self.assertEqual(watch.raise_line(self.paths, runner=self.hotline()), "")

    def test_question_lines_pass_the_hourly_brake(self) -> None:
        line = "check: errand e1 question unanswered for 20 minutes (x)"
        for _ in range(watch.RAISE_HOURLY_CEILING + 2):
            self.assertEqual(watch.brake_line(self.paths, line), line)


class EagerEpochTest(ArmTestCase):
    def test_the_first_done_a_fresh_home_writes_is_raised(self) -> None:
        # Stamped lazily, the epoch was the moment the first terminal line was MET, so
        # that line always read as older than the epoch and was seeded in silence.
        self.assertEqual(watch.raise_line(self.paths), "")
        time.sleep(0.05)
        (self.paths.state / "first.status").write_text("done: the first ever\n", encoding="utf-8")
        self.assertEqual(watch.raise_line(self.paths), "signal: first done: the first ever")
