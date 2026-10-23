#!/usr/bin/env python3
"""The proofs plan 116 asks for before the desk is shown to a human."""

from __future__ import annotations

import json
import os
import re
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
AGENT_DIR = HERE.parent

TMP = Path(tempfile.mkdtemp(prefix="gna-test-"))
os.environ["YMIR_HOME"] = str(TMP)
(TMP / "hodd/memory/mail").mkdir(parents=True)
(TMP / "hodd/memory/mail/accounts.yaml").write_text(
    "accounts:\n"
    "  - id: operator@example.com\n    grant: X\n    status: scoped\n"
    "  - id: team@example.com\n    grant: Y\n    status: scoped\n",
    encoding="utf-8",
)

sys.path.insert(0, str(AGENT_DIR))
import gna_desk  # noqa: E402
import gna_judge  # noqa: E402
import gna_store  # noqa: E402


def record(**over) -> dict:
    base = {
        "id": "m1",
        "account": "operator@example.com",
        "direction": "in",
        "thread_key": "t1",
        "from": {"name": "Craig Example", "email": "craig@example.com"},
        "to": [{"name": "the operator", "email": "operator@example.com"}],
        "subject": "Faktura 2026-10",
        "body_text": "Bifogad faktura for oktober.",
        "received_at": "2026-10-23T10:00:00+00:00",
        "labels": ["INBOX", "UNREAD"],
        "classification": "invoice",
        "confidence": 0.85,
        "proposed_action": "file_invoice",
        "matched_by": "sender_email",
        "person_id": "craig-martin",
        "evidence": "test",
    }
    base.update(over)
    return base


class StoreScope(unittest.TestCase):
    def test_no_account_is_refused(self):
        for call in (lambda: gna_store.latest(""), lambda: gna_store.latest(None)):
            with self.assertRaises(gna_store.ScopeError):
                call()

    def test_undeclared_account_is_refused(self):
        with self.assertRaises(gna_store.ScopeError):
            gna_store.latest("someone@elsewhere.com")

    def test_message_never_crosses_accounts(self):
        gna_store.append([record()])
        with self.assertRaises(gna_store.ScopeError):
            gna_store.get_message("team@example.com", "m1")

    def test_each_account_sees_only_its_own(self):
        gna_store.append([
            record(id="a1", account="operator@example.com"),
            record(id="b1", account="team@example.com", received_at="2026-10-23T11:00:00+00:00"),
        ])
        ids_a = {r["id"] for r in gna_store.latest("operator@example.com")}
        ids_b = {r["id"] for r in gna_store.latest("team@example.com")}
        self.assertIn("a1", ids_a)
        self.assertNotIn("b1", ids_a)
        self.assertIn("b1", ids_b)
        self.assertNotIn("a1", ids_b)


class Judge(unittest.TestCase):
    people = {"craig@example.com": {"id": "craig-martin", "project": "wayof"}}

    def test_known_sender_invoice_is_high_confidence(self):
        verdict = gna_judge.judge(record(), self.people)
        self.assertEqual(verdict["classification"], "invoice")
        self.assertEqual(verdict["proposed_action"], "file_invoice")
        self.assertGreaterEqual(verdict["confidence"], 0.6)
        self.assertIn("craig-martin", verdict["evidence"])

    def test_unknown_sender_lands_in_unsure(self):
        verdict = gna_judge.judge(record(**{"from": {"email": "stranger@nowhere.io"},
                                            "subject": "Hej", "body_text": "Hej pa dig"}), self.people)
        self.assertLess(verdict["confidence"], 0.6)
        self.assertEqual(verdict["classification"], "other")

    def test_thread_inherits(self):
        parent = record(id="m0", classification="invoice", person_id="craig-martin")
        verdict = gna_judge.judge(record(id="m2", subject="Re: Faktura", body_text="Tack!"), self.people, parent)
        self.assertEqual(verdict["classification"], "invoice")
        self.assertEqual(verdict["matched_by"], "thread")

    def test_house_sender_is_not_a_human_question(self):
        verdict = gna_judge.judge(
            record(**{"from": {"email": "team@example.com"}, "subject": "[Copy] team door"}),
            self.people,
            house={"team@example.com"},
        )
        self.assertEqual(verdict["proposed_action"], "archive")
        self.assertEqual(verdict["matched_by"], "house")

    def test_every_verdict_carries_evidence(self):
        for sender in ({"email": "craig@example.com"}, {"email": "x@y.z"}):
            verdict = gna_judge.judge(record(**{"from": sender}), self.people)
            self.assertTrue(verdict["evidence"])
            self.assertIn(verdict["classification"], gna_judge.CLASSES)
            self.assertIn(verdict["proposed_action"], gna_judge.ACTIONS)


class Desk(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        gna_desk.Handler.token_value = "test-token"
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), gna_desk.Handler)
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def get(self, path: str, token: str | None = "test-token"):
        req = urllib.request.Request(f"http://127.0.0.1:{self.port}{path}")
        if token:
            req.add_header("authorization", f"Bearer {token}")
        try:
            with urllib.request.urlopen(req, timeout=5) as r:
                return r.status, json.load(r)
        except urllib.error.HTTPError as exc:
            return exc.code, json.load(exc)

    def test_health_never_names_a_subject(self):
        status, body = self.get("/health", token=None)
        self.assertEqual(status, 200)
        self.assertEqual(body["send_capability"], "none")
        self.assertNotIn("messages_list", json.dumps(body))

    def test_without_token_is_refused(self):
        self.assertEqual(self.get("/queue?account=operator@example.com", token=None)[0], 401)

    def test_without_account_scope_is_refused(self):
        status, body = self.get("/queue")
        self.assertEqual(status, 400)
        self.assertIn("account scope required", body["error"])

    def test_undeclared_account_is_refused(self):
        status, body = self.get("/queue?account=someone@elsewhere.com")
        self.assertEqual(status, 400)
        self.assertIn("not declared", body["error"])

    def test_queue_is_scoped_and_ordered_into_columns(self):
        gna_store.append([record(id="q1")])
        status, body = self.get("/queue?account=operator@example.com&hours=100000")
        self.assertEqual(status, 200)
        self.assertIn("q1", {r["id"] for r in body["columns"]["needs_you"]})

    def test_post_is_not_allowed(self):
        req = urllib.request.Request(f"http://127.0.0.1:{self.port}/draft", data=b"{}", method="POST")
        req.add_header("authorization", "Bearer test-token")
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req, timeout=5)
        self.assertEqual(ctx.exception.code, 405)


class NoSendCapability(unittest.TestCase):
    FORBIDDEN = (
        r"messages/send",
        r"\bsmtplib\b",
        r"users/me/drafts",
        r"mail-send\.sh",
        r"gmail\.send",
    )

    def test_no_file_here_can_send(self):
        for path in sorted(AGENT_DIR.glob("gna_*.py")) + [AGENT_DIR / "mail-scan.sh"]:
            text = path.read_text(encoding="utf-8")
            for pattern in self.FORBIDDEN:
                self.assertIsNone(
                    re.search(pattern, text),
                    f"{path.name} carries a send path: {pattern}",
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
