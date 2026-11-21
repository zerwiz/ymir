#!/usr/bin/env python3
"""The proof that a quiet hour is not a dead guardian (plan 337, 2026-11-20).

The hound wrote its heartbeat only inside the findings sink, and `follow_audit` never returns,
so on a box whose audit log carried no `key="ymir-` record the heartbeat stopped at start-up
and the listener snapshot ran once. Here the follow loop runs against a QUIET fixture for a few
ticks, and the heartbeat's mtime must advance and the snapshot must run more than once.

    python3 tests/test_garmr_hound_pulse.py
"""

from __future__ import annotations

import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin" / "ward" / "garmr"))

import common  # noqa: E402
import hound  # noqa: E402

QUIET = (
    'type=SYSCALL msg=audit(1763650000.001:101): arch=c000003e syscall=59 success=yes '
    'pid=1 uid=0 comm="bash" exe="/usr/bin/bash" key=(null)\n'
)


class PulseOnAQuietLog(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state = os.path.join(self.tmp.name, "state")
        self.audit = os.path.join(self.tmp.name, "audit.log")
        Path(self.audit).write_text(QUIET * 50)
        self._old_cfg = hound._HOUND_CFG
        hound._HOUND_CFG = {"tick_seconds": 0.05, "max_lines_per_tick": 4000}

    def tearDown(self):
        hound._HOUND_CFG = self._old_cfg
        self.tmp.cleanup()

    def test_heartbeat_advances_and_snapshot_reruns_with_no_findings(self):
        findings, snaps = [], []
        mtimes = []
        beat = os.path.join(self.state, "hound.heartbeat")

        def snapshot():
            snaps.append(time.time())
            # a fresh socket each time, so the de-duplication passes it on to the sink
            return [{"kind": "listener", "comm": "x", "addr": f"127.0.0.1:{9000 + len(snaps)}", "pid": "1"}]

        pulse = hound.Pulse(findings.extend, self.state, heartbeat_seconds=0.1,
                            poll_seconds=0.1, snapshot=snapshot)

        def tick():
            pulse()
            if os.path.exists(beat):
                mtimes.append(os.stat(beat).st_mtime_ns)

        hound.follow_audit(self.audit, lambda rows: None, on_tick=tick, max_ticks=8)

        self.assertTrue(os.path.exists(beat), "no heartbeat was ever written on a quiet log")
        self.assertGreater(len(set(mtimes)), 1, f"heartbeat mtime never advanced: {mtimes}")
        self.assertGreater(len(snaps), 1, "the listener snapshot ran only once")
        self.assertEqual(len(findings), len(snaps), "each new socket reaches the sink")

    def test_missing_audit_log_still_beats(self):
        pulse = hound.Pulse(lambda rows: None, self.state, heartbeat_seconds=0,
                            poll_seconds=3600, snapshot=lambda: [])
        hound._HOUND_CFG = {"tick_seconds": 0.01}
        hound.follow_audit(os.path.join(self.tmp.name, "absent.log"), lambda r: None,
                           on_tick=pulse, max_ticks=2)
        self.assertTrue(os.path.exists(os.path.join(self.state, "hound.heartbeat")))

    def test_heartbeat_is_throttled(self):
        clock = [1000.0]
        calls = []
        real = common.heartbeat
        common.heartbeat = lambda state: calls.append(clock[0])
        try:
            pulse = hound.Pulse(lambda r: None, self.state, heartbeat_seconds=60,
                                poll_seconds=3600, snapshot=lambda: [], clock=lambda: clock[0])
            for step in range(0, 180, 10):
                clock[0] = 1000.0 + step
                pulse()
        finally:
            common.heartbeat = real
        self.assertEqual(calls, [1000.0, 1060.0, 1120.0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
