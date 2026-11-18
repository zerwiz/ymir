#!/usr/bin/env python3
"""The RFC headers: a reply can name the message it answers (plan 305 §7.1, phase 7).

The store recorded 226 messages with a derived `thread_key` and none of them with a
`Message-ID`. So the house could say *what arrived* and could not say *which message this
answers* — and every join rested on a subject line, the one thing a reply is free to change.

Four proofs, one per promise the door makes:

  ImportStoresHeaders            every row carries Message-ID · In-Reply-To · References,
                                 read out of the payload the body fetch already paid for
  BackfillHeaders                `--backfill-headers` fills the rows written before it, with
                                 ONE metadata read per row (never a body), and a second run
                                 writes nothing
  ThreadedByHeader               two messages in one conversation are joined BY the header
                                 while their subjects disagree — and joined by subject they
                                 would not be one conversation at all
  LettersDoorNamesTheMessage     a reply drafted through the letters door (`mail-send.sh`)
                                 carries In-Reply-To and References naming the stored message

Nothing here talks to Google: the transport is the desk's own stub (test_gna.StubGmail), and
the letters door is given a local HTTP stand-in for the Gmail API and the token door, exactly
as `bin/time/snotra/tests/test_outbound_gate.py` does.  # allow-superseded-path: this line records where the door WAS, or names the real tests/ directory that never moved

    python3 bin/mail/tests/test_headers.py                 # every proof
    python3 bin/mail/tests/test_headers.py ThreadedByHeader # one of them
"""

from __future__ import annotations

import contextlib
import base64
import io
import json
import os
import re
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from datetime import datetime, timezone
from email import policy
from email.parser import BytesParser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse
import urllib.error

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
MAIL = ROOT / "systems/snotra/services/letters/mail-send.sh"

sys.path.insert(0, str(HERE))
# the desk's own fixtures: one throwaway home, one stub transport, no socket to Google
from test_gna import TMP, StubGmail, gmail_message  # noqa: E402

sys.path.insert(0, str(HERE.parent))
import gna_import  # noqa: E402
import gna_store  # noqa: E402

ACCOUNT = "headers@example.com"


def declare_account() -> None:
    """One more declared account, so these proofs judge a slice of the store of their own.

    The store refuses an undeclared account, which is the boundary that keeps one realm's mail
    out of another's — a proof earns the same rows a real mailbox would, it does not skip the gate."""
    path = TMP / "hodd/memory/mail/accounts.yaml"
    text = path.read_text(encoding="utf-8")
    if ACCOUNT in text:
        return
    marker = "\nhouse:\n"
    row = f"  - id: {ACCOUNT}\n    grant: H\n    status: scoped\n"
    assert marker in text, "the fixture home has no house: block to insert the account before"
    path.write_text(text.replace(marker, "\n" + row + "house:\n", 1), encoding="utf-8")


def with_headers(message: dict, message_id: str, in_reply_to: str = "", references: str = "") -> dict:
    """One stub message, carrying the three headers Gmail returns beside the body."""
    headers = message["full"]["payload"]["headers"]
    headers.append({"name": "Message-ID", "value": message_id})
    if in_reply_to:
        headers.append({"name": "In-Reply-To", "value": in_reply_to})
    if references:
        headers.append({"name": "References", "value": references})
    return message


class RecordingGmail(StubGmail):
    """The stub, with its memory turned on: what the importer ASKED for is the proof that no
    second request was made for a header's sake."""

    def __init__(self, messages: list[dict], account: str, page: int = 2) -> None:
        super().__init__(messages, account, page)
        self.calls: list[tuple[str, dict]] = []

    def api(self, token: str, path: str, params: dict | None = None) -> dict:
        self.calls.append((path, dict(params or {})))
        match = re.match(r"/users/me/messages/(.+)$", path)
        if match and not any(m["id"] == match.group(1) for m in self.messages):
            # a message the mailbox no longer has: the backfill must name it, not die on it
            raise urllib.error.HTTPError(path, 404, "message not found", {}, None)  # type: ignore[arg-type]
        return super().api(token, path, params)


class Door(unittest.TestCase):
    """A stub transport in place of the Gmail grant, for the length of one test."""

    def setUp(self) -> None:
        declare_account()
        for name in ("gna-mail-watermark.json", "gna-mail-last-run.json"):
            try:
                (TMP / "hodd/state" / name).unlink()
            except OSError:
                pass
        self._token, self._api = gna_import.token_for, gna_import.api

    def tearDown(self) -> None:
        gna_import.token_for, gna_import.api = self._token, self._api

    def use(self, transport: StubGmail) -> StubGmail:
        gna_import.token_for, gna_import.api = transport.token, transport.api
        return transport

    def run_import(self, *extra: str) -> tuple[int, str]:
        argv = sys.argv
        sys.argv = ["gna_import.py", "--account", ACCOUNT, *extra]
        out = io.StringIO()
        try:
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
                rc = gna_import.main()
        finally:
            sys.argv = argv
        return rc, out.getvalue()

    def stored(self, message_id: str) -> dict:
        for row in gna_store.latest(ACCOUNT):
            if row.get("id") == message_id:
                return row
        raise AssertionError(f"{message_id} is not in the store")


# ── the importer keeps the name ─────────────────────────────────────────────────────


class ImportStoresHeaders(Door):
    def test_1_every_row_carries_the_three_headers(self):
        transport = self.use(RecordingGmail(
            [with_headers(gmail_message("m-1", int(time.time()) - 60, "The invoice for October"),
                          "<m-1@letters.test>")], ACCOUNT))
        rc, out = self.run_import()
        self.assertEqual(rc, 0, out)
        row = self.stored("m-1")
        self.assertEqual(row["message_id"], "<m-1@letters.test>")
        self.assertEqual(row["in_reply_to"], "")
        self.assertEqual(row["references"], "")
        self.assertTrue(row["headers_at"], "the row does not say when its headers were read")
        self.assertEqual(row["thread_key"], transport.messages[0]["full"]["threadId"],
                         "Gmail's own threadId must stay the thread_key")

    def test_2_the_headers_cost_no_extra_request(self):
        """`format=full` already carries every header: a body is never fetched for a header's sake."""
        transport = self.use(RecordingGmail([with_headers(
            gmail_message("m-2", int(time.time()) - 60, "A question"),
            "<m-2@letters.test>", in_reply_to="<m-1@letters.test>",
            references="<m-1@letters.test>")], ACCOUNT))
        rc, out = self.run_import()
        self.assertEqual(rc, 0, out)
        message_calls = [(p, q) for p, q in transport.calls if re.search(r"/messages/.+$", p)]
        self.assertEqual(len(message_calls), 1, f"the importer asked {len(message_calls)} times for one message")
        self.assertEqual(message_calls[0][1].get("format"), "full",
                         "the one read is the body read the importer already made")
        self.assertEqual([q.get("format") for _, q in transport.calls
                          if "metadata" in (q.get("format") or "")],
                         [], "a metadata read was made for a message the body read already answered")
        row = self.stored("m-2")
        self.assertEqual(row["in_reply_to"], "<m-1@letters.test>")
        self.assertEqual(row["references"], "<m-1@letters.test>")


# ── the rows already written gain them ──────────────────────────────────────────────


class BackfillHeaders(Door):
    """The rows the OLD importer wrote: Gmail's id and threadId, none of the three headers.

    Each proof writes its own two rows, so a count is a count and not an accident of test order."""

    serial = 0

    def setUp(self) -> None:
        super().setUp()
        type(self).serial += 1
        self.tag = f"{type(self).serial:02d}"
        self.ids = [f"legacy-{self.tag}-1", f"legacy-{self.tag}-2"]
        self.old = [
            {"id": self.ids[0], "account": ACCOUNT, "direction": "in", "thread_key": "t-old",
             "from": {"name": "Ada Example", "email": "ada@example.com"},
             "to": [{"name": "", "email": ACCOUNT}], "subject": "The invoice for October",
             "body_text": "The invoice for October is attached.",
             "received_at": "2026-11-10T09:00:00+00:00", "labels": ["INBOX"],
             "classification": "invoice", "confidence": 0.85, "proposed_action": "file_invoice",
             "matched_by": "subject", "evidence": "fixture"},
            {"id": self.ids[1], "account": ACCOUNT, "direction": "in", "thread_key": "t-old",
             "from": {"name": "Ada Example", "email": "ada@example.com"},
             "to": [{"name": "", "email": ACCOUNT}], "subject": "Re: something else entirely",
             "body_text": "Thanks, paying today.",
             "received_at": "2026-11-10T11:00:00+00:00", "labels": ["INBOX"],
             "classification": "invoice", "confidence": 0.85, "proposed_action": "file_invoice",
             "matched_by": "thread", "evidence": "fixture"},
        ]
        gna_store.append([dict(row) for row in self.old])
        self.transport = self.use(RecordingGmail([
            with_headers(gmail_message(self.ids[0], int(time.time()) - 600, "The invoice for October"),
                         f"<{self.ids[0]}@letters.test>"),
            with_headers(gmail_message(self.ids[1], int(time.time()) - 300, "Re: something else entirely"),
                         f"<{self.ids[1]}@letters.test>", in_reply_to=f"<{self.ids[0]}@letters.test>",
                         references=f"<{self.ids[0]}@letters.test>"),
        ], ACCOUNT))

    def spine_lines(self, message_id: str) -> list[dict]:
        lines = gna_store.SPINE.read_text(encoding="utf-8").splitlines()
        return [json.loads(line) for line in lines if line.strip()
                and json.loads(line).get("id") == message_id and json.loads(line).get("account") == ACCOUNT]

    def test_1_the_backfill_fills_them_with_metadata_and_never_a_body(self):
        result = gna_import.backfill_headers(ACCOUNT)
        self.assertEqual(result["missing"], 2, result)
        self.assertEqual(result["filled"], 2, result)
        self.assertEqual(result["written"], 2, result)
        self.assertEqual(result["gone"], [], result)
        self.assertEqual(len(self.transport.calls), 2, self.transport.calls)
        for path, params in self.transport.calls:
            self.assertRegex(path, rf"/messages/{self.ids[0][:-1]}\d$")
            self.assertEqual(params.get("format"), "metadata",
                             "the backfill read a body to learn a header")
            self.assertEqual(params.get("metadataHeaders"), list(gna_import.IDENTITY_HEADERS))
        first, second = self.stored(self.ids[0]), self.stored(self.ids[1])
        self.assertEqual(first["message_id"], f"<{self.ids[0]}@letters.test>")
        self.assertEqual(second["in_reply_to"], f"<{self.ids[0]}@letters.test>")
        self.assertEqual(first["actor"], "gna-backfill-headers")
        self.assertTrue(first["headers_at"])
        self.assertEqual(first["thread_key"], "t-old", "Gmail's threadId must survive the backfill")

    def test_2_the_store_appends_so_the_row_that_lacked_them_survives(self):
        gna_import.backfill_headers(ACCOUNT)
        versions = self.spine_lines(self.ids[1])
        self.assertEqual(len(versions), 2, "the old version was written over, not appended")
        self.assertEqual(versions[0].get("message_id", ""), "", "the first version was rewritten")
        self.assertEqual(versions[-1]["message_id"], f"<{self.ids[1]}@letters.test>")
        self.assertEqual(versions[0]["subject"], versions[-1]["subject"], "the content was not carried over")

    def test_3_a_second_run_is_idempotent(self):
        gna_import.backfill_headers(ACCOUNT)
        before = len(gna_store.SPINE.read_text(encoding="utf-8").splitlines())
        self.transport.calls.clear()
        again = gna_import.backfill_headers(ACCOUNT)
        self.assertEqual(again["missing"], 0, again)
        self.assertEqual(again["filled"], 0, again)
        self.assertEqual(again["written"], 0, again)
        self.assertEqual(self.transport.calls, [], "a complete store was asked for its headers again")
        self.assertEqual(len(gna_store.SPINE.read_text(encoding="utf-8").splitlines()), before)

    def test_4_a_message_gone_from_the_mailbox_is_named_not_raised(self):
        gone_id = f"legacy-{self.tag}-gone"
        gna_store.append([dict(self.old[0], id=gone_id)])
        result = gna_import.backfill_headers(ACCOUNT)
        self.assertEqual(result["gone"], [gone_id], result)
        self.assertEqual(result["filled"], 2, result)
        self.assertEqual(result["written"], 2, result)


# ── two rows, one conversation, joined BY the header ────────────────────────────────


class ThreadedByHeader(unittest.TestCase):
    """A mailbox with NO threadId of its own: the only join left is the message's own chain.

    The two messages deliberately disagree about the subject, which is the whole point — a
    reply that rewrites its subject (`Re: something else entirely`) is one conversation with
    the message it answers, and two strangers with the same subject are two conversations."""

    FIRST = (
        b"From: Ada Example <ada@example.com>\r\n"
        b"To: headers@example.com\r\n"
        b"Subject: The invoice for October\r\n"
        b"Message-ID: <first@letters.test>\r\n"
        b"Date: Mon, 10 Nov 2026 09:00:00 +0000\r\n"
        b"Content-Type: text/plain; charset=utf-8\r\n\r\n"
        b"The invoice for October is attached.\r\n"
    )
    REPLY = (
        b"From: Ada Example <ada@example.com>\r\n"
        b"To: headers@example.com\r\n"
        b"Subject: Re: something else entirely\r\n"
        b"Message-ID: <reply@letters.test>\r\n"
        b"In-Reply-To: <first@letters.test>\r\n"
        b"References: <first@letters.test>\r\n"
        b"Date: Mon, 10 Nov 2026 11:00:00 +0000\r\n"
        b"Content-Type: text/plain; charset=utf-8\r\n\r\n"
        b"Thanks, paying today.\r\n"
    )

    def rows(self) -> list[dict]:
        return gna_import._imap_records(ACCOUNT, [(self.FIRST, "imap:1"), (self.REPLY, "imap:2")])

    def test_1_the_two_rows_are_joined_by_the_header(self):
        first, reply = self.rows()
        self.assertEqual(first["subject"], "The invoice for October")
        self.assertEqual(reply["subject"], "Re: something else entirely")
        self.assertEqual(first["thread_key"], "first@letters.test",
                         "the first message of a chain is joined by its own name")
        self.assertEqual(reply["thread_key"], first["thread_key"],
                         "the reply did not land in the conversation its headers name")
        self.assertEqual(reply["in_reply_to"], "<first@letters.test>")
        self.assertEqual(reply["references"], "<first@letters.test>")

    def test_2_a_chain_of_three_keeps_one_key(self):
        """The ROOT of the chain is the key, so a deeper reply does not open a second thread."""
        deep = self.REPLY.replace(b"In-Reply-To: <first@letters.test>",
                                  b"In-Reply-To: <reply@letters.test>").replace(
            b"References: <first@letters.test>",
            b"References: <first@letters.test> <reply@letters.test>").replace(
            b"Message-ID: <reply@letters.test>", b"Message-ID: <deep@letters.test>")
        rows = gna_import._imap_records(ACCOUNT, [(self.FIRST, "imap:1"), (self.REPLY, "imap:2"),
                                                 (deep, "imap:3")])
        self.assertEqual({row["thread_key"] for row in rows}, {"first@letters.test"})

    def test_3_joined_by_subject_they_would_be_strangers(self):
        first, reply = self.rows()
        by_subject = {first["subject"], reply["subject"]}
        self.assertEqual(len(by_subject), 2,
                         "the fixture only proves the header join if the subjects disagree")

    def test_4_the_join_has_an_effect_not_just_a_key(self):
        """The reply inherits the judgement of the thread it answers, through the header alone."""
        first, reply = self.rows()
        self.assertEqual(first["classification"], "invoice")
        self.assertEqual(reply["classification"], "invoice")
        self.assertEqual(reply["matched_by"], "thread", reply["evidence"])
        self.assertIn(first["thread_key"], reply["evidence"])


# ── a reply names the message it answers, through the letters door ──────────────────


class FakeGmail:
    """The two Gmail questions the letters door asks: which message carries this subject, and what is
    the message I am answering.

    The search answers the way the mailbox does — by subject, ignoring any leading `Re:` — so a proof
    can stand three letters in a mailbox and watch the door decide: one match is a thread, none or two
    are a refusal."""

    def __init__(self) -> None:
        self.messages: dict[str, dict] = {}
        self.asks: list[dict] = []
        self.searches: list[str] = []
        self.drafts: dict[str, bytes] = {}
        self.draft_threads: dict[str, str] = {}

    @staticmethod
    def normalised(subject: str) -> str:
        """The same reading the door makes: every leading Re:, whitespace collapsed, case folded."""
        text = (subject or "").strip()
        while True:
            match = re.match(r"(?is)^\s*re\s*:\s*", text)
            if not match:
                break
            text = text[match.end():]
        return re.sub(r"\s+", " ", text).strip().lower()

    def matching(self, query: str) -> list[str]:
        """The ids a `subject:"…"` search returns, in the mailbox's own order."""
        term = query
        match = re.match(r'\s*subject\s*:\s*"(.*)"\s*$', query, re.S)
        if match:
            term = match.group(1)
        want = self.normalised(term)
        found = []
        for message_id, message in self.messages.items():
            headers = {h.get("name", "").lower(): h.get("value", "")
                       for h in ((message.get("payload") or {}).get("headers") or [])}
            if self.normalised(headers.get("subject", "")) == want:
                found.append(message_id)
        return found

    def serve(self) -> ThreadingHTTPServer:
        api = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *a):  # the proof is the record, not the access log
                pass

            def _json(self, code: int, doc) -> None:
                raw = json.dumps(doc).encode()
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)

            def do_POST(self) -> None:
                u = urlparse(self.path)
                length = int(self.headers.get("Content-Length") or 0)
                body = self.rfile.read(length) if length else b""
                if u.path == "/token":
                    return self._json(200, {"access_token": "fake-token", "expires_in": 3600})
                if u.path == "/gmail/v1/users/me/drafts":
                    payload = json.loads(body or b"{}")
                    message = payload.get("message") or {}
                    raw = message.get("raw") or ""
                    draft_id = f"r-auto-{len(api.drafts) + 1}"
                    api.drafts[draft_id] = base64.urlsafe_b64decode(raw) if raw else b""
                    api.draft_threads[draft_id] = message.get("threadId") or ""
                    return self._json(200, {"id": draft_id, "message": {"id": "m-" + draft_id}})
                return self._json(404, {"error": {"message": "not asked for in this proof"}})

            def do_GET(self) -> None:
                u = urlparse(self.path)
                if u.path == "/gmail/v1/users/me/messages":
                    query = (parse_qs(u.query).get("q") or [""])[0]
                    api.searches.append(query)
                    ids = api.matching(query)
                    return self._json(200, {"messages": [{"id": i, "threadId": api.messages[i]["threadId"]}
                                                        for i in ids],
                                            "resultSizeEstimate": len(ids)})
                match = re.match(r"^/gmail/v1/users/me/messages/([^/]+)$", u.path)
                if not match:
                    return self._json(404, {"error": {"message": "not asked for in this proof"}})
                message_id = unquote(match.group(1))
                query = parse_qs(u.query)
                api.asks.append({"id": message_id,
                                 "format": (query.get("format") or [""])[0],
                                 "headers": query.get("metadataHeaders") or []})
                found = api.messages.get(message_id)
                if not found:
                    return self._json(404, {"error": {"message": "message not found"}})
                return self._json(200, found)

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        return server


class MxFixture:
    """Every MX question answered by one record, so a `.test` recipient is deliverable offline."""

    def __init__(self) -> None:
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("127.0.0.1", 0))
        self.sock.settimeout(0.3)
        self.port = self.sock.getsockname()[1]
        self.stop = False
        threading.Thread(target=self._serve, daemon=True).start()

    def _serve(self) -> None:
        while not self.stop:
            try:
                packet, peer = self.sock.recvfrom(2048)
            except socket.timeout:
                continue
            except OSError:
                return
            try:
                ident, _, qdcount = struct.unpack(">HHH", packet[:6])
                if qdcount != 1 or packet[12] == 0:
                    continue
                index = 12
                while packet[index] != 0:
                    index += 1 + packet[index]
                question = packet[12:index + 5]
                rdata = struct.pack(">H", 10) + b"\xc0\x0c"
                answer = b"\xc0\x0c" + struct.pack(">HHIH", 15, 1, 60, len(rdata)) + rdata
                self.sock.sendto(struct.pack(">HHHHHH", ident, 0x8180, 1, 1, 0, 0) + question + answer, peer)
            except (struct.error, IndexError):
                continue

    def close(self) -> None:
        self.stop = True
        self.sock.close()


class LettersDoor(Door):
    """One throwaway home, one Gmail stand-in, one MX responder, and the letters door's draft helper.

    The proofs below all ask the same question of that door — *what does the letter that leaves say
    about the message it answers?* — so they share the fixture and differ only in the mailbox they
    stand up and the arguments they hand it."""

    MESSAGE_ID = "<alpha-1@letters.test>"

    def setUp(self) -> None:
        super().setUp()
        self.tmp = Path(tempfile.mkdtemp(prefix="gna-headers-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        home = self.tmp / "home"
        secrets = home / "hodd/secrets"
        secrets.mkdir(parents=True)
        key = secrets / "age.key"
        subprocess.run(["age-keygen", "-o", str(key)], check=True, capture_output=True)
        recipient = subprocess.run(["age-keygen", "-y", str(key)], check=True,
                                   capture_output=True, text=True).stdout.strip()
        plain = ("GOOGLE_MCP_CLIENT_ID=fake-client\n"
                 "GOOGLE_MCP_CLIENT_SECRET=fake-secret\n"
                 "SNOTRA_GOOGLE_REFRESH_TOKEN=fake-refresh\n")
        subprocess.run(["age", "-e", "-r", recipient, "-o", str(secrets / "platform.env.age")],
                       input=plain.encode(), check=True)

        self.gmail = FakeGmail()
        self.gmail.messages["alpha-1"] = {
            "id": "alpha-1",
            "threadId": "t-alpha",
            "payload": {"headers": [
                {"name": "Message-ID", "value": self.MESSAGE_ID},
                {"name": "References", "value": "<alpha-0@letters.test>"},
                {"name": "Subject", "value": "The plan for the quarter"},
            ]},
        }
        server = self.gmail.serve()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.dns = MxFixture()
        self.addCleanup(self.dns.close)
        port = server.server_address[1]
        self.env = {**os.environ,
                    "YMIR_HOME": str(home),
                    "YMIR_GMAIL_API_BASE": f"http://127.0.0.1:{port}/gmail/v1",
                    "YMIR_OAUTH_TOKEN_URL": f"http://127.0.0.1:{port}/token",
                    "GNA_DNS_SERVER": f"127.0.0.1:{self.dns.port}"}

    def draft(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(["bash", str(MAIL), "draft", *args],
                              capture_output=True, text=True, env=self.env, timeout=180)

    def import_the_message(self) -> dict:
        self.use(RecordingGmail([with_headers(
            gmail_message("alpha-1", int(time.time()) - 120, "The plan for the quarter"),
            self.MESSAGE_ID)], ACCOUNT))
        rc, out = self.run_import()
        self.assertEqual(rc, 0, out)
        return self.stored("alpha-1")

    def seed(self, message_id: str, thread_id: str, subject: str, message_name: str,
             sender: str = "Partner <partner@letters.test>", date: str = "Mon, 16 Nov 2026 09:00:00 +0000") -> None:
        """Stand one more message in the mailbox, so a proof can ask what one, none or two matches do."""
        self.gmail.messages[message_id] = {
            "id": message_id,
            "threadId": thread_id,
            "payload": {"headers": [
                {"name": "Message-ID", "value": message_name},
                {"name": "References", "value": ""},
                {"name": "Subject", "value": subject},
                {"name": "From", "value": sender},
                {"name": "Date", "value": date},
            ]},
        }

    def reply(self, *args: str, body_text: str = "Agreed, and one question.\n") -> subprocess.CompletedProcess:
        body = self.tmp / "reply.md"
        body.write_text(body_text, encoding="utf-8")
        return self.draft("--to", "partner@letters.test", "--body", str(body), "--plain", *args)

    def letter(self, r: subprocess.CompletedProcess):
        """The exact bytes the door would have sent: `--dry-run` writes the .eml and posts nothing."""
        self.assertEqual(r.returncode, 0, r.stderr)
        printed = [line for line in r.stdout.splitlines() if line.startswith("eml\t")]
        self.assertTrue(printed, f"the door printed no draft: {r.stdout}{r.stderr}")
        return BytesParser(policy=policy.default).parsebytes(Path(printed[-1].split("\t", 1)[1]).read_bytes())


class LettersDoorNamesTheMessageItAnswers(LettersDoor):
    """THE LOOP, CLOSED WITH THE REAL DOORS: the importer keeps the name, and the letters door
    puts that name in `In-Reply-To` and `References` when it drafts the answer.

    `draft --dry-run` renders the exact bytes the door would send (the send path posts those
    bytes unchanged), so the .eml is the letter — no send socket is opened in a proof."""

    def test_1_a_reply_names_the_message_it_answers(self):
        stored = self.import_the_message()
        self.assertEqual(stored["message_id"], self.MESSAGE_ID)

        body = self.tmp / "reply.md"
        body.write_text("Agreed, and one question.\n", encoding="utf-8")
        r = self.draft("--to", "partner@letters.test", "--body", str(body), "--plain",
                       "--reply-to", "alpha-1", "--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        printed = [line for line in r.stdout.splitlines() if line.startswith("eml\t")]
        self.assertTrue(printed, f"the door printed no draft: {r.stdout}{r.stderr}")
        raw = Path(printed[-1].split("\t", 1)[1]).read_bytes()
        letter = BytesParser(policy=policy.default).parsebytes(raw)

        self.assertEqual(letter["In-Reply-To"].strip(), stored["message_id"],
                         "the reply does not name the message the store says it answers")
        self.assertIn(stored["message_id"], letter["References"])
        self.assertEqual(letter["Subject"], "Re: The plan for the quarter")

    def test_2_the_reply_reads_metadata_and_never_the_body(self):
        self.import_the_message()
        body = self.tmp / "reply.md"
        body.write_text("Agreed.\n", encoding="utf-8")
        r = self.draft("--to", "partner@letters.test", "--body", str(body), "--plain",
                       "--reply-to", "alpha-1", "--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(self.gmail.asks, "the door read nothing about the message it answers")
        asked = self.gmail.asks[-1]
        self.assertEqual(asked["id"], "alpha-1")
        self.assertEqual(asked["format"], "metadata", "a reply read the message body to learn its name")
        self.assertIn("Message-ID", asked["headers"])
        self.assertIn("References", asked["headers"])


# ── a "Re:" subject is a claim the door must prove (2026-11-17) ─────────────────────


class AReSubjectNamesItsMessage(LettersDoor):
    """Three letters went out in one night with `Re:` subjects that began NEW threads.

    The subject is the only name a person has for the message they are answering, so the door now
    reads a `Re:` subject as a claim and proves it against the mailbox: exactly one message carries
    that subject (normalised), or the letter is refused with the reason and the candidates named.
    Six proofs, one per promise:

      test_1  one match → In-Reply-To, References and the thread, and it says which message it answers
      test_2  no match → REFUSED, named reason, nothing drafted
      test_3  two matches → REFUSED, both candidates listed, nothing drafted
      test_4  --new-thread → no threading headers, and no lookup either
      test_5  a non-`Re:` subject → unchanged, and the mailbox is never asked
      test_6  --reply-to given → the operator's naming wins over any inference
      test_7  --reply-to with --new-thread → refused as contradictory
    """

    SUBJECT = "The plan for the quarter"

    def test_1_one_match_joins_the_thread_and_says_which_message(self):
        # a different case and spacing proves the normalisation, not a lucky string match
        r = self.reply("--subject", "re:   THE PLAN for the quarter")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("answers\talpha-1", r.stderr,
                      "the door did not say which message it answers")
        self.assertIn(self.SUBJECT, r.stderr)

        draft_id = r.stdout.split("\t")[1]
        letter = BytesParser(policy=policy.default).parsebytes(self.gmail.drafts[draft_id])
        self.assertEqual(letter["In-Reply-To"], self.MESSAGE_ID,
                         "the reply does not name the message whose subject it repeats")
        self.assertIn(self.MESSAGE_ID, letter["References"])
        self.assertEqual(letter["Subject"], "re:   THE PLAN for the quarter",
                         "the operator's own words were rewritten")
        self.assertEqual(self.gmail.draft_threads[draft_id], "t-alpha",
                         "the letter was not placed in the thread it answers")

    def test_2_no_match_refuses_and_names_the_reason(self):
        r = self.reply("--subject", "Re: Something nobody wrote about", "--dry-run")
        self.assertNotEqual(r.returncode, 0, "a reply to a message that does not exist was drafted")
        self.assertIn("REFUSED", r.stderr)
        self.assertIn("no message in the mailbox carries that subject", r.stderr)
        self.assertIn("--new-thread", r.stderr, "the refusal does not name a way forward")
        self.assertEqual(self.gmail.drafts, {}, "the door posted a draft it had refused")

    def test_3_two_matches_refuses_and_lists_the_candidates(self):
        self.seed("alpha-2", "t-alpha-2", self.SUBJECT, "<alpha-2@letters.test>",
                  sender="Other Partner <other@letters.test>",
                  date="Tue, 17 Nov 2026 10:00:00 +0000")
        r = self.reply("--subject", "Re: " + self.SUBJECT, "--dry-run")
        self.assertNotEqual(r.returncode, 0, "the door guessed between two messages with one subject")
        self.assertIn("2 messages in the mailbox carry that subject", r.stderr)
        self.assertIn("alpha-1", r.stderr, "the refusal does not list the candidates")
        self.assertIn("alpha-2", r.stderr, "the refusal does not list the candidates")
        self.assertIn("other@letters.test", r.stderr, "the listing does not say who wrote them")
        self.assertIn("--reply-to", r.stderr, "the refusal does not say how to choose")
        self.assertEqual(self.gmail.drafts, {})

    def test_4_new_thread_starts_one_without_headers(self):
        letter = self.letter(self.reply("--subject", "Re: " + self.SUBJECT,
                                        "--new-thread", "--dry-run"))
        self.assertIsNone(letter["In-Reply-To"], "--new-thread still named a message it answers")
        self.assertIsNone(letter["References"])
        self.assertEqual(self.gmail.searches, [],
                         "--new-thread was supposed to start a conversation, not look one up")

    def test_5_a_subject_that_is_not_a_reply_is_unchanged(self):
        letter = self.letter(self.reply("--subject", "A plan for the quarter", "--dry-run"))
        self.assertIsNone(letter["In-Reply-To"])
        self.assertIsNone(letter["References"])
        self.assertEqual(self.gmail.searches, [], "a subject that promised nothing was still looked up")

    def test_6_an_explicit_reply_to_wins_over_the_inference(self):
        self.seed("alpha-2", "t-alpha-2", self.SUBJECT, "<alpha-2@letters.test>")
        letter = self.letter(self.reply("--subject", "Re: " + self.SUBJECT,
                                        "--reply-to", "alpha-1", "--dry-run"))
        self.assertEqual(letter["In-Reply-To"], self.MESSAGE_ID,
                         "the door inferred over a message the operator named itself")
        self.assertEqual(self.gmail.searches, [],
                         "an explicit --reply-to still went looking for a subject")

    def test_7_a_new_thread_and_a_reply_to_are_refused_together(self):
        r = self.reply("--subject", "Re: " + self.SUBJECT, "--reply-to", "alpha-1",
                       "--new-thread", "--dry-run")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("REFUSED", r.stderr)
        self.assertIn("--new-thread", r.stderr)
        self.assertIn("--reply-to", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
