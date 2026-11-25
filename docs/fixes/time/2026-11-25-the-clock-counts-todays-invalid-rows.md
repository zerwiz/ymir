# The clock counts today's invalid rows

**Component:** time (plan 369 item 12)

## What was wrong

`nornir-cron-start.sh --status` reported `invalid=2`. Both rows were readable `@every` rows. A scheduler
that did not yet know that shape had written them to `state/.cron-invalid`, and nothing ever cleared the
file.

The `today: unbound variable` error in the same item was already fixed on `main` by #935.

## What changed

- `--status` reads the schedule as it stands and counts the rows that cannot fire now.
- Each start of the clock rewrites `state/.cron-invalid` from the same answer.

## Proof

`bin/time/tests/test_cron_invalid.sh` (gate `cron-invalid`) covers a stale record, a really bad row, and a
retirement with no shell error.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #954
