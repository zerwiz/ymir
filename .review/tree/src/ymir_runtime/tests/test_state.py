"""state/ — locks (Gleipnir) · runes · envelopes · queues, beside their modules.

These are the UNIT proofs: the lock's own precedence and truth, the ledger's
chain, the queue's sequence and keys. The PARITY proofs (shim vs the shell it
replaced) live in test_state_parity.py.
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from ymir_runtime.state import envelope, lock, queue, runes


def _clean_env(**extra: str) -> dict[str, str]:
    base = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": os.environ.get("HOME", "/tmp"),
    }
    base.update(extra)
    return base


class StateDirTest(unittest.TestCase):
    def test_override_wins(self) -> None:
        env = _clean_env(BROKK_STATE_OVERRIDE="/tmp/override-state", YMIR_HOME="/tmp/home")
        self.assertEqual(lock.state_dir(env), Path("/tmp/override-state"))

    def test_hoard_state_from_home(self) -> None:
        env = _clean_env(YMIR_HOME="/tmp/home")
        self.assertEqual(lock.state_dir(env), Path("/tmp/home/state"))

    def test_ymir_state_dir_wins_over_home(self) -> None:
        env = _clean_env(YMIR_HOME="/tmp/home", YMIR_STATE_DIR="/tmp/explicit")
        self.assertEqual(lock.state_dir(env), Path("/tmp/explicit"))

    def test_eindri_home_owns_its_state(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp) / "eindri"
            (home / "data").mkdir(parents=True)
            (home / "data" / "eindri-home").write_text("", encoding="utf-8")
            env = _clean_env(BROKK_HOME=str(home), YMIR_HOME="/tmp/main")
            self.assertTrue(lock.is_eindri_home(env))
            self.assertEqual(lock.state_dir(env), home / "state")
            self.assertEqual(lock.lock_path(env), home / "state" / ".lock")

    def test_primary_lock_is_machine_global(self) -> None:
        env = _clean_env(
            YMIR_HOME="/tmp/home",
            XDG_STATE_HOME="/tmp/state-root",
        )
        self.assertEqual(lock.lock_path(env), Path("/tmp/state-root/ymir/brokk.lock"))
        self.assertEqual(lock.pointer_path(env), Path("/tmp/home/state/.lock-path"))

    def test_machine_state_override(self) -> None:
        env = _clean_env(YMIR_HOME="/tmp/home", BROKK_MACHINE_STATE_DIR="/tmp/mach")
        self.assertEqual(lock.lock_path(env), Path("/tmp/mach/brokk.lock"))


class PidTruthTest(unittest.TestCase):
    def test_self_is_alive(self) -> None:
        self.assertTrue(lock.pid_alive(os.getpid()))

    def test_recycled_pid_reads_as_dead(self) -> None:
        self.assertFalse(lock.pid_alive(os.getpid(), "0"))

    def test_nonsense_pid_is_dead(self) -> None:
        self.assertFalse(lock.pid_alive("not-a-pid"))
        self.assertFalse(lock.pid_alive(""))

    def test_vanished_process_is_dead(self) -> None:
        child = subprocess.Popen(["sleep", "60"])
        try:
            self.assertTrue(lock.pid_alive(child.pid))
        finally:
            child.terminate()
            child.wait()
        self.assertFalse(lock.pid_alive(child.pid))

    def test_starttime_is_the_proc_field(self) -> None:
        rest = lock.proc_stat_rest(os.getpid())
        self.assertIsNotNone(rest)
        fields = rest.split()
        self.assertEqual(lock.proc_starttime(os.getpid()), fields[19])


class LockCycleTest(unittest.TestCase):
    def _env(self, tmp: str) -> dict[str, str]:
        return _clean_env(
            YMIR_HOME=str(Path(tmp) / "home"),
            BROKK_STATE_OVERRIDE=str(Path(tmp) / "state"),
            BROKK_MACHINE_STATE_DIR=str(Path(tmp) / "machine"),
            BROKK_SESSION_PID=str(os.getpid()),
        )

    def test_acquire_release_cycle(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            env = self._env(tmp)
            self.assertTrue(lock.acquire(env, shell_pid=os.getpid()))
            self.assertEqual(lock.lock_owner(env), str(os.getpid()))
            lock_file = lock.lock_path(env)
            self.assertEqual(lock_file.read_text(encoding="utf-8").strip(), str(os.getpid()))
            self.assertEqual(lock.proc_starttime(os.getpid()),
                             (Path(str(lock_file) + ".starttime")).read_text(encoding="utf-8").strip())
            pointer = lock.pointer_path(env)
            self.assertEqual(pointer.read_text(encoding="utf-8").strip(), str(lock_file))
            self.assertTrue(lock.release(env, shell_pid=os.getpid()))
            self.assertFalse(lock_file.exists())
            self.assertFalse(pointer.exists())
            self.assertEqual(lock.lock_owner(env), "")

    def test_live_other_owner_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            env = self._env(tmp)
            lock_file = lock.lock_path(env)
            lock_file.parent.mkdir(parents=True, exist_ok=True)
            other = subprocess.Popen(["sleep", "60"])
            try:
                lock_file.write_text(f"{other.pid}\n", encoding="utf-8")
                self.assertFalse(lock.acquire(env, shell_pid=os.getpid()))
                self.assertEqual(lock.lock_owner(env), str(other.pid))
            finally:
                other.terminate()
                other.wait()

    def test_reap_removes_only_the_dead(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            env = self._env(tmp)
            lock_file = lock.lock_path(env)
            lock_file.parent.mkdir(parents=True, exist_ok=True)
            lock_file.write_text("999999\n", encoding="utf-8")
            (Path(str(lock_file) + ".starttime")).write_text("1\n", encoding="utf-8")
            reaped = lock.reap(env)
            self.assertEqual(reaped, ["999999"])
            self.assertFalse(lock_file.exists())
            self.assertFalse(Path(str(lock_file) + ".starttime").exists())

    def test_reap_keeps_a_live_owner(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            env = self._env(tmp)
            lock_file = lock.lock_path(env)
            lock_file.parent.mkdir(parents=True, exist_ok=True)
            lock_file.write_text(f"{os.getpid()}\n", encoding="utf-8")
            self.assertEqual(lock.reap(env), [])
            self.assertTrue(lock_file.exists())

    def test_acquire_clears_a_stale_lock(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            env = self._env(tmp)
            lock_file = lock.lock_path(env)
            lock_file.parent.mkdir(parents=True, exist_ok=True)
            lock_file.write_text("999999\n", encoding="utf-8")
            self.assertTrue(lock.acquire(env, shell_pid=os.getpid()))
            self.assertEqual(lock.lock_owner(env), str(os.getpid()))


class RunesTest(unittest.TestCase):
    def test_escape_matches_the_shell(self) -> None:
        self.assertEqual(runes.escape('a"b\\c\nd\re\tf'), 'a\\"b\\\\c\\nd\\re\\tf')

    def test_append_chains_and_verifies(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ledger = Path(tmp) / "runes_audit.md"
            first = runes.append(
                "alpha", "first", "hello", ledger=ledger, lock=Path(tmp) / "runes.lock",
                timestamp="2026-01-01T00:00:00Z",
            )
            second = runes.append(
                "beta", "second", "world", order="W1", realm="work",
                ledger=ledger, lock=Path(tmp) / "runes.lock",
                timestamp="2026-01-01T00:00:01Z",
            )
            self.assertEqual(first.prev, "")
            self.assertEqual(second.prev, first.checksum)
            text = ledger.read_text(encoding="utf-8")
            self.assertTrue(text.startswith(runes.HEAD))
            self.assertTrue(text.endswith("\n"))
            ok, tip = runes.verify(ledger)
            self.assertTrue(ok, tip)
            self.assertEqual(tip, second.checksum)
            self.assertEqual(runes.last_checksum(ledger), second.checksum)

    def test_head_is_written_once(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ledger = Path(tmp) / "runes_audit.md"
            runes.ensure_head(ledger)
            body = ledger.read_text(encoding="utf-8")
            runes.ensure_head(ledger)
            self.assertEqual(ledger.read_text(encoding="utf-8"), body)

    def test_existing_entries_are_never_rewritten(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ledger = Path(tmp) / "runes_audit.md"
            runes.append("a", "one", "x", ledger=ledger, lock=Path(tmp) / "l", timestamp="t1")
            before = ledger.read_text(encoding="utf-8")
            runes.append("b", "two", "y", ledger=ledger, lock=Path(tmp) / "l", timestamp="t2")
            after = ledger.read_text(encoding="utf-8")
            self.assertTrue(after.startswith(before))
            self.assertGreater(len(after), len(before))

    def test_tamper_breaks_the_chain(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ledger = Path(tmp) / "runes_audit.md"
            runes.append("a", "one", "x", ledger=ledger, lock=Path(tmp) / "l", timestamp="t1")
            text = ledger.read_text(encoding="utf-8").replace('"message":"x"', '"message":"z"')
            ledger.write_text(text, encoding="utf-8")
            ok, _ = runes.verify(ledger)
            self.assertFalse(ok)


class QueueTest(unittest.TestCase):
    def _queue(self, tmp: str) -> queue.WakeQueue:
        return queue.WakeQueue.resolve(path=Path(tmp) / ".wake-queue")

    def test_append_bumps_the_sequence(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            q = self._queue(tmp)
            first = q.append("check", "k1", "p1", epoch=100)
            second = q.append("signal", "k2", "p2", epoch=101)
            self.assertEqual((first.seq, second.seq), (1, 2))
            self.assertEqual(q.pending(), 2)
            self.assertEqual(q.seq_path.read_text(encoding="utf-8").strip(), "2")
            self.assertEqual(
                q.path.read_text(encoding="utf-8"),
                "100\t1\tcheck\tk1\tp1\n101\t2\tsignal\tk2\tp2\n",
            )

    def test_fields_are_cleaned_like_the_shell(self) -> None:
        self.assertEqual(queue.clean_field("a\tb\r\nc"), "a b  c")
        with tempfile.TemporaryDirectory() as tmp:
            q = self._queue(tmp)
            wake = q.append("check", "k\t1", "p\nq", epoch=7)
            self.assertEqual(wake.key, "k 1")
            self.assertEqual(wake.payload, "p q")
            self.assertEqual(len(q.path.read_text(encoding="utf-8").splitlines()), 1)

    def test_assume_locked_appends_without_its_own_lock(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            q = self._queue(tmp)
            wake = q.append("heartbeat", "watcher", "beat", epoch=5, assume_locked=True)
            self.assertEqual(wake.seq, 1)
            self.assertFalse(q.lock_path.exists())

    def test_queued_keys_are_distinct_and_ordered(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            q = self._queue(tmp)
            q.append("check", "a", "1", epoch=1)
            q.append("check", "b", "2", epoch=2)
            q.append("check", "a", "3", epoch=3)
            q.append("stale", "a", "4", epoch=4)
            self.assertEqual(q.queued_keys("check"), ["a", "b"])
            self.assertEqual(q.queued_keys("stale"), ["a"])

    def test_parse_and_dedupe(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            q = self._queue(tmp)
            q.append("signal", "s", "1", epoch=1)
            q.append("heartbeat", "h", "1", epoch=2)
            q.append("heartbeat", "h", "2", epoch=3)
            wakes = q.read()
            self.assertEqual(len(queue.dedupe(wakes)), 2)

    def test_unknown_kind_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                self._queue(tmp).append("bogus", "k", "p")


class EnvelopeTest(unittest.TestCase):
    def test_meta_round_trip_and_atomic_write(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "seat.meta"
            record = envelope.Envelope(kind="seat", payload={"launched": "1", "kind": "ship"})
            record.write_meta(path)
            self.assertEqual(path.read_text(encoding="utf-8"), "launched=1\nkind=ship\n")
            back = envelope.Envelope.read_meta(path, kind="seat")
            self.assertEqual(back.payload, {"launched": "1", "kind": "ship"})
            self.assertEqual(list(Path(tmp).iterdir()), [path])

    def test_json_round_trip(self) -> None:
        record = envelope.Envelope.of("wake", key="k", payload_text="p")
        back = envelope.Envelope.from_json(record.to_json())
        self.assertEqual(back.kind, "wake")
        self.assertEqual(back.payload, {"key": "k", "payload_text": "p"})


if __name__ == "__main__":  # pragma: no cover
    unittest.main()
