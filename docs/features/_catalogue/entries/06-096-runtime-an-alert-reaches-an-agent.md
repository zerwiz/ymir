---
section: voice-and-presence
---
| Runtime | **An alert reaches an agent** (`bin/notify/send.sh`, the owner road) | A HIGH or CRITICAL line is handed to the arm holder that owns its source (the machine in the line, or `config/notify-owners.conf`; the heart's arm when the owner's is dead) as a turn, and the agent answers the operator in the chat with look · fix · silence-for-a-day. The raw bot post waits 10 minutes and goes out only if no agent answered. One line per alarm per hour, CRITICAL included, with the repeat count; a failing cron row names its own stderr | [docs/features/the-hotline.md](docs/features/the-hotline.md) |

## CHANGE LOG

- 2026-11-21 — added with the owner road (errand alerts-reach-agents).
