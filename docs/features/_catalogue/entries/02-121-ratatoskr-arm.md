---
section: agents-work-collaboration
---
| Agents | **The arm door — a task for a machine goes to its one holder** (`bin/bridge/ratatoskr-arm.sh`) | A task addressed to a machine has no pane to wake, so it goes to that machine's one live arm holder: here through `bin/agents/eindri-notify.sh`, across the fleet through `bin/fleet/arm-send.sh`, one verb over doors that already exist. A machine the registry does not know, or one with nobody holding the arm, is refused **by name** and nothing is handed; `--who` is the holder's roll across the fleet, and a machine that does not answer says `no answer` — never confused with `nobody holds the arm`. It says `handed`, never `delivered`: a task counts only when the holder answers (RULES/49, 56) | [docs/features/ratatoskr-arm.md](docs/features/ratatoskr-arm.md) |

See docs/features/ratatoskr-arm.md

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 5).
