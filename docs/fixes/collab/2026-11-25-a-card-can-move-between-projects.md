# The kit moves a card between Plane projects, and ships a handoff page

**2026-11-25 · component: collab**

## What was missing

Plane Community 1.4 has no move to another project, and nothing in the kit said where columns are renamed, added or deleted.

## What changed

`bin/collab/kit/scripts/board_move.py` copies a card into the target project (title, description, priority, people, labels, dates, comments), notes `Moved to …` on the original and sets it to Cancelled. It is a dry run unless given `--apply`, and the new card has a new number.

`bin/collab/kit/docs/board-sync.md` is the handoff for people and agents: how to run both board scripts safely, the rules an agent follows, and where columns are managed in Plane (project Settings, States).

## References

- `bin/collab/kit/scripts/board_move.py`
- `bin/collab/kit/docs/board-sync.md`
- `bin/collab/tests/test_board_sync.py`

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #943
