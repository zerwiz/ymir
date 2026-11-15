---
section: agents-work-collaboration
---
| Review | The review loop — a PR that arrives is judged, and the judge can ask | `review-watch.sh` asks the lock owner about every unjudged PR at its head; `lock-ask.sh` is the read-only agent's mouth; `eindri-review-spawn.sh --pr` seats the judge once per head; `review-seat.sh ensure` is the keeper — a pane holding no agent is reaped and the seat re-raised, naming why a seat could not start | [docs/features/the-review-loop.md](docs/features/the-review-loop.md) |

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #764
