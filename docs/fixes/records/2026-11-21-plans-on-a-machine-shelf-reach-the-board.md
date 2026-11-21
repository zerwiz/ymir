## records · unversioned · 2026-11-21 — plans on a machine's own shelf reach the board

### Why
Shipping a plan from a machine's shelf (`hodd/machines/<machine>/plans/`) printed `plan-card: … no project with a board: block keeps its plans where … lies`. The plan tools found a plan's board only through a project's ledger, and a machine shelf is no project's.

### Files
- `bin/boards/plan_sync.py`, `bin/boards/plan-card-after.sh`
- `bin/boards/tests/test_plan_sync_shelves.py`
- `docs/fixes/records/2026-11-21-plans-on-a-machine-shelf-reach-the-board.md`

### What
The registry may now carry a top-level `plan_shelves:` list beside `projects:`. Each entry names a home folder of numbered plans, optional `labels:`, and a `board:` block shaped like a project's. `project_for_file` and `--project` find a shelf the same way as a project.

Plan numbers repeat between shelves, so a shelf's cards carry its labels and a sync sees only the cards that carry all of them. A project's sync ignores every card bearing a label some shelf owns, so a shelf's plan 1 can never be mistaken for the project's plan 1. A shelf with no `board:` block is refused by name, and `plan-card-after.sh` prints that refusal as it does for a project without a board.

### Verified
`bin/boards/tests/test_plan_sync_shelves.py` (a fake home: shelf found, label scoping both ways, boardless shelf refused) and the existing `test_plan_sync_repo.py` both pass. A project's behaviour is unchanged when no shelf is registered.

## CHANGE LOG

- **2026-11-21** — opened.
