#!/usr/bin/env python3
"""The proofs for the controls `bin/notify/send.sh` carries — a nag that cannot be acted on.

A phone line that leaves a decision must arrive with its buttons, and the house writes buttons
in exactly one grammar (`bin/notify/telegram-buttons.sh`). This door posts straight to the Bot
API with no session behind it, so the wrapper a bridge would parse is not enough: the message
needs the API's own `reply_markup`. Two silent failures are what these proofs stand against:

  · the markup is accepted by the caller and dropped on the way out, so the operator's line
    arrives as prose with no controls and no error anywhere;
  · a button with no prompt — or one the grammar refuses — is sent anyway, and Telegram never
    complains.

The Bot API is stood in for by a local HTTP server (TELEGRAM_API_BASE is configuration, Rule 07),
so nothing here talks to Telegram and no phone rings.

    python3 bin/notify/tests/test_send_buttons.py
    python3 bin/notify/tests/test_send_buttons.py ButtonsArrive    # one proof
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
DOOR = ROOT / "bin/notify/send.sh"


class Telegram:
    """What the door posted, in the order it posted it."""

    def __init__(self) -> None:
        self.calls: list[dict] = []


def make_server(state: Telegram) -> ThreadingHTTPServer:
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *a):
            pass

        def do_POST(self):
            n = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(n).decode("utf-8", "replace") if n else ""
            params = urllib.parse.parse_qs(raw)
            if urllib.parse.urlparse(self.path).path.endswith("/sendMessage"):
                state.calls.append({k: v[0] for k, v in params.items()})
                body = json.dumps({"ok": True, "result": {"message_id": len(state.calls)}}).encode()
            else:
                body = json.dumps({"ok": True}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


class Case(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="send-buttons-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.telegram = Telegram()
        self.srv = make_server(self.telegram)
        self.addCleanup(self.srv.server_close)
        self.addCleanup(self.srv.shutdown)
        port = self.srv.server_address[1]

        self.home = self.tmp / "home"
        (self.home / "hodd/secrets").mkdir(parents=True)
        (self.home / "state").mkdir(parents=True, exist_ok=True)
        self.runes = self.tmp / "runes.md"
        self.env = {
            **os.environ,
            "YMIR_HOME": str(self.home),
            "BROKK_HOME": str(ROOT),
            "BROKK_ROOT_OVERRIDE": str(ROOT),
            "BROKK_RUNES_FILE": str(self.runes),
            "TELEGRAM_BOT_TOKEN": "test-token",
            "TELEGRAM_OWNER_ID": "4242",
            "TELEGRAM_API_BASE": f"http://127.0.0.1:{port}",
        }
        for name in ("TELEGRAM_ALERT_CHAT", "SKIRNIR_TELEGRAM_BOT_TOKEN"):
            self.env.pop(name, None)

    def door(self, *args: str) -> subprocess.CompletedProcess:
        # MEDIUM + --ask reaches the Telegram leg without waking the pocket leg (HIGH+ only),
        # which is the same road a house line takes when it wants a click.
        return subprocess.run(["bash", str(DOOR), "--source", "cron", "--severity", "MEDIUM", "--ask", *args],
                              capture_output=True, text=True, env=self.env, timeout=120)

    def sent(self) -> list[dict]:
        return self.telegram.calls


class ButtonsArrive(Case):
    def test_one_line_arrives_with_its_buttons(self):
        r = self.door("--message", "3 drafts are unwritten", "--buttons", "[[{A|a}{B|b}][{C|c}{D|d}]]")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        sent = self.sent()
        self.assertEqual(len(sent), 1, "one line is one message")
        self.assertIn("3 drafts are unwritten", sent[0].get("text", ""))
        self.assertIn("reply_markup", sent[0], "the controls must travel WITH the line: " + json.dumps(sent[0]))
        markup = json.loads(sent[0]["reply_markup"])
        rows = markup["inline_keyboard"]
        self.assertEqual([len(row) for row in rows], [2, 2], "the caller's rows are kept, not rechunked")
        self.assertEqual([c["text"] for c in rows[0]], ["A", "B"])
        self.assertEqual(rows[1][1]["callback_data"], "d", "the prompt is the click, byte for byte")
        self.assertIn("buttons[4]{label}:", r.stdout, "the record says how many controls the line carried")


class FromPairs(Case):
    def test_button_pairs_are_laid_out_by_the_grammar_door(self):
        r = self.door("--message", "one draft", "--button", "✉️ 1 send|Send draft 1 now.",
                      "--button", "✏️ 1 edit|Edit draft 1.", "--button", "🗑 1 discard|Discard draft 1.")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        markup = json.loads(self.sent()[0]["reply_markup"])
        self.assertEqual(len(markup["inline_keyboard"]), 1, "three buttons, one draft — one row")
        self.assertEqual(len(markup["inline_keyboard"][0]), 3)
        self.assertEqual(markup["inline_keyboard"][0][0]["callback_data"], "Send draft 1 now.")


class Refused(Case):
    def test_a_button_that_cannot_render_is_refused_and_nothing_is_sent(self):
        r = self.door("--message", "one draft", "--button", "✉️ 1 send|")
        self.assertEqual(r.returncode, 2, "a buttonless prompt is a REFUSAL, not a quiet prose line\n" + r.stdout)
        self.assertIn("refused", r.stderr)
        self.assertEqual(self.sent(), [], "a refused control must not post anything at all")

    def test_a_malformed_payload_is_refused(self):
        r = self.door("--message", "one draft", "--buttons", "[[{A|a}]")
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertEqual(self.sent(), [])


class NoButtons(Case):
    def test_a_line_with_no_controls_carries_no_markup(self):
        r = self.door("--message", "everything is quiet")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        sent = self.sent()
        self.assertEqual(len(sent), 1)
        self.assertNotIn("reply_markup", sent[0], "an ordinary line must not grow an empty keyboard")
        self.assertNotIn("buttons[", r.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
