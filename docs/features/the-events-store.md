# The events store — one place where things that happened are written

## What it is

A small, append-only record of what happened on the house: a scheduled job failed, the guardian
saw something. Every event is one row, written by one door, into one file per day. Later parts of
the house (the keeper that merges and deploys, the console) read this record instead of each
keeping its own.

Today two sources write to it: **Nornir** (a scheduled job that exits non-zero) and **Garmr**
(every finding judged above INFO).

## What you need

Nothing beyond the house itself. The files live in `<home>/state/events/YYYY-MM-DD.jsonl`.
Set `YMIR_EVENTS_DIR` to put them somewhere else.

## The commands

Write a row:

`bin/records/events-append.sh --source cron --kind job-failed --subject "backup failed" --severity HIGH --key backup-2026-11-21 --body "rc=7"`

Read the newest rows, optionally filtered:

`bin/records/events-tail.sh -n 20 --source garmr --min-severity HIGH`

Search the last seven days (`--days N` widens it):

`bin/records/events-search.sh "disk"`

## The row

| Field | Meaning |
|---|---|
| `ts` | ISO-8601 time with offset; defaults to now |
| `source` | who is speaking, lower-case (`cron`, `garmr`) |
| `kind` | what sort of event (`job-failed`, `finding`) |
| `subject` | one line, at most 200 characters |
| `severity` | `INFO`, `MEDIUM`, `HIGH` or `CRITICAL` |
| `key` | the dedupe key; derived from the row when you give none |
| `body` | the detail, at most 4000 characters |

## Limits

- A row with a missing or malformed field is **refused** (exit 1) and nothing is written.
- The same `key` on the same day is written once; the second call says `duplicate` and exits 0.
- A source never blocks on the store: if the write fails, the cron job and the Garmr verdict go on.
- Only failures and findings are wired so far; other sources are added by calling the same door.

## If it does not work

Run the append by hand and read the message. `refused — …` names the field that was wrong.
`the home is unresolved` means `YMIR_HOME` is not set and the home could not be found.
The proof is `bash tests/test_events_store.sh`.

## CHANGE LOG

- **2026-11-21** — opened (plan 333 phase 1).
