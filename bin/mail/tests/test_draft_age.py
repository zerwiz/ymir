#!/usr/bin/env python3
"""The proofs for `bin/mail/draft-age.sh` — a draft cannot grow old quietly.

The Allfather's brief (2026-11-16): a draft may not sit in the mailbox for days while the
morning brief reports a clean day. The door reads Gmail's drafts, gives each one its age in
days, and exits non-zero — naming every offender — when one is older than the limit. With no
grant it says so by name instead of printing a zero that reads like an empty outbox.

What is proven here, and why each one is a hole worth a test:

  NoDrafts      an empty outbox is a clean day, and it says "none" — not a blank.
  FreshDraft    a draft younger than the limit is listed with its age and passes.
  AgedDraft     a draft older than the limit FAILS the door and is named with its age and
                subject, so the operator knows which letter is late.
  TheLimit      --days moves the line, and the far side of it changes the verdict.
  NoGrant       no Google key on this seat is a NAMED skip (exit 0), never "0 drafts".
  Unreadable    a drafts list that answers 401 is UNABLE (exit 3), never a clean zero.
  Paging        a draft on the second page is seen; a limit that hides a draft cannot
                become a green day.
  ReadOnly      the stub saw GETs and the token POST only — nothing in this directory can
                write to the mailbox, and the door proves it by what it never asked for.
  TheBriefing   `bin/time/nornir-job-daily-briefing.sh` carries the line, and an aged draft
                makes it publish a brief that is not clean and exit non-zero.

The Gmail API is stood in for by a local HTTP server, and the endpoints are configuration
(Rule 07: YMIR_GMAIL_API_BASE · YMIR_OAUTH_TOKEN_URL). Nothing here talks to Google.

    python3 bin/mail/tests/test_draft_age.py               # every proof
    python3 bin/mail/tests/test_draft_age.py AgedDraft     # one of them
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DOOR = ROOT / "bin/mail/draft-age.sh"
BRIEF = ROOT / "bin/time/nornir-job-daily-briefing.sh"
DAY = 86400.0


# ── the Gmail API, stood in for ──────────────────────────────────────────────────────


class Api:
    """What the door asked for, and the drafts the mailbox holds."""

    def __init__(self) -> None:
        # draft id -> {subject, to, age_seconds}
        self.drafts: dict[str, dict] = {}
        self.requests: list[tuple[str, str]] = []
        self.tokens = 0
        self.page_size = 100

    def add(self, draft_id: str, subject: str, age_seconds: float, to: str = "partner@example.com") -> None:
        self.drafts[draft_id] = {"subject": subject, "to": to, "age_seconds": age_seconds}

    def draft_doc(self, draft_id: str) -> dict:
        return {"id": draft_id, "message": {"id": "m-" + draft_id}}


def make_server(api: Api) -> ThreadingHTTPServer:
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, *a):  # the proofs are the record, not an access log
            pass

        def _json(self, code: int, doc) -> None:
            raw = json.dumps(doc).encode()
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

        def do_POST(self):
            api.requests.append(("POST", self.path))
            n = int(self.headers.get("Content-Length") or 0)
            if n:
                self.rfile.read(n)
            if urllib.parse.urlparse(self.path).path == "/token":
                api.tokens += 1
                return self._json(200, {"access_token": "fake-token", "expires_in": 3600})
            return self._json(404, {"error": {"message": "no such door"}})

        def do_GET(self):
            u = urllib.parse.urlparse(self.path)
            api.requests.append(("GET", self.path))
            if u.path == "/gmail/v1/users/me/drafts":
                if getattr(api, "unauthorised", False):
                    return self._json(401, {"error": {"message": "Invalid Credentials"}})
                query = urllib.parse.parse_qs(u.query)
                page = int((query.get("pageToken") or ["0"])[0])
                ids = list(api.drafts)
                start = page * api.page_size
                chunk = ids[start:start + api.page_size]
                doc: dict = {"drafts": [api.draft_doc(i) for i in chunk]}
                if start + api.page_size < len(ids):
                    doc["nextPageToken"] = str(page + 1)
                return self._json(200, doc)
            m = re.match(r"^/gmail/v1/users/me/messages/([^/]+)$", u.path)
            if m:
                mid = urllib.parse.unquote(m.group(1))
                draft_id = mid[2:] if mid.startswith("m-") else mid
                entry = api.drafts.get(draft_id)
                if entry is None:
                    return self._json(404, {"error": {"message": "message not found"}})
                when = int((time.time() - entry["age_seconds"]) * 1000)
                return self._json(200, {
                    "id": mid,
                    "threadId": "t-" + draft_id,
                    "internalDate": str(when),
                    "payload": {"headers": [
                        {"name": "Subject", "value": entry["subject"]},
                        {"name": "To", "value": entry["to"]},
                    ]},
                })
            return self._json(404, {"error": {"message": "no such door"}})

    srv = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    return srv


# ── one throwaway home, one stub mailbox, per proof ─────────────────────────────────


class Case(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp(prefix="draft-age-test-"))
        self.addCleanup(shutil.rmtree, self.tmp, True)
        self.api = Api()
        self.srv = make_server(self.api)
        self.addCleanup(self.srv.server_close)
        self.addCleanup(self.srv.shutdown)
        port = self.srv.server_address[1]

        self.home = self.tmp / "home"
        sec = self.home / "hodd/secrets"
        sec.mkdir(parents=True)
        # The vault's plaintext record, which the door reads only when the encrypted vault is
        # not openable on this machine — the same fallback bin/notify/mail.sh uses.
        (sec / "platform.env").write_text(
            "GOOGLE_MCP_CLIENT_ID=fake-client\n"
            "GOOGLE_MCP_CLIENT_SECRET=fake-secret\n"
            "SNOTRA_GOOGLE_REFRESH_TOKEN=fake-refresh\n",
            encoding="utf-8",
        )
        self.state = self.tmp / "state"
        self.state.mkdir()
        self.env = {
            **os.environ,
            "YMIR_HOME": str(self.home),
            "BROKK_HOME": str(ROOT),
            # the pane exports the PRIMARY checkout as the root override; this tree is the
            # subject, so the briefing must resolve its own doors from here.
            "BROKK_ROOT_OVERRIDE": str(ROOT),
            "BROKK_STATE_OVERRIDE": str(self.state),
            "BROKK_DATA_OVERRIDE": str(self.tmp / "data"),
            "BROKK_BRIEF_DIR": str(self.tmp / "brief"),
            "BROKK_RUNES_FILE": str(self.tmp / "runes.md"),
            "YMIR_GMAIL_API_BASE": f"http://127.0.0.1:{port}/gmail/v1",
            "YMIR_OAUTH_TOKEN_URL": f"http://127.0.0.1:{port}/token",
        }
        for name in ("GOOGLE_MCP_CLIENT_ID", "GOOGLE_MCP_CLIENT_SECRET",
                     "SNOTRA_GOOGLE_REFRESH_TOKEN", "YMIR_DRAFT_MAX_DAYS"):
            self.env.pop(name, None)

    # helpers ---------------------------------------------------------------------

    def door(self, *args: str, env: dict | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(["bash", str(DOOR), *args], capture_output=True, text=True,
                              env={**self.env, **(env or {})}, timeout=120)

    def brief(self, env: dict | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(["bash", str(BRIEF)], capture_output=True, text=True,
                              env={**self.env, **(env or {})}, timeout=180)

    def brief_text(self) -> str:
        files = sorted((self.tmp / "brief").glob("*.md"))
        self.assertTrue(files, "the briefing published nothing")
        return files[-1].read_text(encoding="utf-8")


# ── the three cases the brief names ─────────────────────────────────────────────────


class NoDrafts(Case):
    def test_an_empty_outbox_is_a_clean_day_and_says_none(self):
        r = self.door()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('"empty"', r.stdout)
        self.assertIn("drafts[0]{id,age_days,subject}:", r.stdout)
        self.assertIn("aged[0]{id,age_days,subject}:", r.stdout)
        brief = self.door("--brief")
        self.assertEqual(brief.returncode, 0, brief.stderr)
        self.assertIn("drafts: none", brief.stdout, "an empty outbox must say none, not nothing")


class FreshDraft(Case):
    def test_a_fresh_draft_passes_and_carries_its_age(self):
        self.api.add("r-fresh", "Re: the quarter plan", 6 * 3600)  # six hours old
        r = self.door()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('"clean",2,1,0', r.stdout)
        self.assertIn("Re: the quarter plan", r.stdout)
        self.assertIn('"r-fresh",0.2,', r.stdout, "six hours is a fraction of a day, and the door must show it")
        self.assertNotIn("AGED:", r.stdout)


class AgedDraft(Case):
    def test_a_draft_older_than_the_limit_fails_and_is_named(self):
        self.api.add("r-fresh", "Re: the quarter plan", 6 * 3600)
        self.api.add("r-old", "The letter I never sent", 5 * DAY)
        r = self.door()
        self.assertEqual(r.returncode, 1, "an aged draft must fail the door\n" + r.stdout)
        self.assertIn('"aged",2,2,1', r.stdout)
        self.assertIn("The letter I never sent", r.stdout)
        self.assertIn("AGED:", r.stdout)
        brief = self.door("--brief")
        self.assertEqual(brief.returncode, 1, brief.stdout)
        self.assertIn("1 of 2 older than 2 days", brief.stdout)
        self.assertIn('"The letter I never sent" (5 days)', brief.stdout, brief.stdout)
        self.assertIn("r-old", r.stdout.split("aged[1]")[1], "the aged list must name the draft id")


class TheLimit(Case):
    def test_days_moves_the_line_and_the_verdict_follows_it(self):
        self.api.add("r-three", "A note to the partner", 3 * DAY)
        self.assertEqual(self.door().returncode, 1, "three days is older than the default two")
        self.assertEqual(self.door("--days", "5").returncode, 0, "three days is inside a five-day limit")
        self.assertEqual(self.door("--days", "3").returncode, 0, "exactly three days is not older than three")
        self.assertEqual(self.door("--days=2").returncode, 1)


# ── the holes that would let a zero lie ─────────────────────────────────────────────


class NoGrant(Case):
    def test_no_grant_is_a_named_skip_and_never_a_zero(self):
        (self.home / "hodd/secrets/platform.env").write_text("SOMETHING_ELSE=x\n", encoding="utf-8")
        r = self.door()
        self.assertEqual(r.returncode, 0, "a skip is not a failed mailbox")
        self.assertIn('"skipped"', r.stdout)
        self.assertIn("SKIP no-grant", r.stdout)
        self.assertIn("no Google", r.stdout)
        self.assertNotIn("drafts[0]", r.stdout, "a skip must not print an empty outbox")
        brief = self.door("--brief")
        self.assertIn("drafts: SKIP", brief.stdout)
        self.assertEqual(self.api.tokens, 0, "no grant must not reach the token door")
        self.assertEqual([q for q in self.api.requests], [], "no grant must not read the mailbox")


class Unreadable(Case):
    def test_a_refused_list_is_unable_not_a_clean_zero(self):
        self.api.unauthorised = True
        r = self.door()
        self.assertEqual(r.returncode, 3, r.stdout + r.stderr)
        self.assertIn("UNABLE", r.stdout)
        self.assertIn("401", r.stdout)
        brief = self.door("--brief")
        self.assertIn("drafts: UNABLE", brief.stdout)


class Paging(Case):
    def test_a_draft_on_the_second_page_is_seen(self):
        self.api.page_size = 2
        self.api.add("r-a", "first", 1 * 3600)
        self.api.add("r-b", "second", 2 * 3600)
        self.api.add("r-c", "the old one", 9 * DAY)  # page two
        r = self.door()
        self.assertEqual(r.returncode, 1, "a draft on page two must not be invisible\n" + r.stdout)
        self.assertIn("the old one", r.stdout)
        self.assertTrue(any("pageToken=1" in path for _, path in self.api.requests),
                        "the door never asked for the second page")


class ReadOnly(Case):
    def test_the_stub_saw_no_write(self):
        self.api.add("r-fresh", "Re: the quarter plan", 3600)
        self.door()
        writes = [(m, p) for m, p in self.api.requests
                  if m != "GET" and not p.startswith("/token")]
        self.assertEqual(writes, [], f"the drafts door wrote to the mailbox: {writes}")
        self.assertTrue(all(m in ("GET", "POST") for m, _ in self.api.requests))
        self.assertEqual(self.api.tokens, 1, "one token, one read")


# ── the brief the operator reads ────────────────────────────────────────────────────


class TheBriefing(Case):
    def test_a_fresh_draft_leaves_the_brief_clean(self):
        self.api.add("r-fresh", "Re: the quarter plan", 6 * 3600)
        r = self.brief()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        text = self.brief_text()
        self.assertIn("The letters nobody sent", text)
        self.assertIn("none older than 2 days", text)
        self.assertNotIn("Unwritten letters have aged", text)

    def test_an_aged_draft_makes_the_brief_not_clean(self):
        self.api.add("r-old", "The letter I never sent", 4 * DAY)
        r = self.brief()
        self.assertEqual(r.returncode, 1, "the brief published a clean day over an aged draft\n" + r.stdout)
        text = self.brief_text()
        self.assertIn("Unwritten letters have aged", text, "the published brief must carry the alarm, not hide it")
        self.assertIn("The letter I never sent", text)
        self.assertIn("older than 2 days", text)

    def test_a_skip_is_carried_into_the_brief_by_name(self):
        (self.home / "hodd/secrets/platform.env").write_text("SOMETHING_ELSE=x\n", encoding="utf-8")
        r = self.brief()
        self.assertEqual(r.returncode, 0, "a skip must not fail the morning brief")
        text = self.brief_text()
        self.assertIn("drafts: SKIP", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
