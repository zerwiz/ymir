# 2026-11-21 — the night report: what the fleet did overnight, in one morning read

**Component:** day (`bin/day/night-report.sh`, `bin/day/night_report.py`, `bin/day/night_seat.py`).

## What was missing

The operator asked for a report of the night's work, done and not done, waiting for him in the morning.
The records already existed, but they were spread across many places:

- the errand status and report files on each seat;
- the pull requests on GitHub;
- the Runes ledger;
- his list, the boards, and the voice ledger.

Nothing read them together. Nothing ticked his list when the work behind an item closed, so the list
kept items that were already done.

## What this change adds

`bin/day/night-report.sh` gathers the window from all of those sources. By default the window starts at
the last report, or at 22:00 the evening before. Every line of the report names its source. The report
is written to `hodd/docs/status/YYYY-MM-DD-night-report.md` in the home and shipped through
`bin/vault/home-sync.sh`. A short line goes into the daily log, and one Telegram message goes out through
`bin/notify/send.sh`. The message has six lines and three buttons.

`state/` is not carried by the home's git, so each other seat is read over its ssh road from
`hodd/data/fleet.json`. The script sends `night_seat.py` itself to that seat's `python3 -`. This works
even on a seat whose runtime does not carry the night report yet. A seat that does not answer is named
in the report.

## What it will not do

It never rewrites one of his items. A proven item gets `- [x]` and an appended `(done: …)` note. It is
proven only when its **subject** names exactly one PR or errand, and that one closed. Several rules
guard against a false tick:

- A PR named only in an item's reasons does not count.
- A PR merged before the item was written does not count.
- An item that names several PRs is never ticked.

All three are tests.

## Proof

`python3 bin/day/tests/test_night_report.py` runs 5 tests, and all pass. They use a fixture home with
invented names, no network, and no ssh. The tests cover:

- the counts;
- an appended tick that is never rewritten;
- sources on every line;
- an empty night that says so in one line;
- a dry run that writes nothing.

A dry run on the dev seat read three seats, named the fourth as unreachable, and listed 42 PRs merged
and 38 open. It would have ticked four items, and each one was checked by hand against its PR.

The schedule row (`@heart 06:30`, with a `@dev 06:50 --fallback` stand-in) goes into the home's
`config/cron.yaml`. It stays commented out until this change is merged, because `cron-guard` refuses a
row for a script that does not ship yet.
