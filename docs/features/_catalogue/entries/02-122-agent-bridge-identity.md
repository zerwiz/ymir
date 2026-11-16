---
section: agents-work-collaboration
---
| Agents | **The bridge identity** (`bin/bridge/a2a-bridge-session.sh`) | Every session's A2A bridge names itself from its own environment: `<harness>-<pane>` (`pi-w6R-p1`, `claude-w39-p23`), never `brokk-…` for a non-pi agent (RULES/44); advertises the name the fleet registry gives this machine and binds an address that name can actually be dialled on, never loopback on a fleet seat; keeps one inbox per session; and releases a port claim whose process is gone, so a crashed session cannot exhaust the span. Seated by `bin/bridge/a2a-mcp.sh install`, so install and every update have it. `--identity` and `--dry` are the two ways to see it without spawning anything | [docs/features/agent-bridge-identity.md](docs/features/agent-bridge-identity.md) |

See docs/features/agent-bridge-identity.md

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 6).
