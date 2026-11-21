---
section: agents-work-collaboration
---
| Collaboration | **Talk to, and steer, any agent — `fleet-tell`** (`bin/fleet/fleet-tell.sh`, Pi and MCP `gna_fleet_tell`) | One road for every message between agents on any machine: an arm holder, an errand, or a pane. It uses the target machine's own `tell.sh` over ssh, falls back to typing into the agent's herdr pane, signs the line, and reports one row per target. It carries the steer, answer and stop verbs, and is the road behind the `steer` action of `ymir_errand`. | [docs/features/fleet-tell.md](docs/features/fleet-tell.md) |
