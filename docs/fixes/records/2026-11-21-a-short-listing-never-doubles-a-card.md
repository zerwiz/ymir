# Plan sync doubled cards when the board's listing came back short

**Date:** 2026-11-21 · **Component:** records (`bin/boards/plan_sync.py`, `tests/test_plan_sync.py`) ·
**Errand:** `open-ends`

## What was wrong

The full plan sync for the Ymir place ran twice that night while the board's door was restarted four times. Each
restart met Plane's rate limit, and for a while the door listed a place short or not at all. A plan whose card the
listing missed looked new, and was created again: plan 340 ended with four cards (925, 927, 936, 940, all one
stamp) and plan 343 with two (926, 961). The same weakness explains most of the place's older duplicates: 492 plan
cards for 272 plans.

A second, smaller fault: plan 111's `add_link` was refused with `URL already exists` because Plane's listing spelled
the link differently, and the plan counted as failed.

## What was built

- Before it creates a plan card, the sync asks for the exact title by name (`list_cards` with a query). A card that
  answers is left for the next run's full listing, and the summary counts it as `found=`.
- Before it creates a step under an existing card, it does the same under that parent.
- An `add_link` refused with `already exists` is taken as standing.

Nothing here deletes a duplicate. Which copy to keep is a choice made on the board, with the person who owns it.

## Proof

`python3 -m unittest tests.test_plan_sync` — 9 OK. The new test hides every card from the full listing; the next run
writes no card and reports `found=3`, and the run after it changes nothing.
