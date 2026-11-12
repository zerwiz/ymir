# The daily log writes itself

**What it is.** Your home keeps one log per day, `hodd/memory/daily/YYYY-MM-DD.md`. Agents add to it with
`bin/records/daily-log.sh`; **the daily line** (`bin/time/daily-line.sh`) now also adds, by itself, *what moved today*
— read from the record, not from anyone's memory:

- commits in your home (the machine's own housekeeping commits are left out),
- commits in every project checked out on this machine (the `clones` in `hodd/identity/projects.yaml`) and in Ymir,
- mail sent today (the mail desk's store and the mail ledger),
- meeting records added today under `svartalfaheim/*/meetings/`,
- worker handoffs and blocked cards, as before.

It remembers what it has already logged, so it can run several times a day: each run adds only what is new, and a run
with nothing new writes nothing.

## What you need

A home (`YMIR_HOME`, resolved by `bin/vault/hoard-lib.sh`) and, for the projects, their `clones` entry for this machine.

## Do it

    bin/time/daily-line.sh             # add what moved since the last run to today's log
    bin/time/daily-line.sh --dry-run   # print it, write nothing (and mark nothing as logged)
    bin/time/daily-line.sh --date 2026-11-11
    python3 bin/time/daily_moved.py --self-test

To have it run by itself, put these rows in your home's `config/cron.yaml`:

    @dev 12:30 bin/time/daily-line.sh
    @dev 18:00 bin/time/daily-line.sh
    @dev 23:30 bin/time/daily-line.sh

## Limits

- It lists *what* moved (commit subjects, mail subjects, meeting files), not *why*. The why is still written by the
  person or agent doing the work, with `daily-log.sh add`.
- Mail sent shows only after the mail desk has imported it.

## If it does not work

- *Nothing is written:* nothing new since the last run — that is correct. `--dry-run` shows what it sees.
- *A project's commits are missing:* its `clones` entry does not name this machine's hostname.

## CHANGE LOG

- **2026-11-11** — first written: the daily line says what moved, idempotently (plan 252).
