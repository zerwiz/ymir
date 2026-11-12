# records · 2026-11-12 — the daily log and the to-do list are joined, both ways

## Files
- `bin/records/comms.py`: `log_entries()`, `_log_opens()` (an entry tagged `open`/`todo` becomes an *open* proposal,
  written with `· log <date>T<time>`), `log_ticks()` (a tick on the list is written to today's log once; the first run
  only remembers; a tick already in the log from another machine is skipped), `log_join()`; `todo-matches` writes new
  ticks unless `--no-log`; new commands `log-ticks` and `log-join`
- `bin/day/day.py`: THE LOG — today's entries, those marked open, those not on the list yet
- `bin/records/tests/test_comms.py` (+4, class `DayAndListJoined`)
- `docs/features/messages-in-out-and-owed.md`: appended section

## Why
The operator, 2026-11-12: *"daily log and personal todolist should go togheter atlest som conector"*. Measured that
day: `day.py` never read the daily log, `comms.py` never wrote to it, and `daily-log.sh` never read the list, so an
entry saying "still open" never reached the list and a tick on the list never showed as done. On that day no log
existed until he asked.

## Proof
On his real home, read-only (`todo-matches --offline --no-log`): of the day's eight entries, the two tagged `open` —
the calendar grant and the morning's failed jobs — were offered, and nothing else. `log-join` printed 8 · 2 · 2.
