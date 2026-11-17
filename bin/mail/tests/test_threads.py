#!/usr/bin/env python3
"""The proofs plan 305 phase 1 asks for: three fixtures — answered, unanswered, waiting.

Each fixture is a tiny mail store written to a temporary directory; the door is run
against it with a pinned `--now`, so a lane that depends on age cannot drift with the
clock. The last test is the law the reader owes the record: it reads, and never writes.

The evidence proofs are here too (2026-11-17, the audit of the 49): a conversation also
closes by a document, a meeting or a filing, and a fifth kind — `answered-elsewhere` —
which is MARKED and never counted as a reply. A row that matches only a sender, and above
all only a DOMAIN, must close nothing: that is the mistake that hid an unsigned
development agreement behind a signed NDA.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
THREADS = HERE.parent / "threads.sh"
NOW = "2026-11-16T12:00:00Z"

# An empty evidence file, so no proof ever reads the operator's own home by accident.
EMPTY_EVIDENCE = Path(tempfile.mkdtemp(prefix="threads-evidence-")) / "empty.yaml"
EMPTY_EVIDENCE.write_text("version: 1\nclosed: []\n", encoding="utf-8")


def message(thread_key, direction, at, *, mid=None, subject="", labels=None,
            classification="other", proposed_action="", auto_submitted="",
            account="operator@example.com", sender="Ada Example <ada@example.org>",
            handled_at=""):
    """One store row, with only the fields the door reads.

    `sender` is the other party, whichever way the message went: the address it came from
    on an inbound row, the address it went to on an outbound one. Distinct people per
    fixture keep one fixture's letter from answering another fixture's thread.
    """
    name, _, address = sender.partition("<")
    sender_email = (address.strip(">") or sender).strip()
    sender_name = name.strip()
    row = {
        "id": mid or "%s-%s" % (thread_key, direction + at),
        "account": account,
        "direction": direction,
        "thread_key": thread_key,
        "received_at": at,
        "subject": subject,
        "labels": labels if labels is not None else (["INBOX"] if direction == "in" else ["SENT"]),
        "classification": classification,
        "proposed_action": proposed_action,
        "auto_submitted": auto_submitted,
        "handled_at": handled_at,
        "from": {"name": "", "email": "someone@example.org"},
        "to": [{"name": "", "email": account}],
    }
    if direction == "in":
        row["from"] = {"name": sender_name, "email": sender_email}
        row["to"] = [{"name": "", "email": account}]
    else:
        row["from"] = {"name": "", "email": account}
        row["to"] = [{"name": sender_name, "email": sender_email}]
    return row


# FIXTURE 1 — ANSWERED. We wrote last, two days ago: quieter than the three-day nudge.
ANSWERED = [
    message("t-answered", "in", "2026-11-10T09:00:00+00:00", subject="Spec v2.5",
            sender="Bo Example <bo@example.org>",
            classification="question", proposed_action="reply_needed"),
    message("t-answered", "out", "2026-11-14T10:00:00+00:00", mid="out-answered",
            sender="Bo Example <bo@example.org>"),
]

# FIXTURE 2 — UNANSWERED. They wrote last and it owes a reply: the only lane that speaks.
UNANSWERED = [
    message("t-unanswered", "in", "2026-11-09T08:00:00+00:00", subject="Two questions",
            labels=["INBOX", "UNREAD"], classification="question",
            proposed_action="reply_needed"),
]

# FIXTURE 3 — WAITING ON THEM. We answered, then nothing for six days: the nudge lane.
WAITING = [
    message("t-waiting", "in", "2026-11-01T09:00:00+00:00", subject="The invoice",
            sender="Cy Example <cy@example.org>",
            classification="request", proposed_action="reply_needed"),
    message("t-waiting", "out", "2026-11-10T09:00:00+00:00", mid="out-waiting",
            sender="Cy Example <cy@example.org>"),
]

# Not a lane fixture, a guard: a notice nobody must answer is closed, not owed.
NOTICE = [
    message("t-notice", "in", "2026-11-02T09:00:00+00:00", subject="Your flight is booked",
            labels=["INBOX", "UNREAD"], sender="Dee Example <dee@example.org>",
            classification="notice", proposed_action="archive"),
]


def write_store(directory, rows):
    path = Path(directory) / "messages.jsonl"
    with open(path, "w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row) + "\n")
    return path


def write_evidence(directory, rows, name="evidence.yaml"):
    """An evidence file in the shape the home's own file is written in."""
    lines = ["version: 1", "closed:"]
    for row in rows:
        lines.append("  - id: %s" % row["id"])
        match = row.get("match") or {}
        parts = []
        for key in ("from", "from_domain", "domain", "subject_any", "thread_keys", "message_ids"):
            if key in match:
                parts.append("%s: [%s]" % (key, ", ".join('"%s"' % value for value in match[key])))
        lines.append("    match: { %s }" % ", ".join(parts))
        for key in ("kind", "evidence", "evidence_message", "closed_on", "note"):
            if key in row:
                lines.append('    %s: "%s"' % (key, row[key]))
    path = Path(directory) / name
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def run(store, *args):
    """The door, with an evidence file pinned so no proof reads the operator's home."""
    extra = [] if "--evidence" in args else ["--evidence", str(EMPTY_EVIDENCE)]
    return subprocess.run(
        ["bash", str(THREADS), "--store", str(store), "--now", NOW, *args, *extra],
        capture_output=True, text=True, check=False,
    )


def run_in_home(home, store):
    """The door with a home of its own: the evidence file is then the home's own file."""
    env = {key: value for key, value in os.environ.items() if key != "YMIR_MAIL_EVIDENCE"}
    env["YMIR_HOME"] = str(home)
    env["YMIR_HOARD"] = str(Path(home) / "hodd")
    return subprocess.run(
        ["bash", str(THREADS), "--store", str(store), "--now", NOW],
        capture_output=True, text=True, check=False, env=env,
    )


def rows_by_key(store, *args):
    done = run(store, "--json", *args)
    assert done.returncode == 0, done.stderr
    return {t["thread_key"]: t for t in json.loads(done.stdout)["threads"]}


class ThreadsDoor(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="threads-test-")
        self.dir = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_fixture_answered(self):
        """We wrote last and it is recent: `answered`, and not listed at him."""
        store = write_store(self.dir, ANSWERED)
        done = run(store)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn('"answered"', done.stdout)
        thread = rows_by_key(store)["t-answered"]
        self.assertEqual(thread["lane"], "answered")
        self.assertEqual(thread["last_direction"], "out")
        self.assertTrue(thread["answered"])
        self.assertEqual(thread["answered_by"], "out-answered")
        self.assertIsNone(thread["unanswered_days"])
        self.assertEqual(thread["age_days"], 2)

    def test_fixture_unanswered(self):
        """They wrote last and it owes an answer: `needs-you`, with the age of the debt."""
        store = write_store(self.dir, UNANSWERED)
        thread = rows_by_key(store)["t-unanswered"]
        self.assertEqual(thread["lane"], "needs-you")
        self.assertEqual(thread["last_direction"], "in")
        self.assertFalse(thread["answered"])
        self.assertEqual(thread["unanswered_days"], 7)
        self.assertTrue(thread["unread"])
        self.assertEqual(thread["correspondent"], "Ada Example")

    def test_fixture_waiting(self):
        """We wrote last and it has gone quiet: `waiting-on-them` — where a nudge comes from."""
        store = write_store(self.dir, WAITING)
        thread = rows_by_key(store)["t-waiting"]
        self.assertEqual(thread["lane"], "waiting-on-them")
        self.assertEqual(thread["age_days"], 6)
        self.assertIsNone(thread["unanswered_days"])

    def test_the_four_lanes_all_appear_and_sum_to_the_threads(self):
        """One row per thread, exactly one lane each, and the counts agree with the rows."""
        store = write_store(self.dir, ANSWERED + UNANSWERED + WAITING + NOTICE)
        done = run(store)
        self.assertEqual(done.returncode, 0, done.stderr)
        lines = [l for l in done.stdout.splitlines() if l.startswith('  "t-')]
        self.assertEqual(len(lines), 4, done.stdout)
        lanes = sorted(l.rsplit('"', 2)[-2] for l in lines)
        self.assertEqual(lanes, ["answered", "closed", "needs-you", "waiting-on-them"])
        payload = json.loads(run(store, "--json").stdout)
        self.assertEqual(sum(payload["counts"].values()), 4)
        self.assertEqual(payload["totals"]["threads"], 4)
        self.assertEqual(payload["totals"]["messages"], 6)

    def test_a_notice_owes_nothing_and_is_closed(self):
        """The plan's rule: no notice ever appears in needs-you."""
        store = write_store(self.dir, NOTICE)
        thread = rows_by_key(store)["t-notice"]
        self.assertEqual(thread["lane"], "closed")
        self.assertEqual(thread["lane_reason"], "nothing-owed")
        self.assertIsNone(thread["unanswered_days"])
        self.assertEqual(rows_by_key(store, "--lane", "needs-you"), {})

    def test_handled_at_closes_a_thread(self):
        """His tick is evidence: a handled message closes its conversation."""
        rows = [message("t-handled", "in", "2026-11-09T08:00:00+00:00",
                        classification="question", proposed_action="reply_needed",
                        handled_at="2026-11-10T08:00:00+00:00")]
        store = write_store(self.dir, rows)
        thread = rows_by_key(store)["t-handled"]
        self.assertEqual(thread["lane"], "closed")
        self.assertEqual(thread["lane_reason"], "handled")

    def test_the_lane_filter_and_its_aliases(self):
        """`--lane` takes the plan's own words, and a filtered block shows no fake zeros."""
        store = write_store(self.dir, ANSWERED + UNANSWERED + WAITING + NOTICE)
        for given in ("needs-you", "needs you", "needs_you"):
            done = run(store, "--lane", given)
            self.assertEqual(done.returncode, 0, done.stderr)
            self.assertIn("threads.sh[1]{", done.stdout)
            self.assertIn("lanes[1]{lane,threads}:", done.stdout)
            self.assertNotIn('"answered",', done.stdout)
        done = run(store, "--lane", "nonsense")
        self.assertEqual(done.returncode, 2)

    def test_the_nudge_day_is_a_flag_not_a_constant(self):
        """Age decides answered vs waiting-on-them, and the boundary is the caller's."""
        store = write_store(self.dir, ANSWERED)
        self.assertEqual(rows_by_key(store, "--nudge-days", "1")["t-answered"]["lane"],
                         "waiting-on-them")
        self.assertEqual(rows_by_key(store, "--nudge-days", "3")["t-answered"]["lane"], "answered")

    def test_a_future_stamp_is_never_a_negative_age(self):
        """A clock that disagrees with the store reports 0 days owed, never a negative one."""
        rows = [message("t-future", "in", "2026-12-01T08:00:00+00:00",
                        classification="question", proposed_action="reply_needed")]
        store = write_store(self.dir, rows)
        self.assertEqual(rows_by_key(store)["t-future"]["unanswered_days"], 0)

    def test_an_unreadable_row_is_a_finding_not_a_blank(self):
        """A broken line is counted and named, and the threads that do parse still print."""
        store = write_store(self.dir, UNANSWERED)
        with open(store, "a", encoding="utf-8") as handle:
            handle.write("{not json\n")
        done = run(store, "--json")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(json.loads(done.stdout)["totals"]["unreadable_rows"], 1)
        self.assertIn("unreadable row", done.stderr)

    def test_it_reads_the_store_and_never_writes_it(self):
        """The reader's law: the store is byte-identical before and after, mtime included."""
        store = write_store(self.dir, ANSWERED + UNANSWERED + WAITING + NOTICE)
        digest = hashlib.sha256(store.read_bytes()).hexdigest()
        stamp = store.stat().st_mtime_ns
        before = sorted(p.name for p in Path(self.dir).iterdir())
        for args in ([], ["--json"], ["--lane", "closed"], ["--nudge-days", "0"]):
            self.assertEqual(run(store, *args).returncode, 0)
        self.assertEqual(hashlib.sha256(store.read_bytes()).hexdigest(), digest)
        self.assertEqual(store.stat().st_mtime_ns, stamp)
        self.assertEqual(sorted(p.name for p in Path(self.dir).iterdir()), before)

    def test_a_missing_store_is_an_error_not_an_empty_answer(self):
        """No store must not read as 'no mail': silence and an empty well look the same."""
        done = subprocess.run(
            ["bash", str(THREADS), "--store", str(Path(self.dir) / "absent.jsonl")],
            capture_output=True, text=True, check=False)
        self.assertEqual(done.returncode, 1)
        self.assertIn("no mail store", done.stderr)
        self.assertEqual(done.stdout, "")

    def test_an_empty_store_prints_an_empty_board(self):
        """No messages is a real answer: zero threads, four lanes at zero, exit 0."""
        store = write_store(self.dir, [])
        done = run(store)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("threads.sh[0]{", done.stdout)
        self.assertIn('"needs-you",0', done.stdout)


# ── the evidence proofs (2026-11-17, the audit of the 49) ────────────
# A conversation closes by a document, a meeting or a filing — each declared with a path, a
# message id or a meeting record — and by a fifth kind, `answered-elsewhere`, which is
# marked and never counted as a reply. A row matching only a sender, and above all only a
# DOMAIN, closes nothing: a rule matching "signwell" alone folded the UNSIGNED development
# agreement into the signed NDA and hid it.

NDA_DOCUMENT = {
    "id": "coherans-nda-signed",
    "match": {"from": ["partner@inmost.example.net", "docs@signwell.example.net"],
              "subject_any": ["nda", "coherans", "annex"]},
    "kind": "document",
    "evidence": "svartalfaheim/example/NDA/Mutual_NDA_v1.pdf",
    "evidence_message": "fixture-nda-message",
    "closed_on": "2026-10-16",
}

NDA_MEETING = {
    "id": "coherans-signing-meeting",
    "match": {"from": ["partner@inmost.example.net"],
              "subject_any": ["nda sign", "nda review"]},
    "kind": "meeting",
    "evidence": "mail 2026-10-15 'Your meeting recap - NDA signing' (the recorder's own summary)",
    "evidence_message": "fixture-recap-message",
    "closed_on": "2026-10-15",
}

FILING = {
    "id": "service-notices",
    "match": {"from": ["team@hostinger.example.net"]},
    "kind": "filing",
    "evidence": "hodd/memory/mail/audit-of-the-49-2026-11-17.md — classified notice/service; nothing asked",
    "closed_on": "2026-11-17",
}

SIGNED_THREAD = message("t-nda", "in", "2026-10-14T10:00:00+00:00",
                        subject="Document completed (Mutual_NDA_v1.7)",
                        sender="SignWell Docs <docs@signwell.example.net>",
                        classification="request", proposed_action="reply_needed")

# The contract that one "signwell" rule swallowed: a DIFFERENT agreement, never completed,
# chased four times. It is dated before the NDA's closed_on so that only the SUBJECT can
# keep it open — the date alone must not be what saves it.
DEVELOPMENT_THREAD = message("t-dev", "in", "2026-10-15T09:00:00+00:00",
                             subject="Please complete Development_Agreement",
                             sender="SignWell Docs <docs@signwell.example.net>",
                             classification="request", proposed_action="reply_needed")


class EvidenceClosures(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="threads-evidence-")
        self.dir = self.tmp.name

    def tearDown(self):
        self.tmp.cleanup()

    def test_a_document_row_closes_without_a_letter(self):
        """The NDA case: the signature was the answer, and the row NAMES the paper."""
        store = write_store(self.dir, [SIGNED_THREAD])
        evidence = write_evidence(self.dir, [NDA_DOCUMENT])
        thread = rows_by_key(store, "--evidence", str(evidence))["t-nda"]
        self.assertEqual(thread["lane"], "closed")
        self.assertEqual(thread["lane_reason"], "document")
        self.assertFalse(thread["answered"])          # no letter was ever sent
        self.assertIsNone(thread["unanswered_days"])
        self.assertEqual(thread["evidence_kind"], "document")
        self.assertEqual(thread["evidence_ref"], "svartalfaheim/example/NDA/Mutual_NDA_v1.pdf")
        self.assertEqual(thread["evidence_id"], "fixture-nda-message")
        self.assertEqual(thread["evidence_row"], "coherans-nda-signed")
        self.assertEqual(thread["evidence_on"], "2026-10-16")
        done = run(store, "--evidence", str(evidence))
        self.assertIn('"document:svartalfaheim/example/NDA/Mutual_NDA_v1.pdf","fixture-nda-message","closed"',
                      done.stdout)
        self.assertIn("1 closed by evidence", done.stdout)

    def test_a_meeting_row_closes(self):
        """A meeting that happened is the record of it; the row names the note."""
        rows = [message("t-sign", "in", "2026-10-15T08:00:00+00:00",
                        subject="NDA signing - Wednesday",
                        sender="Ina Partner <partner@inmost.example.net>",
                        classification="request", proposed_action="reply_needed")]
        store = write_store(self.dir, rows)
        evidence = write_evidence(self.dir, [NDA_MEETING])
        thread = rows_by_key(store, "--evidence", str(evidence))["t-sign"]
        self.assertEqual(thread["lane"], "closed")
        self.assertEqual(thread["lane_reason"], "meeting")
        self.assertEqual(thread["evidence_kind"], "meeting")
        self.assertEqual(thread["evidence_id"], "fixture-recap-message")

    def test_a_filing_row_closes(self):
        """A notice that needed nothing but reading is closed by filing, not by a reply."""
        rows = [message("t-service", "in", "2026-11-10T08:00:00+00:00",
                        subject="Your Hostinger account",
                        sender="Hostinger <team@hostinger.example.net>",
                        classification="request", proposed_action="reply_needed")]
        store = write_store(self.dir, rows)
        evidence = write_evidence(self.dir, [FILING])
        thread = rows_by_key(store, "--evidence", str(evidence))["t-service"]
        self.assertEqual(thread["lane"], "closed")
        self.assertEqual(thread["lane_reason"], "filing")
        self.assertFalse(thread["answered"])
        self.assertEqual(thread["evidence_row"], "service-notices")

    def test_a_window_closure_is_marked_answered_elsewhere_and_never_a_reply(self):
        """The fifth kind: we wrote to that person about something else. Marked, not a reply."""
        rows = [
            message("t-iso", "in", "2026-11-10T09:00:00+00:00", subject="One question",
                    sender="Ina Partner <partner@inmost.example.net>",
                    classification="question", proposed_action="reply_needed"),
            message("t-other", "in", "2026-11-11T09:00:00+00:00", subject="Another matter",
                    sender="Ina Partner <partner@inmost.example.net>",
                    classification="request", proposed_action="reply_needed"),
            message("t-other", "out", "2026-11-12T09:00:00+00:00", mid="out-elsewhere",
                    sender="Ina Partner <partner@inmost.example.net>"),
        ]
        store = write_store(self.dir, rows)
        thread = rows_by_key(store)["t-iso"]
        self.assertEqual(thread["lane"], "closed")
        self.assertEqual(thread["lane_reason"], "answered-elsewhere")
        self.assertTrue(thread["answered_elsewhere"])
        self.assertFalse(thread["answered"])          # the whole point: it is NOT a reply
        self.assertIsNone(thread["unanswered_days"])
        self.assertEqual(thread["evidence_kind"], "answered-elsewhere")
        self.assertEqual(thread["evidence_id"], "out-elsewhere")
        self.assertEqual(thread["evidence_to"], "partner@inmost.example.net")
        payload = json.loads(run(store, "--json").stdout)
        self.assertEqual(payload["totals"]["closed_answered_elsewhere"], 1)
        self.assertEqual(payload["totals"]["answered_threads"], 1)   # t-other only
        self.assertEqual(payload["totals"]["window_days"], 14)
        self.assertIn('"answered-elsewhere:out-elsewhere"', run(store).stdout)
        self.assertIn("1 answered elsewhere", run(store).stdout)

    def test_the_window_is_the_callers_and_the_default_is_fourteen_days(self):
        """Two days is inside fourteen and outside one; the boundary is a flag."""
        rows = [
            message("t-iso", "in", "2026-11-10T09:00:00+00:00", subject="One question",
                    sender="Ina Partner <partner@inmost.example.net>",
                    classification="question", proposed_action="reply_needed"),
            message("t-other", "out", "2026-11-12T09:00:00+00:00", mid="out-elsewhere",
                    sender="Ina Partner <partner@inmost.example.net>"),
        ]
        store = write_store(self.dir, rows)
        self.assertEqual(rows_by_key(store)["t-iso"]["lane_reason"], "answered-elsewhere")
        self.assertEqual(rows_by_key(store, "--window", "1")["t-iso"]["lane"], "needs-you")
        self.assertEqual(rows_by_key(store, "--window", "2")["t-iso"]["lane_reason"],
                         "answered-elsewhere")
        self.assertEqual(run(store, "--window", "many").returncode, 1)
        self.assertIn("--window wants a whole number of days",
                      run(store, "--window", "many").stderr)

    def test_a_sender_domain_alone_must_not_close(self):
        """A domain is not evidence. A sender is not evidence. Only the subject protects it."""
        store = write_store(self.dir, [SIGNED_THREAD, DEVELOPMENT_THREAD])
        domain_rows = [
            {"id": "by-domain", "match": {"from_domain": ["signwell.example.net"]},
             "kind": "document",
             "evidence": "svartalfaheim/example/NDA/Mutual_NDA_v1.pdf"},
            {"id": "by-bare-domain", "match": {"from": ["signwell.example.net"]},
             "kind": "document",
             "evidence": "svartalfaheim/example/NDA/Mutual_NDA_v1.pdf"},
            {"id": "by-sender-alone", "match": {"from": ["docs@signwell.example.net"]},
             "kind": "document",
             "evidence": "svartalfaheim/example/NDA/Mutual_NDA_v1.pdf"},
        ]
        evidence = write_evidence(self.dir, domain_rows)
        threads = rows_by_key(store, "--evidence", str(evidence))
        self.assertEqual(threads["t-nda"]["lane"], "needs-you")     # nothing closed
        self.assertEqual(threads["t-dev"]["lane"], "needs-you")
        payload = json.loads(run(store, "--json", "--evidence", str(evidence)).stdout)
        self.assertEqual(payload["totals"]["evidence_rows"], 0)
        self.assertEqual(payload["totals"]["evidence_refused"], 3)
        refused = [item["why"] for item in payload["evidence"]["refused"]]
        self.assertTrue(any("DOMAIN" in why for why in refused), refused)
        self.assertTrue(any("narrows to the sender alone" in why for why in refused), refused)
        done = run(store, "--evidence", str(evidence))
        self.assertIn("not applied", done.stderr)

        # …and the SPECIFIC row closes the NDA and leaves the development agreement open.
        specific = write_evidence(self.dir, [NDA_DOCUMENT], name="specific.yaml")
        threads = rows_by_key(store, "--evidence", str(specific))
        self.assertEqual(threads["t-nda"]["lane_reason"], "document")
        self.assertEqual(threads["t-dev"]["lane"], "needs-you")

    def test_a_reply_is_computed_not_declared(self):
        """A hand-written `kind: reply` is refused: the letters are the authority on replies."""
        rows = [message("t-nda", "in", "2026-10-14T10:00:00+00:00",
                        subject="Document completed (Mutual_NDA_v1.7)",
                        sender="SignWell Docs <docs@signwell.example.net>",
                        classification="request", proposed_action="reply_needed")]
        store = write_store(self.dir, rows)
        evidence = write_evidence(self.dir, [{
            "id": "claimed-reply",
            "match": {"from": ["docs@signwell.example.net"], "subject_any": ["nda"]},
            "kind": "reply",
            "evidence": "fixture-nda-message",
        }])
        payload = json.loads(run(store, "--json", "--evidence", str(evidence)).stdout)
        self.assertEqual(payload["totals"]["evidence_refused"], 1)
        self.assertEqual(payload["threads"][0]["lane"], "needs-you")
        self.assertIn("computed from the store", payload["evidence"]["refused"][0]["why"])

    def test_the_home_evidence_file_is_read_without_a_flag(self):
        """`hodd/memory/mail/evidence.yaml` is read when it is there — that is the default."""
        home = Path(self.dir) / "home"
        (home / "hodd" / "memory" / "mail").mkdir(parents=True)
        evidence = write_evidence(home / "hodd" / "memory" / "mail", [NDA_DOCUMENT])
        store = write_store(self.dir, [SIGNED_THREAD])
        done = run_in_home(home, store)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("1 row(s) applied from %s" % evidence, done.stdout)
        payload = json.loads(subprocess.run(
            ["bash", str(THREADS), "--store", str(store), "--now", NOW, "--json"],
            capture_output=True, text=True, check=False,
            env={**{k: v for k, v in os.environ.items() if k != "YMIR_MAIL_EVIDENCE"},
                 "YMIR_HOME": str(home), "YMIR_HOARD": str(home / "hodd")}).stdout)
        self.assertEqual(payload["threads"][0]["lane_reason"], "document")

    def test_no_evidence_file_closes_nothing_and_says_so(self):
        """Absence is said out loud: no file means a reply is the only closure this run sees."""
        home = Path(self.dir) / "home"
        (home / "hodd" / "memory" / "mail").mkdir(parents=True)
        store = write_store(self.dir, [SIGNED_THREAD])
        done = run_in_home(home, store)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("evidence: none", done.stdout)
        self.assertIn("\"needs-you\"", done.stdout)

    def test_a_named_evidence_file_that_is_absent_is_an_error(self):
        """A typo in --evidence must not read as 'no evidence': that is a silent false green."""
        store = write_store(self.dir, [SIGNED_THREAD])
        done = run(store, "--evidence", str(Path(self.dir) / "absent.yaml"))
        self.assertEqual(done.returncode, 1)
        self.assertIn("no evidence file", done.stderr)
        self.assertEqual(done.stdout, "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
