---
section: agents-work-collaboration
---
| Agents | **The relay — a task gets woken and the answer comes back** (`bin/bridge/ratatoskr-relay.sh`) | The loop that turns the queue into a conversation: it wakes a **ready** target (`herdr agent prompt` where that verb exists, `agent send` + Enter where it does not — probed, never assumed), confirms the agent moved, retries once, and carries the answer into the **asker's** own pane under `[ratatoskr · from <claimer> · re <id>]`. A blocked pane is never typed into, a mid-turn agent waits, and a wake that changed nothing is a miss naming the pane and the reason. Seated as a user unit from `config/units.yaml` by install step `a2a` and re-seated by every update; the unit waits for a live arm holder, because no agent runs unowned | [docs/features/ratatoskr-relay.md](docs/features/ratatoskr-relay.md) |

See docs/features/ratatoskr-relay.md

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 4).
