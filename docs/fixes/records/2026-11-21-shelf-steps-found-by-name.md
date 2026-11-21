## records · unversioned · 2026-11-21 — a plan shelf finds its own step cards by name

### Why
Review of the plan-shelf change found that a shelf's sync could not find a step card by name. Step cards carry no labels, and the shelf scope demanded the shelf's labels, so on a short board listing a second step was created.

### Files
- `bin/boards/plan_sync.py`
- `bin/boards/tests/test_plan_sync_shelves.py`

### What
`found_by_title` applies the label scope only to top-level cards. A step is scoped by its parent. A test covers a shelf and a project looking up an unlabelled step.
