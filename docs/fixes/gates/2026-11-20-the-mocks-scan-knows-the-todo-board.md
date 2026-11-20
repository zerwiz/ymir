# The mocks scan knows the to-do board

**Component:** gates · **Date:** 2026-11-20

## What was wrong

The to-do board door (`bin/records/todo_board.py`, the `todo.sh` face) and its config file
`todo-board.yaml` carry the word `todo` as the feature's own name. The mocks scan reads a bare `todo` in
shipped code as a half-built door, so the whole-tree gate on PR #840 went red on 38 lines that are names,
not stubs. The board library's lane table (`"todo"`, a list name Plane and Trello both ship) was caught too.

## Whose word

The exception was put to the operator, because widening a scan's excuses is a change to oversight, not a
worker's call. His word, 2026-11-20: "merge all into one PR" — this exception is part of that batch.

## What changed

`.agents/skills/galdr-ymirsystem/scripts/mocks-scan.sh` excuses three shapes, each in the same class as an
excuse it already had:

- `bin/records/todo_board.py`, by file, like `bin/records/comms.py` (the ledger it succeeds).
- the filename `todo-board.yaml`, like `todo.md`.
- `bin/boards/cardlib.py` lines that quote `"todo"` as a lane name.

`.agents/tests/mocks-scan.test.sh` still proves a lone `todo`, a look-alike door and a stub beside a declared
file are caught, and the shipped tree passes its own scan.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #853
