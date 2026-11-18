# mail · 2026-11-17 — the weekly draft sweep: every draft, the trend, one line with buttons

## Files

- `bin/mail/draft-age.sh` — `--weekly`: every draft oldest first, one trend row, one phone line with
  a send/edit/discard button per draft, and total silence on a week with no drafts
- `bin/mail/tests/test_draft_age.py` — five weekly proofs added (16 in the file now)
- `hodd/state/draft-trend.jsonl` — NEW, append-only, in the home: `{at, drafts, aged, oldest_days}`
- `docs/features/draft-age-the-unwritten-letter.md` — the how-to for the sweep
- plan 305's appended decision (2026-11-17 03:05) is the specification

## Why

The Allfather asked whether the draft check should also run weekly. The answer was yes — **as a
different job, not the same check on a second schedule** — because the morning brief cannot do three
things a week can:

1. **It cannot witness its own death.** The only draft check lived inside a job that can die; this
   house has measured a scheduler running a stale tree for 28 days.
2. **It only looks at *aged*.** A draft one day old is correct on Tuesday and is the week's
   unfinished correspondence by Friday. The brief asks "is anything too old"; the week asks "what did
   I start and not finish".
3. **It has no memory.** A count per day cannot show a trend.

## Fix

`--weekly` reads the same mailbox through the same door and adds four acts:

- **Every draft, oldest first**, numbered, with its age — not only the aged ones.
- **One trend row per run**, appended to `hodd/state/draft-trend.jsonl` in the home (Rule 04: state
  belongs to the hoard) and never rewritten (Rule 06).
- **ONE line to the phone**, naming every draft, through `bin/notify/send.sh` with `--buttons`: a
  **send · edit · discard** button per draft. A nudge that cannot be acted on is a nag.
- **Silence on a quiet week**: no drafts means no message at all, and one no-op Rune saying the
  sweep looked. A nag gets muted, and a muted door is a dead one.

The two acts the door may not perform for itself are delegated, not restated: `bin/records/runes-append.sh`
owns the ledger and `bin/notify/send.sh` owns the phone. The settle order is deliberate — the trend row
is written **before** the message, so a delivery that fails leaves the week recorded.

A **skip** and an **unread mailbox** are not a quiet week: a skip writes no trend row and sends
nothing, and an unreadable mailbox stops the sweep with `UNABLE` (exit 3). Only a week the door really
read, and really found empty, is silent.

## Proof

`python3 bin/mail/tests/test_draft_age.py` — 16 proofs against a stub Gmail; the five weekly ones are:

| Proof | What it pins |
|---|---|
| `WeeklyQuiet` | no drafts → **no message**, one trend row of zeros, one no-op Rune |
| `WeeklyEvery` | every draft named oldest first and numbered — including the ones too young for the daily limit — with three buttons each, laid one draft to a row |
| `WeeklyAged` | an aged draft still fails the sweep (exit 1) and still sends exactly ONE line |
| `WeeklyTrend` | two sweeps append two rows and the first is byte-identical afterwards |
| `WeeklySkip` | no grant → **no** trend row, nothing sent: a skip never looks like a quiet week |

The line itself is proved separately in `bin/notify/tests/test_send_buttons.py` (the markup reaches
the Bot API, the caller's rows survive, a button that could not render is refused).

## The schedule

`@heart Mon 09:15 bin/mail/draft-age.sh --weekly` — on the heart, because the mailbox is ingested
there (a sweep on a machine that cannot read the mailbox would report a clean week it never looked
at), and at 09:15 so the week never pre-empts the 07:00 brief. The row ships in
`config/cron.yaml.example` and is seated into an existing home by migration
`0025-the-weekly-draft-sweep.sh`. See `docs/fixes/time/2026-11-17-the-clock-can-say-monday.md` for the
day gate that made the row fire at all.

## The cost, stated

One more schedule row, one small state file, and one risk — a weekly nag. The three rules that hold it
down: one line per week, the same weekly key so a rerun cannot repeat it, and total silence on a clean
week. Buttons are drawn for the first ten drafts; beyond that the line names them all and says so.
