---
section: core-install-run-operate
---
| Record | **The plan board** (`bin/records/plan-board.sh`) | How many plans are done and not done, what to work on next, and which old plans a newer one replaced — from evidence (merged PRs that name the plan, commits, fix notes, the PRs a plan cites), never from a stale label. A status the evidence suggests carries a `?`; `confirm` writes it into the plan's declared header (`status · verified · superseded_by`), and only then is it a fact. `tally · list · next · supersede · show · confirm`, `--json` | [The plan board](docs/features/the-plan-board.md) |
