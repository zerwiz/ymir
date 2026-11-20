---
section: agents-work-collaboration
---
| Plan sync | A project's plans as whole cards on its board | `bin/boards/plan-sync.sh --project <id>` mirrors the plan ledger onto the project's board, one whole card per plan (`NNN · title`, label `plan`, state group from the ledger status): the plan's full text as Markdown under a "generated from the file" line, its phases as sub-items with their accept lines, a link to the file, its diagrams drawn by the board where it can; idempotent by a stamp, upgrading short cards in place, never deleting, leaving a hand-moved card alone. The plan tools (`plan.sh new`, `note.sh`, `home-sync.sh ship`) sync a plan's card after every change, and a seat with no road says so | [docs/features/plan-sync.md](docs/features/plan-sync.md) |

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #837
- 2026-11-20 — whole cards: full text, phases as sub-items, link, diagrams; the plan tools keep the board current (plan 335, 3b).
