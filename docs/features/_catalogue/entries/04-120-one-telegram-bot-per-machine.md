---
section: fleet-models
---
| Fleet | **One Telegram bot per machine, read by the arm holder** (`bin/notify/telegram-reader.sh`; off until the home sets `reader: arm`) | The machine's one bot moves with the arm between pi, Claude Code and Hermes, never with two readers, and the operator's id is set once. pi and Hermes reconnect by themselves when the arm moves; a running Claude Code session needs `/mcp`. | [docs/features/telegram-one-bot.md](docs/features/telegram-one-bot.md) |

## CHANGE LOG

- 2026-11-27 — first version.
