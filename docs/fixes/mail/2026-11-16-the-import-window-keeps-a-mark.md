# mail · 2026-11-16 — the import window is a mark, and a gap that speaks

## Files

- `bin/mail/gna_import.py` — the high-water mark, the mark-shaped window, the gap report
- `bin/time/nornir-job-gna-mail.sh` — the clock measures the gap before it reads, names it, records it
- `bin/mail/gna_notify.py` — the next notice opens with *"the desk was blind for N days"*
- `bin/mail/tests/test_gna.py` — a week of downtime against a stub transport, and a fixture repair
- `hodd/state/gna-mail-watermark.json` (the home) — the mark itself, one row per account

## Why

The importer asked the mailbox for **the last N days**, measured from *now*:
`newer_than:2d` on the Gmail path and `SINCE <today minus two days>` on IMAP. Two days is a
width, not a mark, and that is the whole fault: every hour the desk was down is an hour the ask
never covered.

A run after a week of downtime therefore read the last two days, wrote a clean summary, and
said nothing about the five days in between. Mail that had arrived during the outage was not
skipped by a bug an operator could see — it was outside the question, and the run looked exactly
like a quiet inbox. That is the same shape as "absence rendered as an empty list", which this
desk's own law forbids.

## Fix

The importer now keeps a **high-water mark per account**: the newest message it has read, and the
moment it last looked (`hodd/state/gna-mail-watermark.json`). A run asks for everything **since
the mark** — `after:<epoch>` on Gmail, `SINCE <the mark's day>` on IMAP — so a run after downtime
reads the whole gap.

Four properties hold the mark honest:

- **It only moves forward.** Re-reading an overlap (a backfill, or IMAP's day-granularity `SINCE`)
  can never roll the mark back onto mail already behind it.
- **It is asked from one second before the mark**, so a message that arrived in the same second as
  the newest one read is not lost; the store's own de-duplication absorbs that second.
- **The ask is paginated.** Gmail answers newest-first, a hundred at a time. Reading only the first
  page after a long gap would keep the newest hundred and drop the oldest of the outage, so the
  listing follows `nextPageToken`. A window still wider than `--max` is reported as `TRUNCATED`,
  never as a quiet success.
- **`--days` survives as an override** for a deliberate backfill. It is no longer the clock.

**The gap speaks.** Before it reads, the run measures how long the desk was blind — from the last
run that ended well (`rc: 0`; a run that could not read the mailbox is not a look), falling back to
the marks it did not stamp. A silence wider than the run interval (`GNA_RUN_INTERVAL_HOURS`,
default 24) is named in days with both ends:

```
gna-mail[import] GAP the desk was blind for 7 days — from 2026-11-09T18:19:50+00:00 to
2026-11-16T18:19:51+00:00 (the clock runs every 24h) — this run reads the whole gap
```

The same measurement is written into `hodd/state/gna-mail-last-run.json` under `gap`, so the next
notice can open with it — *"the desk was blind for 7 days — mail: 8 new …"* — and say it exactly
once (`gap.spoken_at` marks it said). A notice that buried the outage under the counts would read
as if the desk had been awake the whole time.

The last-run record is now written by the importer (`--record-run`) instead of a bash `printf`, so
one owner holds its shape as it gains the window and the gap.

**A test fixture was broken and is repaired.** `_ImapHandler.write` appended a second CRLF to an
untagged response that already ended in one, so every IMAP proof in `bin/mail/tests/test_gna.py`
failed with `imaplib.IMAP4.abort: command: CAPABILITY => unexpected response: b''` — five failures
on a clean tree before this change. A proof file that cannot run proves nothing, so the fix is part
of this one.

## Verified

```
python3 -m unittest discover -s bin/mail/tests -p "test_*.py"
Ran 49 tests in 14.476s
OK
```

`41` tests before this change (`5` of them failing on a clean tree), `49` after, none failing. The
new `ImportWindow` class drives a **stub transport** (no socket, no grant) through a week of
downtime and proves:

| Proof | What it shows |
|---|---|
| `test_a_run_after_a_week_of_downtime_skips_nothing_in_the_gap` | all six messages that arrived while the desk was blind are in the store, plus the fresh one; the listing took four pages |
| `test_the_ask_is_everything_since_the_mark_never_a_fixed_width` | every query carries `after:` and none carries `newer_than:`; the epoch asked for is one second before the mark; the run printed `since … (mark)` |
| `test_days_is_still_an_override_for_a_backfill` | `--days 30` asks `newer_than:30d`, and the window says `(days)` |
| `test_the_gap_is_named_in_days_with_both_ends` | `gap.days` is 7, `gap.from` is the last look, the line says *the desk was blind for 7 days*, and the last-run record carries it |
| `test_a_normal_interval_is_not_called_blindness` | two hours of silence is not a gap and produces no line |
| `test_a_failed_run_is_not_a_look` | a run with `rc: 2` does not count as a look; the marks decide the gap |
| `test_the_next_notice_opens_with_the_gap_and_says_it_once` | the notice's **first** line opens with the gap, and a second notice does not repeat it |
| `test_the_mark_never_moves_backwards` | re-reading older mail leaves the mark where it was |

The importer's own door still passes: `python3 bin/mail/gna_import.py --self-test` → `9/9 passed`.

The job was run against a seeded home with a seven-day-old last-run record:

```
gna-mail[--dry-run] GAP the desk was blind for 7 days — from 2026-11-09T18:19:50+00:00 to
2026-11-16T18:19:51+00:00 (the clock runs every 24h) — this run reads the whole gap
```

and `hodd/state/gna-mail-last-run.json` then held:

```json
{"at": "2026-11-16T18:19:51+00:00", "window": "mark", "days": null, "rc": 1, "accounts": 1,
 "gap": {"exceeded": true, "days": 7.0, "from": "2026-11-09T18:19:50+00:00",
         "to": "2026-11-16T18:19:51+00:00", "interval_hours": 24.0, "source": "last-run",
         "line": "the desk was blind for 7 days — …"}}
```

`bash -n bin/time/nornir-job-gna-mail.sh` and `bash -n` over the importer's `--self-test` path
pass; `python3 -m compileall` on the changed modules is clean.

## What this does not do

It cannot recover mail that a previous run already skipped — that mail was never asked for and is
not in the store. It makes the *next* outage audible and the next run whole. A deliberate refill of
an old stretch is `--days <n>`, a backfill by the operator's own hand.

## CHANGE LOG

- **2026-11-16** — note written: the mark replaces the width; the gap is named in the run, recorded,
  and spoken once by the next notice.
