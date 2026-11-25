# The board sync finds its description block by content, not by markers

**2026-11-25 · component: collab**

## What was wrong

The sync wrapped its block in HTML comments to find it again. Plane drops HTML comments and wraps the text in a `<div>`, so on the next run the block was not found, and a fresh copy was added above the old one. Every run would have stacked another copy on every card.

## What changed

`merge_description` now recognises its own block by its content (the list of `Created`, `Updated`, `Product`, `Was`, `Reviewer`, `Source` and `Links` lines), keeps Plane's `<div>` balanced, and returns the description unchanged when nothing differs, so a second run reports `unchanged`. Human text after the block is kept. A new test covers a block that the board has rewrapped.

## References

- `bin/collab/kit/scripts/board_sync.py`
- `bin/collab/tests/test_board_sync.py`
