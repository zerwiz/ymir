#!/usr/bin/env python3
"""The proofs plan 261 asks for: the record, the owed list, the to-do proposals, the brief,
and Telegram recorded both ways. Every test runs against a fixture home — never the real hoard.

Run: python3 -m unittest discover -s bin/records/tests -p 'test_comms.py'
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs

HERE = Path(__file__).resolve().parent
RECORDS = HERE.parent
ROOT = RECORDS.parent.parent

TMP = Path(tempfile.mkdtemp(prefix="comms-test-"))
os.environ["YMIR_HOME"] = str(TMP)
os.environ["COMMS_NOW"] = "2026-11-12T01:00:00+00:00"
os.environ["COMMS_OFFLINE"] = "0"
sys.path.insert(0, str(RECORDS))
import comms  # noqa: E402

ME = {"name": "Operator", "email": "op@example.com"}
ASKER = {"name": "Rey Asker", "email": "rey@example.org"}
PARTNER = {"name": "Carl Partner", "email": "carl@example.com"}


def mail(mid, direction, at, subject, frm, to, body="", cls="other", action="archive", thread=None):
    return {"id": mid, "account": ME["email"], "direction": direction, "thread_key": thread or mid,
            "from": frm, "to": [to] if isinstance(to, dict) else to, "cc": [], "subject": subject,
            "body_text": body, "classification": cls, "proposed_action": action, "handled_at": None,
            "received_at": at, "person_id": None, "project_id": None}


MAILS = [
    # the platform signature request — and its reminders are only in the live mailbox
    mail("s1", "in", "2026-10-23T19:08:00+00:00", "Please complete Acme_Devagreement_v2",
         {"name": "Rey Asker via SignWell", "email": "docs@signwell.example.net"}, ME,
         "Rey Asker says: please complete the development agreement.", "notice"),
    # another document finished on the same platform — it must NOT tick this item
    mail("s0", "in", "2026-10-16T10:45:00+00:00", "Document completed (Other_NDA_v1)",
         {"name": "SignWell", "email": "docs@signwell.example.net"}, ME, "", "notice"),
    # an older invitation to a different account, from the same platform
    mail("a0", "in", "2026-10-30T08:28:00+00:00", "You are invited to Someone Else AB on ledgerly",
         {"name": "Ledgerly", "email": "noreply@ledgerly.example.net"}, ME,
         "Invited to Someone Else AB on ledgerly by other@example.org.", "notice"),
    # the invitation the item means
    mail("a1", "in", "2026-11-06T07:26:00+00:00", "You are invited to Acme Invest AB on ledgerly",
         {"name": "Ledgerly", "email": "noreply@ledgerly.example.net"}, ME,
         "Invited to Acme Invest AB on ledgerly by rey@example.org. The link is valid for 7 days.", "notice"),
    # the asker, three days later, working with him inside that account
    mail("a2", "in", "2026-11-09T15:14:00+00:00", "Rey Asker mentioned you on the card Get Ledgerly Paid plan",
         {"name": "Trello", "email": "do-not-reply@notify.example.net"}, ME,
         "Rey Asker mentioned you. Here is the key for Acme Invest AB's paid ledgerly account.", "notice"),
    # the two playbook letters, sent
    mail("p1", "out", "2026-11-06T18:05:00+00:00", "The delivery playbook, v1.3 — for your audit",
         ME, {"name": "Rey Asker", "email": "rey@example.org"}),
    mail("p2", "out", "2026-11-06T18:05:30+00:00", "The delivery playbook, v1.3 — for your audit",
         ME, {"name": "Carl Partner", "email": "carl@example.com"}),
    # a Foreman mail to Carl that must NOT tick "Ask Carl to merge Foreman PR #20"
    mail("f1", "out", "2026-11-10T16:38:00+00:00", "Foreman — the audit, and the one defect",
         ME, {"name": "Carl Partner", "email": "carl@example.com"}),
    # an incoming question that needs him
    mail("q1", "in", "2026-11-11T09:00:00+00:00", "Can we move Friday's meeting?",
         {"name": "Sam Guest", "email": "sam@example.net"}, ME, "Can we?", "question", "reply_needed"),
    # a question he asked, unanswered
    mail("w1", "out", "2026-11-10T09:00:00+00:00", "Do you want in?", ME,
         {"name": "Vic Friend", "email": "vic@example.net"}, "Ten minutes, honest answer — do you want in?"),
]

TODO = """# The Allfather's day

---

# His half — what only he can do

## Today

- [ ] **Rödd carries Sam's mail** — set by him.

- [ ] **Accept the Ledgerly invitation** — from `rey@example.org`, arrived this morning,
      link expires in seven days.
- [ ] **Send the two playbook drafts** — written and waiting (`r-5967…` to Rey,
      `r2252…` to Carl).
- [ ] **Confirm the development agreement on SignWell** — the October request.
- [ ] **Answer Rey on "Activate our Trello Agent"** — mentioned today.

## This week

- [ ] **Ask Carl to merge Foreman PR #20** — until then documents need a PR.
- [ ] **Decide the studio's four open questions** — whose studio on paper.

---

# The derived half — what the house measured

- [ ] a derived line the house wrote — never his item.
"""

LIVE = {  # the platform's own series, answered by the read-only search
    "in:anywhere from:signwell.example.net newer_than:60d": [
        {"id": "r2", "subject": "Reminder: Please complete Acme_Devagreement_v2", "date": "Thu, 29 Oct 2026 19:33:31 +0100"},
        {"id": "r1", "subject": "Reminder: Please complete Acme_Devagreement_v2", "date": "Mon, 26 Oct 2026 19:33:26 +0100"},
        {"id": "s0", "subject": "Document completed (Other_NDA_v1)", "date": "Fri, 16 Oct 2026 10:45:56 +0200"},
    ],
}


def seed():
    (TMP / "hodd/memory/mail").mkdir(parents=True, exist_ok=True)
    (TMP / "hodd/memory/mail/messages.jsonl").write_text("".join(json.dumps(m) + "\n" for m in MAILS))
    for shelf in ("letters", "mail-drafts", "mail/drafts", "collab/letters", "notify/approvals"):
        (TMP / "hodd/state" / shelf).mkdir(parents=True, exist_ok=True)
    (TMP / "hodd/state/letters/2026-11-06-playbook-audit-carl.txt").write_text("Carl,\n\nThe playbook.\n")
    (TMP / "hodd/state/letters/2026-11-06-playbook-audit-carl.html").write_text("<p>Carl,</p>")
    (TMP / "hodd/state/mail-drafts/sam-notes.md").write_text("Sam,\n\nNotes.\n")
    (TMP / "hodd/state/mail/drafts/vic-login.md").write_text("Hi Vic,\n\nYour login.\n")
    (TMP / "hodd/state/collab/letters/2026-11-03-to-sam.md").write_text("# Letter to Sam — the door\n\nSam,\n")
    (TMP / "hodd/state/notify/approvals/abc.json").write_text(json.dumps(
        {"id": "abc", "question": "Approve the bot to stay armed?", "asked_at": "2026-10-21T20:58:48+0300",
         "decision": None}))
    (TMP / "hodd/state/notify/approvals/done.json").write_text(json.dumps(
        {"id": "done", "question": "Old", "asked_at": "2026-10-01", "decision": "yes"}))
    fx = TMP / "live.json"
    fx.write_text(json.dumps(LIVE))
    os.environ["COMMS_GMAIL_FIXTURE"] = str(fx)
    todo = TMP / "hodd/life/personal/me/todo.md"
    todo.parent.mkdir(parents=True, exist_ok=True)
    todo.write_text(TODO)
    return todo


class TheRecord(unittest.TestCase):
    def setUp(self):
        seed()

    def test_mail_is_read_where_it_lies_never_copied(self):
        rows = comms.mail_rows()
        self.assertEqual(len(rows), len(MAILS))
        self.assertFalse((TMP / "hodd/memory/comms/mail.jsonl").exists())
        self.assertFalse(comms.append("mail", "in", "x"))
        r = next(x for x in rows if x["ref"] == "p2")
        self.assertEqual((r["channel"], r["direction"], r["who"]), ("mail", "out", "carl@example.com"))

    def test_a_telegram_row_has_the_one_shape(self):
        self.assertTrue(comms.append("telegram", "in", "operator", thread="1", ref="7", text="hello"))
        row = comms.channel_rows("telegram")[-1]
        for k in comms.ROW_KEYS:
            self.assertIn(k, row)
        self.assertEqual(row["direction"], "in")
        self.assertFalse(comms.append("telegram", "sideways", "x"))


class TheOwedList(unittest.TestCase):
    def test_every_shelf_is_named_once(self):
        seed()
        os.environ["COMMS_OFFLINE"] = "1"
        try:
            rows = comms.owed(live=True)
        finally:
            os.environ["COMMS_OFFLINE"] = "0"
        shelves = {r["shelf"] for r in rows}
        self.assertEqual(shelves, {"letters", "mail-drafts", "mail/drafts", "collab/letters", "approvals"})
        self.assertEqual(sum(1 for r in rows if r["shelf"] == "letters"), 1, "one letter in two dresses")
        who = {r["path"].split("/")[-1]: r["for"] for r in rows}
        self.assertEqual(who["sam-notes.md"], "Sam")
        self.assertEqual(who["vic-login.md"], "Vic")
        self.assertEqual(who["2026-11-03-to-sam.md"], "Sam")
        self.assertNotIn("done.json", who, "an answered approval is not owed")


class TheTodo(unittest.TestCase):
    def test_it_proposes_exactly_the_three_true_ticks(self):
        todo = seed()
        props = comms.match_todo(todo.read_text(), None, live=True)
        ticks = {p["item"]: p for p in props if p["kind"] == "tick"}
        self.assertEqual(set(ticks), {"Accept the Ledgerly invitation", "Send the two playbook drafts",
                                      "Confirm the development agreement on SignWell"})
        self.assertEqual(ticks["Send the two playbook drafts"]["confidence"], "high")
        self.assertIn("rey@example.org", ticks["Send the two playbook drafts"]["evidence"])
        self.assertIn("carl@example.com", ticks["Send the two playbook drafts"]["evidence"])
        self.assertIn("Acme Invest AB", ticks["Accept the Ledgerly invitation"]["evidence"])
        self.assertNotIn("Someone Else", ticks["Accept the Ledgerly invitation"]["evidence"])
        self.assertIn("reminded him 2 times", ticks["Confirm the development agreement on SignWell"]["evidence"])
        self.assertNotIn("Other_NDA", ticks["Confirm the development agreement on SignWell"]["evidence"])

    def test_without_the_live_series_signwell_is_not_guessed(self):
        todo = seed()
        os.environ["COMMS_GMAIL_FIXTURE"] = str(TMP / "absent.json")
        props = comms.match_todo(todo.read_text(), None, live=True)
        self.assertNotIn("Confirm the development agreement on SignWell",
                         {p["item"] for p in props if p["kind"] == "tick"})

    def test_opens_and_waits_carry_their_message(self):
        todo = seed()
        props = comms.match_todo(todo.read_text(), None, live=False)
        opens = [p for p in props if p["kind"] == "open"]
        waits = [p for p in props if p["kind"] == "wait"]
        self.assertEqual([p["refs"] for p in opens], [["q1"]])
        self.assertEqual([p["refs"] for p in waits], [["w1"]])

    def test_apply_writes_only_his_yes_and_never_his_lines(self):
        todo = seed()
        before = todo.read_text()
        props = comms.match_todo(before, None, live=True)
        pick = next(p for p in props if p["item"] == "Send the two playbook drafts")
        done = comms.apply([pick["id"]], todo, live=True)
        self.assertEqual([d["id"] for d in done], [pick["id"]])
        after = todo.read_text()
        self.assertTrue(after.startswith(before.rstrip("\n")), "his half is untouched; the house half is appended")
        self.assertIn(comms.HOUSE_MARK, after)
        self.assertIn(f"(item {pick['id']})", after)
        self.assertIn("- [ ] **Send the two playbook drafts**", after, "his own box stays as he left it")
        again = comms.match_todo(after, None, live=True)
        self.assertNotIn(pick["id"], {p["id"] for p in again}, "never proposed twice")
        # an id that is not proposed now is not written
        self.assertEqual(comms.apply(["deadbeef"], todo, live=True), [])
        # a second approval is appended under its own section, the first line kept
        nxt = next(p for p in again if p["kind"] == "wait")
        comms.apply([nxt["id"]], todo, live=True)
        final = todo.read_text()
        self.assertIn(f"(item {pick['id']})", final)
        wait_at = final.index("## Waiting on others")
        self.assertGreater(final.index(f"(item {nxt['id']})"), wait_at)


class OwedConversations(unittest.TestCase):
    """2026-11-12, his word: the to-do must know what mail he owes, and stop owing it once answered."""

    def seed_conv(self, mails, drafts=None, keep=None):
        todo = seed()
        if keep is not None:
            todo.write_text(keep)
        (TMP / "hodd/memory/mail/messages.jsonl").write_text("".join(json.dumps(m) + "\n" for m in mails))
        live = dict(LIVE)
        if drafts is not None:
            live["in:drafts"] = drafts
        fx = TMP / "live-conv.json"
        fx.write_text(json.dumps(live))
        os.environ["COMMS_GMAIL_FIXTURE"] = str(fx)
        return todo

    REY = {"name": "Rey Asker", "email": "rey@example.org"}

    def ask(self, mid, at, subject, action="create_card", thread="t-plan"):
        return mail(mid, "in", at, subject, self.REY, ME, "Could you look?", "request", action, thread)

    def test_one_line_per_conversation_and_calendar_mail_is_not_owed(self):
        todo = self.seed_conv([
            self.ask("a1", "2026-11-10T09:00:00+00:00", "The plan"),
            self.ask("a2", "2026-11-11T09:00:00+00:00", "Re: The plan"),
            mail("c1", "in", "2026-11-11T10:00:00+00:00", "Invitation: Friday synch @ Fri", self.REY, ME,
                 "", "meeting", "archive", "t-cal"),
        ], drafts=[])
        opens = [p for p in comms.match_todo(todo.read_text(), None, days=14, live=True) if p["kind"] == "open"]
        self.assertEqual([p["thread"] for p in opens], ["t-plan"], "one line for the thread, none for the invitation")
        self.assertEqual(opens[0]["refs"], ["a2"], "the line points at their last word")

    def test_a_reply_closes_the_line_the_house_wrote(self):
        mails = [self.ask("a1", "2026-11-11T09:00:00+00:00", "The plan")]
        todo = self.seed_conv(mails, drafts=[])
        pid = next(p["id"] for p in comms.match_todo(todo.read_text(), None, days=14, live=True) if p["kind"] == "open")
        comms.apply([pid], todo, live=True)
        self.assertIn(f"(item {pid} · thread t-plan)", todo.read_text())
        # a draft is not an answer
        mails.append(dict(mail("d1", "out", "2026-11-11T10:00:00+00:00", "Re: The plan", ME, self.REY, thread="t-plan"),
                          labels=["DRAFT"]))
        (TMP / "hodd/memory/mail/messages.jsonl").write_text("".join(json.dumps(m) + "\n" for m in mails))
        self.assertFalse([p for p in comms.match_todo(todo.read_text(), None, days=14, live=True) if p["kind"] == "close"])
        # the sent reply is
        mails.append(mail("s1", "out", "2026-11-11T11:00:00+00:00", "Re: The plan", ME, self.REY, thread="t-plan"))
        (TMP / "hodd/memory/mail/messages.jsonl").write_text("".join(json.dumps(m) + "\n" for m in mails))
        props = comms.match_todo(todo.read_text(), None, days=14, live=True)
        close = next(p for p in props if p["kind"] == "close")
        self.assertEqual(close["refs"], ["s1"])
        self.assertNotIn("open", {p["kind"] for p in props if p.get("thread") == "t-plan"})
        before = todo.read_text()
        comms.apply([close["id"]], todo, live=True)
        after = todo.read_text()
        self.assertEqual(after.count(f"(item {pid}"), 1, "the line is ticked in place, not written twice")
        self.assertIn("- [x] ", after[after.index(comms.HOUSE_MARK):])
        self.assertEqual(before[:before.index(comms.HOUSE_MARK)], after[:after.index(comms.HOUSE_MARK)],
                         "his half is never touched")

    def test_a_draft_is_one_line_and_its_conversation_is_not_doubled(self):
        todo = self.seed_conv([self.ask("a1", "2026-11-11T09:00:00+00:00", "The plan")],
                              drafts=[{"id": "r123", "subject": "Re: The plan", "date": "Wed, 11 Nov 2026"}])
        props = comms.match_todo(todo.read_text(), None, days=14, live=True)
        self.assertEqual([p["kind"] for p in props if p["kind"] in ("open", "send")], ["send"])
        send = next(p for p in props if p["kind"] == "send")
        comms.apply([send["id"]], todo, live=True)
        self.assertIn("· draft r123)", todo.read_text())
        # the draft leaves the folder: the line is proposed closed — but never when the folder could not be read
        kept = todo.read_text()
        self.seed_conv([self.ask("a1", "2026-11-11T09:00:00+00:00", "The plan")], drafts=None, keep=kept)
        self.assertFalse([p for p in comms.match_todo(todo.read_text(), None, days=14, live=True) if p["kind"] == "close"])
        self.seed_conv([self.ask("a1", "2026-11-11T09:00:00+00:00", "The plan")], drafts=[], keep=kept)
        closes = [p for p in comms.match_todo(todo.read_text(), None, days=14, live=True) if p["kind"] == "close"]
        self.assertEqual([c["closes"] for c in closes], [send["id"]])

    def test_a_password_reset_is_not_waiting_on_anyone(self):
        todo = self.seed_conv([
            mail("x1", "out", "2026-11-10T09:00:00+00:00", "Reset your ExampleProject password", ME,
                 {"name": "Sam", "email": "sam@example.net"}, "Click here. Questions?"),
            mail("x2", "out", "2026-11-10T09:00:00+00:00", "Do you want in?", ME,
                 {"name": "T", "email": "probe.test@example.net"}, "Do you want in?"),
        ], drafts=[])
        self.assertFalse([p for p in comms.match_todo(todo.read_text(), None, days=14, live=True) if p["kind"] == "wait"])


class TheBrief(unittest.TestCase):
    def test_brief_names_each_channel_and_what_waits(self):
        seed()
        (TMP / "hodd/memory/comms").mkdir(parents=True, exist_ok=True)
        (TMP / "hodd/memory/comms/telegram.jsonl").write_text("")
        comms.append("telegram", "in", "operator", text="hi", at="2026-11-11T20:00:00+00:00")
        comms.append("telegram", "out", "operator", text="hello", at="2026-11-11T20:00:05+00:00")
        os.environ["COMMS_OFFLINE"] = "1"
        try:
            text = comms.brief(48)
        finally:
            os.environ["COMMS_OFFLINE"] = "0"
        self.assertIn("**Telegram**: 1 in · 1 out", text)
        self.assertIn("**Mail**:", text)
        self.assertIn("Still to send", text)
        self.assertIn("What moved on his list", text)


class FakeTelegram(BaseHTTPRequestHandler):
    sent: list = []
    updates: list = []

    def log_message(self, *a):
        pass

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        form = {k: v[0] for k, v in parse_qs(self.rfile.read(n).decode()).items()}
        method = self.path.rsplit("/", 1)[-1]
        if method == "getUpdates":
            res, FakeTelegram.updates = FakeTelegram.updates, []
            body = {"ok": True, "result": res}
        else:
            if method == "sendMessage":
                FakeTelegram.sent.append(form)
            body = {"ok": True, "result": {}}
        out = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)


class TelegramBothWays(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv = ThreadingHTTPServer(("127.0.0.1", 0), FakeTelegram)
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()
        cls.base = f"http://127.0.0.1:{cls.srv.server_address[1]}"

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()

    def setUp(self):
        seed()
        FakeTelegram.sent.clear()
        p = TMP / "hodd/memory/comms/telegram.jsonl"
        if p.exists():
            p.unlink()

    def test_the_bot_records_what_it_hears_and_what_it_says(self):
        FakeTelegram.updates = [{"update_id": 5, "message": {
            "message_id": 77, "text": "what is on today?", "chat": {"id": 1, "type": "private"},
            "from": {"id": 1, "username": "operator", "is_bot": False}}}]
        stub = TMP / "answer_stub.py"
        stub.write_text(
            "import os, sys\n"
            f"sys.path.insert(0, {str(ROOT / 'systems/skirnir/services')!r})\n"
            "import telegram\n"
            "telegram.answer = lambda *a, **k: 'Two meetings and one letter.'\n"
            "telegram.allowed = lambda chat: (True, '')\n"
            "sys.argv = ['telegram.py', '--once']\n"
            "sys.exit(telegram.main())\n")
        env = {**os.environ, "SKIRNIR_TELEGRAM_BOT_TOKEN": "fixture", "TELEGRAM_OWNER_ID": "1",
               "TELEGRAM_API_BASE": self.base}
        run = subprocess.run([sys.executable, str(stub)], env=env, capture_output=True, text=True, timeout=60)
        self.assertEqual(run.returncode, 0, run.stderr[-400:])
        rows = comms.channel_rows("telegram")
        self.assertEqual([(r["direction"], r["who"], r["ref"]) for r in rows],
                         [("in", "operator", "77"), ("out", "operator", "77")])
        self.assertEqual(rows[1]["text"], "Two meetings and one letter.")
        self.assertEqual(FakeTelegram.sent[-1]["text"], "Two meetings and one letter.")

    def test_the_hotline_records_what_it_sends(self):
        env = {**os.environ, "TELEGRAM_BOT_TOKEN": "fixture", "TELEGRAM_OWNER_ID": "1",
               "TELEGRAM_API_BASE": self.base, "PATH": os.environ["PATH"]}
        run = subprocess.run(["bash", str(ROOT / "bin/notify/send.sh"), "--source", "errand",
                              "--severity", "INFO", "--ask", "--no-telegram", "--message", "x"],
                             env=env, capture_output=True, text=True, timeout=60)
        self.assertEqual(comms.channel_rows("telegram"), [], "no Telegram leg, no Telegram row")
        run = subprocess.run(["bash", str(ROOT / "bin/notify/send.sh"), "--source", "errand",
                              "--severity", "INFO", "--ask", "--key", "plan-261-proof",
                              "--message", "plan 261: the hotline is recorded"],
                             env=env, capture_output=True, text=True, timeout=60)
        self.assertIn('"1"\n', run.stdout + "\n", run.stdout + run.stderr)
        rows = comms.channel_rows("telegram")
        self.assertEqual(len(rows), 1, run.stdout + run.stderr)
        self.assertEqual((rows[0]["direction"], rows[0]["project"]), ("out", "errand"))
        self.assertIn("plan 261: the hotline is recorded", rows[0]["text"])


if __name__ == "__main__":
    unittest.main()
