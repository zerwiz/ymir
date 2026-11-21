# A step found by name must sit under this plan card

**Date:** 2026-11-21 · **Component:** records (`bin/boards/plan_sync.py`, `tests/test_plan_sync.py`) ·
**Errand:** `rework-862` (the review of PR #862)

## What was wrong

The change in `2026-11-21-a-short-listing-never-doubles-a-card.md` asked for a step by name before creating it. Its
check compared only whether the found card had a parent. A same-titled step under any other card, such as a
duplicate plan card, stood in for this card's step. So the step was never made, and the plan stayed `updated` on
every run.

## What was built

- `found_by_title` now compares the parent itself: `str(c["parent"]) == str(parent)`.
- Three tests: a hidden step under this card is not made again; a same-titled step under another card does not
  stand for ours; an `add_link` refused as `already exists` is not a failure.

The full account is the addendum at the foot of the first note.

## Proof

`python3 -m unittest tests.test_plan_sync` — 12 OK. Each new test fails against the broken code and passes on the
fix.
