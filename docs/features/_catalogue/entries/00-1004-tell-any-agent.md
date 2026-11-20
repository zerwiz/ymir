---
section: core-install-run-operate
---
| Operate | **Tell any agent — one door** (`bin/agents/tell.sh`, `bin/agents/hermes-tell.sh`) | One verb for every place an agent lives on this machine. `tell.sh <who> "<line>"` resolves the name to its road and says which one it took: `arm` (the arm holder), a herdr pane id or an errand's name (`eindri-send.sh`), `window:<pid or word>` (a terminal window, `window-tell.sh`), and `hermes`, `hermes:desktop` or `hermes:<session>` (the Hermes gateway's API, through `hermes-tell.sh`). `tell.sh --list` names every reachable agent with its road. Every line is stamped `[from <who>]`, and the result is *handed* plus any answer, never *done*. Hermes's key is read from Hermes's own env and never printed. A busy Hermes session (mid-turn or with subagents running) is refused unless `--force`. Another machine (`<machine>:<who>`) is plan 340.5 and is refused by name | [Tell any agent](docs/features/tell-any-agent.md) |

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #840
