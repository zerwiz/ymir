# 2026-11-21 — the night report's rework after the judge's review of PR #867

**Component:** day (`bin/day/night_report.py`, `bin/day/tests/test_night_report.py`).

The judge returned PR #867 with six items. This note records the rework; the detail of each item is in
the addenda at the foot of `docs/fixes/day/2026-11-21-the-night-report.md`.

- **His to-do is the board.** The report reads it with `bin/records/todo.sh list --json` and closes a
  proven card with `todo.sh move <card> Done`. The retired file `life/personal/me/todo.md` is read only
  when the board cannot be, and it is never written.
- **The whole-file rewrite is gone** with the file write, so a concurrent edit can no longer be lost.
- **The buttons fit.** Each prompt is 64 bytes or less, so Telegram's `callback_data` carries it whole;
  a test renders them through `bin/notify/telegram-buttons.sh`.

Proof: `python3 bin/day/tests/test_night_report.py` (7 tests, all pass), and a live dry run on the dev
seat that would close exactly the cards for #858, #831, #800, #810 and #771.
