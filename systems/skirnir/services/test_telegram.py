"""test_telegram.py — the two faults that made Skírnir look deaf (plan 227 §S1.5, 2026-11-09).

  1 · `telegram: rate limited (too fast)` went to stderr and the Allfather's message vanished with no
      sentence at all. A limit must TELL him to wait, once, and never answer a flood with a flood.
  2 · a poll (or a send, or the bookkeeping) that raised took the whole poller with it: systemd
      restarted the bot, Telegram replayed the same update, and it died again. A poison message must
      be skipped and PRINTED, never turn into permanent deafness.

Run: python3 -m unittest discover -s systems/skirnir/services -p 'test_*.py'
"""
import io
import json
import os
import sys
import tempfile
import unittest
import urllib.error
from unittest.mock import patch

fixture = tempfile.TemporaryDirectory()
os.environ["YMIR_HOME"] = fixture.name
os.environ["SKIRNIR_TELEGRAM_BOT_TOKEN"] = "fixture-token"
os.environ["TELEGRAM_OWNER_ID"] = "1"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import telegram                                                     # noqa: E402


class RateLimitSpeaks(unittest.TestCase):
    def setUp(self):
        telegram.NOTICED.clear()
        try:
            os.remove(telegram.LIMITS)
        except OSError:
            pass

    def test_two_messages_inside_five_seconds_are_limited(self):
        with patch.object(telegram.time, "time", return_value=1000.0):
            self.assertEqual(telegram.allowed("42"), (True, ""))
        with patch.object(telegram.time, "time", return_value=1001.0):
            self.assertEqual(telegram.allowed("42"), (False, "too fast"))

    def test_the_notice_tells_him_to_wait(self):
        sent = []
        with patch.object(telegram, "api_patient", side_effect=lambda *a, **k: sent.append(k)):
            telegram.rate_notice("42", "too fast")
        self.assertEqual(len(sent), 1, "a limit must send ONE sentence")
        self.assertIn("seconds", sent[0]["text"].lower())
        self.assertIn("send it again", sent[0]["text"].lower())

    def test_a_flood_gets_one_notice_not_a_storm(self):
        sent = []
        with patch.object(telegram, "api_patient", side_effect=lambda *a, **k: sent.append(k)):
            for _ in range(10):
                telegram.rate_notice("42", "too fast")
        self.assertEqual(len(sent), 1, "ten dropped messages must not become ten notices")

    def test_the_hourly_cap_says_so_without_blaming_him(self):
        sent = []
        with patch.object(telegram, "api_patient", side_effect=lambda *a, **k: sent.append(k)):
            telegram.rate_notice("43", "30/hour in this chat")
        self.assertEqual(len(sent), 1)
        self.assertIn("thirty", sent[0]["text"].lower())


class APatient(unittest.TestCase):
    def test_a_429_is_waited_out_and_retried(self):
        calls = []

        def api(method, **params):
            calls.append(method)
            if len(calls) == 1:
                body = io.BytesIO(json.dumps({"parameters": {"retry_after": 2}}).encode())
                raise urllib.error.HTTPError("u", 429, "Too Many Requests", {}, body)
            return {"ok": True}

        with patch.object(telegram, "api", side_effect=api), \
                patch.object(telegram.time, "sleep") as slept:
            self.assertEqual(telegram.api_patient("sendMessage", chat_id=1, text="x"), {"ok": True})
        self.assertEqual(len(calls), 2, "a 429 must be retried, never dropped")
        slept.assert_called_once_with(2)


class APoisonUpdateCannotDeafenHim(unittest.TestCase):
    def test_one_unhandleable_message_is_skipped_and_the_poll_goes_on(self):
        updates = [{"update_id": 7,
                    "message": {"message_id": 1, "from": {"id": 55, "username": "someone"},
                                "chat": {"id": 42, "type": "private"}, "text": "hello there"}}]
        seen = []

        def api(method, **params):
            if method == "getUpdates":
                seen.append("poll")
                return {"result": updates if len(seen) == 1 else []}
            return {}

        # main() is the poller: before this fix an exception from the engine escaped main() entirely,
        # the process exited, systemd restarted it and the same update killed it again — deafness.
        with patch.object(telegram, "api", side_effect=api), \
                patch.object(telegram, "answer", side_effect=RuntimeError("the engine exploded")), \
                patch.object(telegram, "api_patient", return_value={}), \
                patch.object(telegram, "send_voice", return_value=None), \
                patch.object(telegram.time, "sleep", return_value=None), \
                patch.object(sys, "argv", ["telegram.py", "--once"]):
            self.assertEqual(telegram.main(), 0, "the poller must survive a bad message")
        with open(telegram.OFFSET) as fh:
            self.assertEqual(fh.read().strip(), "8",
                             "the offset must still advance past the poison message")

    def test_a_failed_poll_is_printed_and_not_silent(self):
        def api(method, **params):
            if method == "getUpdates":
                raise TimeoutError("the read timed out")
            return {}

        argv = ["telegram.py", "--once"]
        with patch.object(telegram, "api", side_effect=api), \
                patch.object(telegram.time, "sleep", side_effect=KeyboardInterrupt), \
                patch.object(sys, "argv", argv), \
                patch("sys.stderr", new_callable=io.StringIO) as err:
            with self.assertRaises(KeyboardInterrupt):
                telegram.main()
        self.assertIn("poll failed", err.getvalue(),
                      "a poll that fails must say so, or a timeout looks like a quiet night")


if __name__ == "__main__":
    unittest.main()
