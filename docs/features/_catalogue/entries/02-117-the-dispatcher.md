---
section: agents-work-collaboration
---
| Agents | **The dispatcher — the queues become one list** (`bin/dispatch/dispatch.sh` · `bin/time/nornir-job-dispatch.sh`) | Reads the mail desk's needs-you column and the durable wake queue, keeps only what is genuinely the Allfather's (never a `lock-ask`, which belongs to the arm, and never a notice), and writes one proposal line per item inside the marked block of his to-do — with a `sha256(source\|id)` key so the same item is never proposed twice, an attempt cap of three after which the key is terminal, and a ledger that records every run as `work` or `no-op` with its reasons. An unreadable input exits non-zero instead of claiming `0`. The timer is registered in `config/units.yaml` (every 10 minutes) and rendered by `bin/engine/units.sh` | [docs/features/the-dispatcher.md](docs/features/the-dispatcher.md) |

## CHANGE LOG

- **2026-11-16** — opened with the door itself (plan 304 §4.3, the dispatcher).
