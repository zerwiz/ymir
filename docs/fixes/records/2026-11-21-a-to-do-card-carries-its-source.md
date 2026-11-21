# The to-do door's cards were refused: the source rode in the description, not as `source`

**Date:** 2026-11-21 · **Component:** records (`bin/records/todo_board.py`, `bin/records/tests/test_todo_board.py`) ·
**Errand:** `open-ends`

## What was wrong

Gimlé's `create_card` requires `source: <path>#<id>` — the record a card came from — and refuses a card without
it. `todo_board.py` wrote the source only as a `source:` line in the description and never passed the argument.
So every `bin/records/todo.sh add … --source …` was refused with *"a card made by an agent needs
`source: <path>#<id>`"*, and eight to-dos for the operator waited.

A to-do's source is often prose ("the command line", `<file> · line 12 · <trail>`), which the shape refuses too.

## What was built

- `card_source(item)` derives the anchor: the source as given when it is already `<path>#<id>`; `<file>#L<line>`
  for a line of the to-do file; `<record>#<id>` for a voice task; `<file>#<key>` when it opens with a path; and
  `bin/records/todo.sh#<key>` for prose. The description keeps the prose line as before.
- `file_card` passes it as `source`.
- The test's fake board now refuses a card without the shape, as the real door does.

## Proof

`python3 bin/records/tests/test_todo_board.py` — PASS, 0 failed (five new checks on the shape).

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #858
