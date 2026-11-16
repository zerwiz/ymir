#!/usr/bin/env python3
"""The proofs plan 305 phase 1 asks for: three fixtures — answered, unanswered, waiting.

Each fixture is a tiny mail store written to a temporary directory; the door is run
against it with a pinned `--now`, so a lane that depends on age cannot drift with the
clock. The last test is the law the reader owes the record: it reads, and never writes.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
THREADS = HERE.parent / "threads.sh"
NOW = "2026-11-16T12:00:00Z"


def message(thread_key, direction, at, *, mid=None, subject="", labels=None,
            classification="other", proposed_action="", auto_submitted="",
            account="operator@example.com", sender="Ada Example <ada@example.org>",
            handled_at=""):
    """One store row, with only the fields the door reads."""
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
        row["from"] = {"name": "Ada Example", "email": "ada@example.org"}
        row["to"] = [{"name": "", "email": account}]
    else:
        row["from"] = {"name": "", "email": account}
        row["to"] = [{"name": "Ada Example", "email": sender.split("<")[-1].strip(">") if "<" in sender else sender}]
    return row


# FIXTURE 1 — ANSWERED. We wrote last, two days ago: quieter than the three-day nudge.
ANSWERED = [
    message("t-answered", "in", "2026-11-10T09:00:00+00:00", subject="Spec v2.5",
            classification="question", proposed_action="reply_needed"),
    message("t-answered", "out", "2026-11-14T10:00:00+00:00", mid="out-answered"),
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
            classification="request", proposed_action="reply_needed"),
    message("t-waiting", "out", "2026-11-10T09:00:00+00:00", mid="out-waiting"),
]

# Not a lane fixture, a guard: a notice nobody must answer is closed, not owed.
NOTICE = [
    message("t-notice", "in", "2026-11-02T09:00:00+00:00", subject="Your flight is booked",
            labels=["INBOX", "UNREAD"], classification="notice",
            proposed_action="archive"),
]


def write_store(directory, rows):
    path = Path(directory) / "messages.jsonl"
    with open(path, "w", encoding="utf-8") as handle:
        for row in rows:
            handle.write(json.dumps(row) + "\n")
    return path


def run(store, *args):
    return subprocess.run(
        ["bash", str(THREADS), "--store", str(store), "--now", NOW, *args],
        capture_output=True, text=True, check=False,
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
