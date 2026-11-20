---
section: core-install-run-operate
---
| Heavy slot | `bin/heavy-slot.sh` | The machine's counted heavy lanes — a job takes a free lane, and one that finds every lane held waits and says whose job it waits for | [docs/features/heavy-slot.md](docs/features/heavy-slot.md) |

The number of lanes is the machine's own, read from `hosts.<host>.lanes` in the home's fleet registry.

## CHANGE LOG

- **2026-11-18** — corrected to counted lanes; the exclusive lock had been read as "one builder".
- **2026-11-17** — written with the change it describes (plan 002 §6.1).
