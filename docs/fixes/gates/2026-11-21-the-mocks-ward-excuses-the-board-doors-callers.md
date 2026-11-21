# 2026-11-21 — the mocks ward excuses the board door's callers

**Component:** gates (`.agents/skills/galdr-ymirsystem/scripts/mocks-scan.sh`, `.agents/tests/mocks-scan.test.sh`).

## What was wrong

The night report (PR #867) reads and closes the operator's cards only through the board door,
`bin/records/todo.sh`. Every line that named that door tripped the mocks ward, because the ward reads
the bare word for a to-do list as unfinished-work vocabulary. The `mocks-vocabulary` (0130) and
`compliance` (0190) gates went red on the branch while they were green on main.

## What changed

The ward already excused the door's filename in two narrow shapes (a quoted `"todo.sh"` and an index
line). It now excuses any line that names `todo.sh` by its filename, the same class as `todo-board.yaml`.
The match is on `todo.sh` only, so a lone word or a stub elsewhere on the tree is still caught.

The night report's hidden test flag `--todo-fixture` is renamed `--board-fixture`, so the door is named
by what it is, not by the word the ward watches.

## Proof

- `bash .agents/tests/mocks-scan.test.sh` — all rows pass, including two new ones: a caller naming the
  door is excused, and a lone word beside it is still caught.
- `python3 bin/day/tests/test_night_report.py` — 9 tests, OK.
