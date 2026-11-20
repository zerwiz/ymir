---
section: agents-work-collaboration
---
| Plan sync | A project's plans as cards on its board | `bin/boards/plan-sync.sh --project <id>` mirrors the plan ledger onto the project's board, one card per plan (`NNN · title`, label `plan`, state group from the ledger status), idempotent, never deleting, leaving a hand-moved card alone; the board is reached through the contract's `mcp` adapter named in the registry | [docs/features/plan-sync.md](docs/features/plan-sync.md) |
