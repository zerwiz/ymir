---
section: agents-work-collaboration
---
| Agents | **The proof — one nonce through every door** (`bin/bridge/a2a-talk.sh prove`) | The house's own proof that agents find and answer each other: a nonce through the three doors of the loop — queue, relay, arm — and, with `--live`, through two real agents and back unchanged. It extends the door that already proves the channel rather than adding a second prover, and it has no partial green: a door that cannot answer is `FAILED` and named, a hop that does not arrive is `UNPROVED` with the agent and the task id, and the exit code says so | [docs/features/a2a-prove.md](docs/features/a2a-prove.md) |

See docs/features/a2a-prove.md

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 7).
