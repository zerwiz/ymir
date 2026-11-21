---
section: agents-work-collaboration
---
| Collaboration | The night report — what the fleet did while you slept (`bin/day/night-report.sh`) | Each morning it reads every seat's errands, the PRs of every registered repository, the Runes ledger and your list, then writes `hodd/docs/status/YYYY-MM-DD-night-report.md` in the home: done, not done and why, merged, open and why, alarms and mends, and what waits on you, oldest first. It ticks an item only when its subject names one PR or errand proven closed, appending a dated note and never rewriting the item. It sends one Telegram message with three buttons; `--dry-run` writes nothing. | [Guide](docs/features/night-report.md) |

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #867
