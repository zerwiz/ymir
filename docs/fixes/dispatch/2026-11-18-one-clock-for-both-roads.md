# dispatch · 2026-11-18 — one clock for both roads

## Files

- `bin/dispatch/dispatch.py` — `_store_columns` windows the mail rows by the run's own stamp
- `bin/dispatch/tests/test_dispatch.py` — the existing suite, green again (51 passed, 0 failed)

## Why

The dispatcher reads two roads: the wake queue and the mail store. The wake road windowed its
rows by `now()`, which honours `DISPATCH_NOW`; the mail road handed the window to
`gna_store.latest(account, hours)`, which measures it from the **real** clock.

One run therefore judged one inbox by two clocks. In the hall the error hides, because both
clocks are nearly the same. In a test it does not: the fixture pins the run to `2026-11-16T17:00Z`
and puts its messages at `09:00Z` the same day, so the wake ask came through and the mail rows
fell outside a window measured from today. `dispatch` went red (40 passed, 11 failed) a day after
the test was written, and the failure looked like a cap bug because the four-attempt test seeds
its ledger with a mail key that never arrived.

## Fix

`_store_columns` asks the store for every row (`latest(account, None)`) and applies the cutoff
itself, with the same `now() - hours` the wake road uses and the same rule for a stamp it cannot
read (keep it, never silently drop it). One clock decides both roads, so a pinned clock is
pinned everywhere — and the test's fixed dates stay true.

## Not changed

The desk road (`_desk_columns`) still passes `hours` to the running desk: that window belongs to
a live service answering in real time, which is the right clock there. A test never uses it
(`GNA_DESK_URL` is empty), so no test can be decided by it.
