#!/usr/bin/env python3
"""The proofs that an alert reaches an AGENT as a turn — not only a bot post nobody answers (2026-11-21).

At the operator's word: *"The cron are still not triggering the chat … We must be sending in to the chat
wrong."* Measured: `bin/notify/send.sh` posted straight to the Bot API (a bot's own post never reaches any
session as a turn), its arm leg woke only the LOCAL machine's queue, the hound's CRITICAL skipped dedupe and
said the same line every 15 minutes for 9 hours, and a failing cron row said "no output".

Each proof runs the REAL door inside a throwaway root: the door, the home resolver and the button grammar
are copied in; Runes, the desktop, the pocket and the communications record are stand-ins that only log;
the arm wire (`bin/fleet/arm-send.sh`) is a fake that logs which machine it was asked to reach and fails
for the machines the test names dead; Telegram is a local HTTP server. Nothing real rings.

    python3 bin/notify/tests/test_alert_owner_road.py
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import threading
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
ME = subprocess.run(["hostname", "-s"], capture_output=True, text=True).stdout.strip().lower()


def make_server(calls: list) -> ThreadingHTTPServer:
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *a):
            pass

        def do_POST(self):
            n = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(n).decode("utf-8", "replace") if n else ""
            if self.path.endswith("/sendMessage"):
                calls.append({k: v[0] for k, v in urllib.parse.parse_qs(raw).items()})
            body = b'{"ok":true}'
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


def stub(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body)
    path.chmod(0o755)


class Case(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="alert-owner-road-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.calls: list = []
        srv = make_server(self.calls)
        self.addCleanup(srv.server_close)
        self.addCleanup(srv.shutdown)

        root = self.tmp / "root"
        for rel in ("bin/notify/send.sh", "bin/vault/hoard-lib.sh",
                    "bin/notify/telegram-buttons.sh", "bin/notify/telegram-buttons.mjs"):
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / rel, root / rel)
        log = self.tmp / "legs.log"
        self.arm_log = self.tmp / "arm.log"
        quiet = f'#!/bin/sh\nprintf "%s\\n" "$0 $*" >>"{log}"\nexit 0\n'
        for rel in ("bin/vault/hodd.sh", "bin/records/runes-append.sh",
                    "systems/snotra/services/tts-lease/ymir-say.sh"):
            stub(root / rel, quiet)
        for rel in ("bin/ward/garmr/notify.py", "bin/records/comms.py"):
            stub(root / rel, "import sys\nsys.exit(0)\n")
        # The fake arm wire: it logs <machine> TAB <line>, and refuses a machine named dead (exit 3, as the
        # real door does when nobody holds the arm there).
        stub(root / "bin/fleet/arm-send.sh",
             f'#!/bin/sh\ncase ",$FAKE_ARM_DEAD," in *",$1,"*) exit 3 ;; esac\n'
             f'printf "%s\\t%s\\n" "$1" "$2" >>"{self.arm_log}"\nexit 0\n')
        self.door = root / "bin/notify/send.sh"

        self.home = self.tmp / "home"
        (self.home / "hodd/data").mkdir(parents=True)
        (self.home / "state").mkdir(parents=True)
        (self.home / "hodd/data/fleet.json").write_text(json.dumps({"heart": "heart-h", "hosts": {}}))
        self.env = {
            **{k: v for k, v in os.environ.items()
               if not k.startswith(("TELEGRAM_", "SKIRNIR_TELEGRAM_", "YMIR_NOTIFY_", "YMIR_STATE_DIR"))},
            "YMIR_HOME": str(self.home),
            "TELEGRAM_BOT_TOKEN": "test-token",
            "TELEGRAM_OWNER_ID": "4242",
            "TELEGRAM_API_BASE": f"http://127.0.0.1:{srv.server_address[1]}",
            "YMIR_NOTIFY_VAULT": "0",
            "YMIR_NOTIFY_FLUSH_SCHEDULE": "0",
        }
        self.state = self.home / "state/notify/state.json"

    def send(self, *args: str, **env: str) -> subprocess.CompletedProcess:
        return subprocess.run(["bash", str(self.door), *args], capture_output=True, text=True,
                              env={**self.env, **env}, timeout=120)

    def alert(self, msg: str, sev: str = "HIGH", key: str = "", **env: str) -> subprocess.CompletedProcess:
        args = ["--source", "cron", "--severity", sev, "--message", msg]
        if key:
            args += ["--key", key]
        r = self.send(*args, **env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        return r

    def arm(self) -> list[tuple[str, str]]:
        if not self.arm_log.exists():
            return []
        return [tuple(l.split("\t", 1)) for l in self.arm_log.read_text().splitlines()]

    def age_state(self, seconds: int) -> None:
        """Pretend `seconds` passed: every remembered instant moves back."""
        s = json.loads(self.state.read_text())
        s["seen"] = {k: v - seconds for k, v in s.get("seen", {}).items()}
        s["counts"] = {k: [t - seconds for t in v] for k, v in s.get("counts", {}).items()}
        self.state.write_text(json.dumps(s))


class OwnerRoad(Case):
    def test_an_alert_from_machine_a_reaches_a_arm(self):
        r = self.alert("job failed (rc=1): bin/x.sh — boom", YMIR_NOTIFY_HOST="host-a")
        arm = self.arm()
        self.assertEqual(len(arm), 1, r.stdout)
        self.assertEqual(arm[0][0], "host-a", "the machine named in the line owns it")
        self.assertIn("[host-a · cron/HIGH] job failed", arm[0][1])
        self.assertIn("telegram_message", arm[0][1], "the turn tells the agent how to answer the operator")
        self.assertIn("--answered", arm[0][1])
        self.assertIn("--silence", arm[0][1], "the silence-for-a-day button has a command behind it")
        self.assertEqual(self.calls, [], "the raw post WAITS while an agent holds the alert")
        self.assertIn('"held"', r.stdout)

    def test_with_a_dead_the_heart_arm_takes_it_and_the_line_says_so(self):
        r = self.alert("job failed (rc=4): learn-home", YMIR_NOTIFY_HOST="host-a", FAKE_ARM_DEAD="host-a")
        arm = self.arm()
        self.assertEqual([m for m, _ in arm], ["heart-h"], r.stdout)
        self.assertIn("host-a's arm did not answer — handed to the heart", arm[0][1])
        self.assertIn("heart-h (the heart; host-a did not answer)", r.stdout)

    def test_with_no_arm_anywhere_the_bot_posts_at_once(self):
        self.alert("the rail is dark", YMIR_NOTIFY_HOST="host-a", FAKE_ARM_DEAD="host-a,heart-h")
        self.assertEqual(self.arm(), [])
        self.assertEqual(len(self.calls), 1, "a silent fleet still pages the operator")

    def test_owner_override_from_the_home_config(self):
        (self.home / "config").mkdir()
        (self.home / "config/notify-owners.conf").write_text("# source machine\ncron host-b\n* self\n")
        self.alert("a cron row failed", YMIR_NOTIFY_HOST="host-a")
        self.assertEqual([m for m, _ in self.arm()], ["host-b"])

    def test_unanswered_in_time_posts_raw_and_answered_withdraws(self):
        r1 = self.alert("first alarm", YMIR_NOTIFY_ANSWER_MIN="0")
        alert1 = r1.stdout.split("owner[1]{alert,handed_to,group,repeats}:\n  \"", 1)[1].split('"', 1)[0]
        self.send("--flush-due")
        self.assertEqual(len(self.calls), 1, "nobody answered: the raw line goes to the chat")
        self.assertIn("no agent answered", self.calls[0]["text"])
        self.assertIn("first alarm", self.calls[0]["text"])

        r2 = self.alert("second alarm", YMIR_NOTIFY_ANSWER_MIN="0")
        alert2 = r2.stdout.split("owner[1]{alert,handed_to,group,repeats}:\n  \"", 1)[1].split('"', 1)[0]
        self.assertNotEqual(alert1, alert2)
        a = self.send("--answered", alert2)
        self.assertIn("withdrawn", a.stdout)
        self.send("--flush-due")
        self.assertEqual(len(self.calls), 1, "an answered alert is never posted raw")

    def test_medium_and_ask_do_not_take_the_owner_road(self):
        self.alert("a quiet thing", sev="MEDIUM")
        self.send("--source", "cron", "--severity", "HIGH", "--ask", "--message", "approve?")
        self.assertEqual(self.arm(), [])


class Flood(Case):
    def test_nine_hours_of_15_minute_criticals_are_nine_lines_with_counts(self):
        msg = "the hound is silent (heartbeat {}s old) — the guardian is not guarding"
        for k in range(36):  # every 15 minutes for 9 hours
            self.alert(msg.format(25000 + k * 900), sev="CRITICAL", key="housewatch:hound",
                       YMIR_NOTIFY_OWNER_ROAD="0")
            self.age_state(900)
        self.assertLessEqual(len(self.calls), 9, [c["text"] for c in self.calls])
        self.assertEqual(len(self.calls), 9)
        for c in self.calls[1:]:
            self.assertIn("repeated 3× since the last line", c["text"])

    def test_an_hour_stamp_in_the_key_does_not_make_it_a_new_key(self):
        self.alert("x", sev="CRITICAL", key="housewatch:hound:2026112019", YMIR_NOTIFY_OWNER_ROAD="0")
        self.age_state(900)
        self.alert("x", sev="CRITICAL", key="housewatch:hound:2026112020", YMIR_NOTIFY_OWNER_ROAD="0")
        self.assertEqual(len(self.calls), 1)

    def test_two_pids_in_the_key_are_two_lines(self):
        # garmr keys each alert per process; a 7-digit pid is an identity, never a stamp.
        for pid in ("1944928", "2243535", "31337", "31338"):
            r = self.alert("ward rule tripped", key=f"garmr:shell spawned:{pid}", YMIR_NOTIFY_OWNER_ROAD="0")
            self.assertNotIn('"duplicate"', r.stdout, pid)
        self.assertEqual(len(self.calls), 4)

    def test_an_epoch_or_iso_stamp_in_the_key_still_folds(self):
        self.alert("x", key="watch:disk:1763700000", YMIR_NOTIFY_OWNER_ROAD="0")
        self.alert("x", key="watch:disk:1763703600", YMIR_NOTIFY_OWNER_ROAD="0")
        self.alert("x", key="watch:disk:2026-11-21T03:00:00Z", YMIR_NOTIFY_OWNER_ROAD="0")
        self.assertEqual(len(self.calls), 1)

    def test_an_auto_key_folds_the_changing_number(self):
        self.alert("heartbeat 100s old", YMIR_NOTIFY_OWNER_ROAD="0")
        self.alert("heartbeat 1000s old", YMIR_NOTIFY_OWNER_ROAD="0")
        self.assertEqual(len(self.calls), 1)

    def test_an_auto_key_keeps_a_number_that_names_the_thing(self):
        # A review seat sends "--message '<PR #, verdict…>'" with no key: two PRs are two notices.
        self.alert("new PR #857 opened — CI blocked", YMIR_NOTIFY_OWNER_ROAD="0")
        r = self.alert("new PR #858 opened — CI blocked", YMIR_NOTIFY_OWNER_ROAD="0")
        self.assertNotIn('"duplicate"', r.stdout)
        self.alert("port 8080 refused", YMIR_NOTIFY_OWNER_ROAD="0")
        self.alert("port 8081 refused", YMIR_NOTIFY_OWNER_ROAD="0")
        self.assertEqual(len(self.calls), 4)

    def test_an_auto_key_folds_measurements(self):
        for msg in ("disk at 91% after 3 min (rc=1) at 03:10", "disk at 92% after 4 min (rc=2) at 03:25"):
            self.alert(msg, YMIR_NOTIFY_OWNER_ROAD="0")
        self.assertEqual(len(self.calls), 1)

    def test_a_repeat_is_not_a_second_turn_for_the_agent(self):
        self.alert("same thing", key="k:1")
        self.alert("same thing", key="k:1")
        self.assertEqual(len(self.arm()), 1)

    def test_silence_for_a_day(self):
        r = self.alert("noisy", key="noisy:thing", YMIR_NOTIFY_OWNER_ROAD="0")
        group = r.stdout.split("owner[1]{alert,handed_to,group,repeats}:\n  \"", 1)[1].split('","')[2]
        s = self.send("--silence", group, "--hours", "24")
        self.assertIn("silenced", s.stdout)
        self.age_state(7200)
        r2 = self.alert("noisy", key="noisy:thing", YMIR_NOTIFY_OWNER_ROAD="0")
        self.assertIn('"silenced"', r2.stdout)
        self.assertEqual(len(self.calls), 1)


class CronTail(unittest.TestCase):
    def tail(self, err: str, out: str, rc: str = "1") -> str:
        d = Path(tempfile.mkdtemp(prefix="cron-tail-"))
        self.addCleanup(shutil.rmtree, d, True)
        (d / "e").write_text(err)
        (d / "o").write_text(out)
        script = (f'. "{ROOT}/bin/time/cron-fail-lib.sh"; t="$(cron_row_tail "{d}/e" "{d}/o")"; '
                  f'cron_fail_detail /h "bin/x.sh" {rc} "$t"')
        return subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=30).stdout

    def test_a_failing_rows_stderr_tail_is_the_reason(self):
        out = self.tail("noise\nhome-sync: fetch failed — base UNVERIFIED\nhome-sync: push refused\n", "learn-home ran\n")
        self.assertIn("home-sync: push refused", out)
        self.assertIn("fetch failed", out)
        self.assertNotIn("no output", out)

    def test_stdout_when_stderr_is_empty(self):
        self.assertIn("last words", self.tail("", "first\nlast words\n"))

    def test_silence_still_says_it_said_nothing(self):
        self.assertIn("said nothing", self.tail("", ""))

    def test_the_scheduler_reads_the_rows_own_output(self):
        src = (ROOT / "bin/time/nornir-cron-start.sh").read_text()
        self.assertIn('cron_row_tail "$_err" "$_out"', src)
        self.assertNotIn('tail -n 4 "$log"', src, "the shared log is not the row's voice")


if __name__ == "__main__":
    unittest.main(verbosity=2)
