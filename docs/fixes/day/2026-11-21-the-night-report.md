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

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #867

## Addendum, 2026-11-21 — his to-do is the board, so the report reads and closes it there

The judge's review of PR #867 found that the report read and ticked `life/personal/me/todo.md`. The home
froze that file on 2026-11-20: his to-do moved to the board, and `bin/records/todo.sh` is the one door
the house writes it through. Ticking the file gave two truths for one item, and *Waiting on you* was
read from a mirror that no longer follows the board.

Now the report reads his to-do with `todo.sh list --json` and closes a proven card with
`todo.sh move <card> Done`. The proof is written in the report, under *Closed on your to-do*. The file is
never written. When the board is not configured, or does not answer, the file is read so he still sees
what waits, nothing is closed, and the report says why under *What could not be read*.

A card's title lost its date in the migration, so the guard "a PR merged before the item was written does
not count" reads the date from the card's description instead. Without that, a live dry run would have
closed *Ask … to merge Foreman PR #20*, because `#20` in this repository merged in September. With it,
the same dry run closes exactly the four cards the judge checked by hand (#831, #771, #810, #800), plus
the card for #858, which merged tonight.

Item 3 of the review (the whole file rewritten from an old snapshot) goes away with this: each close is
one card, moved through the door, and nothing is rewritten.

Proof: `python3 bin/day/tests/test_night_report.py` now runs 6 tests, and all pass. A fixture stands in
for the door. The tests show that a proven card is moved to Done, the file stays byte-for-byte the same
(also when the board is not configured), and a second run moves nothing again.


## Addendum, 2026-11-21 — the buttons' prompts fit in 64 bytes

Telegram caps a button's `callback_data` at 64 bytes, and `bin/notify/telegram-buttons.mjs` clips a
longer prompt at a word boundary. Two of the three prompts were longer, so a tap arrived as
*"Take the PRs listed green in hodd/docs/status/…-night-r"* (the merge was lost) and
*"Read the 'Errands not done' section of"* (the object was lost).

Each prompt is now one short sentence that keeps its verb and its object and names the report by date,
such as *"Merge the green PRs in the 2026-11-21 night report"*. A test renders the three buttons through
`telegram-buttons.sh emit --format reply-markup` and asserts that each `callback_data` equals its prompt.
