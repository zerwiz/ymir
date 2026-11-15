---
section: agents-work-collaboration
---
| Agents | **The seat audit** (`bin/seat/seat-audit.sh`) | One line per agent pane in every workspace and tab: folder, branch, dirty count, commits on no remote, whether `HEAD` is in `origin/main`, the PR state and GitHub's own mergeability, and a verdict from the runbook's table. `--tsv` for machines, `--no-pr` offline, `--fetch` for a truthful count. `bin/seat/seat-reap.sh --sweep` reads it and now closes hand-seated tabs too | [docs/features/the-seat-audit.md](docs/features/the-seat-audit.md) |

See docs/features/the-seat-audit.md

## CHANGE LOG

- **2026-11-14** — written with the change it describes (plan 293 parts 1–2).
