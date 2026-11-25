# The kit gains a one-way sync from plan, ticket and document headers to Plane cards

**2026-11-25 · component: collab**

## What was missing

The header fields added the day before (`created`, `product`, `labels`, `parent` and the rest) had no reader that
put them on a board. A project that wanted its plans on Plane had to write its own sync, and each copy would drift.

## What changed

`bin/collab/kit/scripts/board_sync.py` reads every header with the reader `status.py` already uses and upserts one
Plane card per file. It is a dry run unless given `--apply`.

- A card is found by its `external_id` (the file path), never by title, so a renamed title updates the card.
- A card made before the tool existed is adopted by its id (`PREFIX-NNN` at the start of its name) and is never duplicated.
- It writes name, state, priority, assignees, labels, dates and parent, plus a block at the top of the description with `created`, `updated`, `product`, `legacy_id`, source and links. Text a person adds below the block is kept.
- It never deletes or moves a card and never writes to a file. The token is read from an environment variable the config names.
- Configuration is `plans/.board.json` (a template ships as `plans/.board.json.example`): the board's URL and workspace, which product maps to which Plane project, and optional state, priority and person aliases.

## Proof

`bin/collab/tests/test_board_sync.py` runs seven cases against a fake Plane held in memory: a dry run writes nothing, an apply creates cards with dates and parent, a second run is unchanged, a rename updates in place, human text survives, an older card is adopted, and a missing token is refused.

## References

- `bin/collab/kit/scripts/board_sync.py`
- `bin/collab/kit/plans/.board.json.example`
- `bin/collab/kit/docs/headers.md`
