#!/usr/bin/env python3
"""The outbound gate's proofs — plan 124 §7, his word 2026-10-24:

    "the plans are now capable of sending out emails first to me so I can validate
     what's ever going out or made in the correct way."

Four behaviours, one per hole the audit measured:

  MailGate      an unapproved draft is refused AND the refusal is recorded;
                an approved draft sends exactly once; a second send is refused;
                a draft edited after approval is refused as STALE.
  CalendarGate  an invite with attendees defaults to no mail, and only an approved
                one sets sendUpdates=all; an edited event after approval is STALE;
                a cancel mails nobody unless it is approved too.
  GnaOwed       Gná's own ward still holds: nothing in bin/mail can send, and the send
                path she is owed stays owed to plan 116.

The Gmail and Calendar APIs are stood in for by a local HTTP server and the endpoints are
configuration (Rule 07: YMIR_GMAIL_API_BASE · YMIR_CALENDAR_API_BASE · YMIR_OAUTH_TOKEN_URL).
Nothing here talks to Google, and nothing here mocks the gate: the doors, the approval
records, the hash binding and the spending are the shipping ones.

    python3 bin/time/snotra/tests/test_outbound_gate.py            # every proof
    python3 bin/time/snotra/tests/test_outbound_gate.py MailGate   # one hole
"""

from __future__ import annotations

import base64
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MAIL = ROOT / "bin/time/snotra/mail-send.sh"
CAL = ROOT / "bin/time/snotra/calendar-invite.sh"
APPROVE = ROOT / "bin/time/snotra/snotra-approve.sh"

# ── the two APIs, stood in for ───────────────────────────────────────────────────────


class Api:
    """What the server saw, and the drafts it holds. One instance per test."""

    def __init__(self) -> None:
        self.drafts: dict[str, bytes] = {}
        self.lengths: dict[str, int] = {}
        self.sends: list[str] = []
        self.events: list[dict] = []
        self.cancels: list[dict] = []
        self.tokens = 0


def make_server(api: Api) -> ThreadingHTTPServer:
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *a):  # the tests are the record, not the access log
            pass

        def _body(self) -> bytes:
            n = int(self.headers.get("Content-Length") or 0)
            return self.rfile.read(n) if n else b""

        def _json(self, code: int, doc) -> None:
            raw = json.dumps(doc).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def _empty(self, code: int) -> None:
            self.send_response(code)
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_POST(self):
            u = urlparse(self.path)
            body = self._body()
            if u.path == "/token":
                api.tokens += 1
                return self._json(200, {"access_token": "fake-token", "expires_in": 3600})
            if u.path == "/gmail/v1/users/me/drafts/send":
                api.sends.append(json.loads(body or b"{}").get("id", ""))
                return self._json(200, {"id": "m-" + api.sends[-1]})
            if u.path == "/calendar/v3/calendars/primary/events":
                q = parse_qs(u.query)
                api.events.append({"body": json.loads(body or b"{}"),
                                   "sendUpdates": (q.get("sendUpdates") or ["<absent>"])[0]})
                return self._json(200, {"id": "e-1", "htmlLink": "http://example.invalid/e-1",
                                        "hangoutLink": "http://example.invalid/meet"})
            return self._empty(404)

        def do_GET(self):
            u = urlparse(self.path)
            m = re.match(r"^/gmail/v1/users/me/drafts/([^/]+)$", u.path)
            if m:
                did = unquote(m.group(1))
                if did not in api.drafts:
                    return self._json(404, {"error": {"message": "draft not found"}})
                raw = base64.urlsafe_b64encode(api.drafts[did]).decode()
                return self._json(200, {"id": did, "message": {"raw": raw}})
            if u.path == "/gmail/v1/users/me/profile":
                return self._json(200, {"emailAddress": "operator@example.com"})
            return self._empty(404)

        def do_DELETE(self):
            u = urlparse(self.path)
            m = re.match(r"^/calendar/v3/calendars/primary/events/([^/]+)$", u.path)
            if m:
                q = parse_qs(u.query)
                api.cancels.append({"id": unquote(m.group(1)),
                                    "sendUpdates": (q.get("sendUpdates") or ["<absent>"])[0]})
                return self._empty(204)
            return self._empty(404)

    srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


# ── a home with a real vault, and the env the doors read ─────────────────────────────


class Case(unittest.TestCase):
    """One throwaway home, one vault, one server, per test."""

    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="gate-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.api = Api()
        self.srv = make_server(self.api)
        self.addCleanup(self.srv.server_close)
        self.addCleanup(self.srv.shutdown)
        port = self.srv.server_address[1]

        home = self.tmp / "home"
        sec = home / "hodd/secrets"
        sec.mkdir(parents=True)
        key = sec / "age.key"
        subprocess.run(["age-keygen", "-o", str(key)], check=True,
                       capture_output=True)
        recipient = subprocess.run(["age-keygen", "-y", str(key)], check=True,
                                   capture_output=True, text=True).stdout.strip()
        plain = ("GOOGLE_MCP_CLIENT_ID=fake-client\n"
                 "GOOGLE_MCP_CLIENT_SECRET=fake-secret\n"
                 "SNOTRA_GOOGLE_REFRESH_TOKEN=fake-refresh\n")
        subprocess.run(["age", "-e", "-r", recipient, "-o", str(sec / "platform.env.age")],
                       input=plain.encode(), check=True)

        self.home = home
        self.state = self.tmp / "state"
        self.runes = self.tmp / "runes.md"
        self.env = {
            **os.environ,
            "YMIR_HOME": str(home),
            "XDG_STATE_HOME": str(self.state),
            "XDG_CONFIG_HOME": str(self.tmp / "config"),
            "BROKK_HOME": str(ROOT),
            "BROKK_RUNES_FILE": str(self.runes),
            "YMIR_OPERATOR": "the-allfather",
            "YMIR_GMAIL_API_BASE": f"http://127.0.0.1:{port}/gmail/v1",
            "YMIR_CALENDAR_API_BASE": f"http://127.0.0.1:{port}/calendar/v3",
            "YMIR_OAUTH_TOKEN_URL": f"http://127.0.0.1:{port}/token",
        }

    # helpers ---------------------------------------------------------------------

    def run_script(self, script: Path, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(["bash", str(script), *args], capture_output=True,
                              text=True, env=self.env, timeout=120)

    def draft(self, did: str, body: bytes) -> None:
        self.api.drafts[did] = body

    def approve(self, key: str) -> subprocess.CompletedProcess:
        return self.run_script(APPROVE, "approve", key)

    def ledger(self) -> str:
        return self.runes.read_text(encoding="utf-8") if self.runes.is_file() else ""


# ── hole 1: the mail door ────────────────────────────────────────────────────────────


class MailGate(Case):
    def test_1_unapproved_draft_is_refused_and_the_refusal_is_recorded(self):
        self.draft("r-1", b"To: partner@example.com\r\nSubject: OptiCat\r\n\r\nhello\r\n")
        r = self.run_script(MAIL, "send", "r-1")
        self.assertNotEqual(r.returncode, 0, r.stdout)
        self.assertIn("NOT APPROVED", r.stderr)
        self.assertEqual(self.api.sends, [], "the door opened the send socket without the word")
        self.assertIn("REFUSED mail r-1", self.ledger(), "the refusal was not carved into the Runes")

    def test_2_an_approved_draft_sends_exactly_once_and_a_second_send_is_refused(self):
        self.draft("r-2", b"To: partner@example.com\r\nSubject: OptiCat\r\n\r\nhello\r\n")
        self.assertEqual(self.approve("r-2").returncode, 0)

        first = self.run_script(MAIL, "send", "r-2")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertTrue(first.stdout.startswith("sent\t"), first.stdout)
        self.assertEqual(self.api.sends, ["r-2"])

        second = self.run_script(MAIL, "send", "r-2")
        self.assertNotEqual(second.returncode, 0, "the same word released the letter twice")
        self.assertIn("ALREADY SENT", second.stderr)
        self.assertEqual(self.api.sends, ["r-2"], "a replay reached the send socket")
        self.assertIn("REFUSED mail r-2", self.ledger())
        self.assertIn("SPENT mail r-2", self.ledger())

    def test_3_a_draft_edited_after_approval_is_refused_as_stale(self):
        self.draft("r-3", b"To: partner@example.com\r\nSubject: OptiCat\r\n\r\nhello\r\n")
        self.assertEqual(self.approve("r-3").returncode, 0)
        self.draft("r-3", b"To: partner@example.com\r\nSubject: OptiCat\r\n\r\nhello, and one more thing\r\n")

        r = self.run_script(MAIL, "send", "r-3")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("STALE", r.stderr)
        self.assertEqual(self.api.sends, [])
        self.assertIn("REFUSED mail r-3: STALE", self.ledger())

    def test_4_the_gate_is_a_verb_of_the_door_not_a_caller_habit(self):
        """`send` must not depend on anyone remembering to call `check` first."""
        text = MAIL.read_text(encoding="utf-8")
        send_body = text.split("send(){", 1)[1].split("\ndiscard(){", 1)[0]
        self.assertIn("gate mail", send_body, "the approval check is not inside the send door")
        self.assertLess(send_body.index("gate mail"), send_body.index("drafts/send"),
                        "the door asks for the send before it asks for the word")


# ── hole 2: the calendar door ────────────────────────────────────────────────────────


class CalendarGate(Case):
    ARGS = ("--title", "OptiCat review", "--start", "2026-10-30T10:00:00",
            "--end", "2026-10-30T10:30:00")

    def create(self, *extra: str) -> subprocess.CompletedProcess:
        return self.run_script(CAL, "create", *self.ARGS, *extra)

    def test_1_an_invite_with_attendees_mails_nobody_without_the_word(self):
        r = self.create("--attendees", "partner@example.com")
        self.assertEqual(r.returncode, 3, r.stderr)
        self.assertIn("REFUSED", r.stderr)
        self.assertEqual(self.api.events, [], "an event was posted and Google mailed the attendee")
        self.assertIn("REFUSED event evt-2026_10_30T10_00_00", self.ledger())
        held = self.state / "ymir/approvals/pending/evt-2026_10_30T10_00_00.json"
        self.assertTrue(held.is_file(), "the body was not held for the operator to read")

    def test_2_an_approved_invite_sets_sendUpdates_all_and_is_spent_once(self):
        self.create("--attendees", "partner@example.com")
        key = "evt-2026_10_30T10_00_00"
        self.assertEqual(self.run_script(APPROVE, "approve-event", key).returncode, 0)

        r = self.create("--attendees", "partner@example.com")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(self.api.events), 1)
        self.assertEqual(self.api.events[0]["sendUpdates"], "all")
        self.assertEqual(self.api.events[0]["body"]["attendees"][0]["email"], "partner@example.com")
        self.assertIn("mail\tall", r.stdout)

        again = self.create("--attendees", "partner@example.com")
        self.assertEqual(again.returncode, 3, "the same word released a second invitation")
        self.assertIn("ALREADY SENT", again.stderr)
        self.assertEqual(len(self.api.events), 1)

    def test_3_an_event_edited_after_approval_is_refused_as_stale(self):
        self.create("--attendees", "partner@example.com")
        key = "evt-2026_10_30T10_00_00"
        self.assertEqual(self.run_script(APPROVE, "approve-event", key).returncode, 0)

        r = self.run_script(CAL, "create", "--title", "OptiCat review — and pricing",
                            "--start", "2026-10-30T10:00:00", "--end", "2026-10-30T10:30:00",
                            "--attendees", "partner@example.com")
        self.assertEqual(r.returncode, 3)
        self.assertIn("STALE", r.stderr)
        self.assertEqual(self.api.events, [])

    def test_4_an_event_without_attendees_mails_nobody_and_needs_no_word(self):
        r = self.create()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.api.events[0]["sendUpdates"], "none")
        self.assertIn("mail\tnone", r.stdout)

    def test_5_a_cancel_mails_nobody_unless_it_is_approved_too(self):
        quiet = self.run_script(CAL, "cancel", "e-1")
        self.assertEqual(quiet.returncode, 0, quiet.stderr)
        self.assertEqual(self.api.cancels[0]["sendUpdates"], "none")

        noisy = self.run_script(CAL, "cancel", "e-2", "--notify")
        self.assertEqual(noisy.returncode, 3, "a cancellation notice left without the word")
        self.assertEqual(len(self.api.cancels), 1)

        key = "evt-e-2-cancel"
        self.assertEqual(self.run_script(APPROVE, "approve-event", key).returncode, 0)
        loud = self.run_script(CAL, "cancel", "e-2", "--notify")
        self.assertEqual(loud.returncode, 0, loud.stderr)
        self.assertEqual(self.api.cancels[-1]["sendUpdates"], "all")

    def test_6_the_default_value_is_none_in_the_tool_itself(self):
        """A default that only the tests see is not a default: read the door."""
        text = CAL.read_text(encoding="utf-8")
        self.assertNotIn("sendUpdates=all\"", text, "an unapproved sendUpdates=all is still spellable")
        self.assertIn('local send_updates="none"', text)
        self.assertEqual(text.count("send_updates=\"all\""), 2,
                         "sendUpdates=all must be set in exactly the two approved branches")


# ── hole 3: what is owed, not built ──────────────────────────────────────────────────


class GnaOwed(Case):
    def test_1_gnas_own_ward_still_holds(self):
        r = subprocess.run([sys.executable, str(ROOT / "bin/mail/tests/test_gna.py"),
                            "NoSendCapability"],
                           capture_output=True, text=True, timeout=120)
        self.assertEqual(r.returncode, 0, r.stderr[-2000:])

    def test_2_no_door_here_can_send_around_the_gate(self):
        """Every send in the tree names the approval door — the debt is stamped, not widened."""
        offenders = []
        for path in (ROOT / "bin").rglob("*"):
            if not path.is_file() or path.suffix not in (".sh", ".py"):
                continue
            text = path.read_text(encoding="utf-8", errors="replace")
            if re.search(r"mail-send\.sh\"?\s+send\b", text) and path.name not in {
                    "mail-send.sh", "snotra-approve.sh", "meet.sh"}:
                if "gate mail" not in text and "snotra-approve.sh" not in text:
                    offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [], f"a door sends without asking the gate: {offenders}")


if __name__ == "__main__":
    unittest.main(verbosity=2)
