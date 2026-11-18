# time · 2026-11-18 — the day gate waits on the mark

## Files

- `.agents/tests/nornir-schedule-shapes.test.sh` — `run_at` waits for the mark file to settle
- `bin/gates/checks.d/0510-nornir-day-gate.sh` — unchanged; it runs that test

## Why

The scheduler runs each row in a background subshell (`( run_row ) &`) and exits on
`BROKK_CRON_ONCE`, so `cron.pid` is already gone — or still holds a previous pass's pid — while
the row it just fired is writing its mark.

`run_at` waited on that pid, so the wait could finish before the row it was waiting for had
written anything. On an idle machine the row usually won the race; on a loaded runner it did not.
CI reported `a day gate fires on its own day — want 1, got 0`, and the very next count in the same
minute saw the fire arrive. The gate looked red for a fault it did not have.

## Fix

`run_at` waits on the one fact that settles: the mark file. It polls the file's size and line
count every 250 ms and returns after the file has been unchanged for two seconds, bounded at
twenty-five seconds. A row either writes within that quiet window or it did not fire at all.

Two consecutive runs of the whole matrix are green here, and the assertions that failed in CI
(`a day gate fires on its own day`, `the day list fires on a listed day`) now read the count after
the write has landed.
