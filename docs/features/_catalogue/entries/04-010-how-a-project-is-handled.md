---
section: fleet-models
---
| Fleet | How a project is handled, in one read | Each project's registry row carries a `handling:` block: public or private, where its plans live, its board, its people, whether it is private to the operator, who merges under which gates, how it deploys, and its vault key names. Every value names its source, and `bin/records/project.sh` reads one field, audits every row, and renders the page | [docs/features/how-a-project-is-handled.md](docs/features/how-a-project-is-handled.md) |

## CHANGE LOG

- **2026-11-21** — the page was written for the change that made it true (plan 345).
