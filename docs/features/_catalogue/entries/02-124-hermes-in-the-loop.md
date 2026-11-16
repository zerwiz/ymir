---
section: agents-work-collaboration
---
| Agents | **Hermes in the loop** (`bin/seat/agent-ready.sh hermes:…` · the pane road) | Hermes reaches the loop in two shapes and one vocabulary. An agent in a **pane** is an ordinary pane agent — herdr seats it, the ready check judges it, the queue and relay wake it, and its answer returns to the asker. A **session** behind a gateway has no pane: it is addressed by id or title, its state read from the runtime's own admissions table, so a turn lost in a crash shows as `blocked: lost turn, run recover` and is never resumed by a tool. The headless road stays **stated, not claimed**: there is no `hermes mcp serve` in this version, and switching on the API server or the MCP plugin is the operator's decision | [docs/features/hermes-in-the-loop.md](docs/features/hermes-in-the-loop.md) |

See docs/features/hermes-in-the-loop.md

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 8).
