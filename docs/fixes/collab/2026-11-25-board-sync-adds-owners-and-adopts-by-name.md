# The board sync adds owners instead of replacing them, and can adopt a named card

**2026-11-25 · component: collab**

## What was wrong

When a file's header named an owner, `board_sync.py` replaced everyone already on the card. That removes people someone set by hand in the board. A plan with no id in its name also could not find its existing card, so a first run created a second card beside it.

## What changed

Assignees are now added and never removed. A repo that wants the header to be the whole list sets `"assignees": "replace"` in `plans/.board.json`.

`plans/.board.json` takes an optional `adopt` map from a file path to a card (`"plans/01-the-company.md": "ALPHA-12"`). The sync claims that card instead of creating one, and warns when the card is missing or already claimed.

## References

- `bin/collab/kit/scripts/board_sync.py`
- `bin/collab/kit/docs/board-sync.md`
- `bin/collab/tests/test_board_sync.py` (two new tests; 10 pass)
