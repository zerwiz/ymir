---
section: agents-work-collaboration
---
| Agents | **The ready check** (`bin/seat/agent-ready.sh`) | One answer per target in one vocabulary, for both backends: `ready`, `working`, `blocked: <why>`, `dead` — with the reason a person acts on (`blocked: trust prompt` for a pane standing on a harness's trust dialog, `blocked: lost turn, run recover` for a Hermes session paused by an unknown admission). Reads herdr's `agent get`/`agent explain` and joins `hermes sessions list` with the runtime's own admissions table. `--all` for every agent and session on the machine, `--json` for a script, and the exit code carries the same answer (`0` ready · `1` working · `2` blocked · `3` dead) | [docs/features/agent-ready-check.md](docs/features/agent-ready-check.md) |

See docs/features/agent-ready-check.md

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 1).
