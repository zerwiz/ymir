---
section: agents-work-collaboration
---
| Delivery | **Run the smithy from anywhere — the agent tool and the phone** (`bin/forge/team-run.sh` · [how-to](docs/features/run-the-smithy-from-anywhere.md)) | His word, 2026-11-21: *"in the agent tool, I want to be able to run the smidja simply when I'm out and about. For bigger tasks, run the smidja."* and *"I want to be able to choose the herdr runtime for it, or the internal runtime for the agents."* One door runs the smithy on a named machine or the least loaded one (`--on auto`), over ssh through that machine's own install, and answers with run id, machine, runtime, state and link. The runtime is `herdr` (each agent seated in a visible pane) or `internal` (headless), defaulted per machine in `config/machines/<host>/smidja.yaml` and overridable per run; the answer names it. Faces: the Pi tool and the MCP tool `ymir_team_run`, and a six-line phone answer. Proved by `bin/forge/tests/test_team_run.py` | [docs/features/run-the-smithy-from-anywhere.md](docs/features/run-the-smithy-from-anywhere.md) |

## CHANGE LOG

- 2026-11-21 — added with the door.
