---
component: agents
date: 2026-11-16
plan: 303
step: 9
---

# Hermes is a second backend, the way herdr is one

Plan 303 §14, and §13.5's 9a–9f built as one delivery rather than six scripts.

## Why

Five doors reached an agent, and each had learned herdr's own way. Hermes could not be reached
at all: two sessions of one Desktop profile share one gateway and one **inbox**, so a bridge
could not tell them apart and neither could answer the other — one of them said it plainly,
*"my bridge inbox is empty"*, while its twin had drained the message.

A bridge names a process. A **backend** names an address. Hermes is a session, so a backend is
what it needs, and herdr is the shape to copy: six verbs, one resolver, one stamp, one ready
vocabulary.

## What changed

`bin/seat/backends/` — one adapter per backend, in one folder, behind one resolver:

| verb | herdr | hermes |
|---|---|---|
| `list` | `herdr agent list` | `hermes sessions list` joined with the runtime's admissions table |
| `get` | `herdr agent get` | the session's last admission |
| `read` | `herdr agent read` | the tail of `hermes sessions export` |
| `prompt` | `herdr agent prompt`, else `agent send` + Enter | `hermes chat --resume <id> -q -Q`, and a paused session is refused |
| `wait` | poll to the requested state | poll to the requested state |
| `explain` | why herdr says blocked | why it is paused, and the exact recovery |
| `recover` | — | show the lost input, then `hermes sessions discard` — only with `--yes` |

- **the resolver**: `herdr:<pane>`, `hermes:<id-or-title>`, or bare — and **bare is herdr**, so
  nothing that works today changes shape.
- **`ratatoskr who`** now lists Hermes sessions beside the panes (9a), and `ratatoskr send` to a
  `hermes:` target goes through the backend (9b).
- **the `ymir_hermes` MCP door** (9c): `list`, `send`, `recover` in `bin/mcp/ymir-mcp.py`, so
  every harness — Hermes included — carries the same three tools.
- **`recover` prints the lost input BEFORE it discards** (9d), and refuses to discard without
  `--yes`. A person's turn is not a worker's to throw away.
- **identity** (9e): the wake text and the queue carry `[from agent … · herdr pane … · machine]`,
  and a Hermes session's own id is the address it answers to.
- **the watcher** (9f) is the `agentroad` surface: it fails on a bridge named `brokk-` that is
  not pi, on a stalled backend door, and on a relay unit that is enabled but **failed** — which
  is how a pinned runtime that predates the script looks from outside.
- **arrival, per §15.4**: `.agents/harnesses/hermes.yaml` describes the harness for
  `harness-extensions-install.sh`; `.agents/migrations/0023-agents-talk.sh` heals an existing
  home (dead port claims, a stale arm pane, the relay unit, a Hermes restart that is owed); the
  `agentroad` surface is registered in `config/surfaces.yaml` so Eir and Gróa both know it.

## The restart rule, kept mechanically

The migration never restarts Hermes while a turn is live. Where a restart would be wanted it
counts the live admissions; if any is open it writes `state/hermes-restart-pending` naming the
count and restarts **nothing**. That is the operator's standing rule of 2026-11-16, made a line
of code instead of a habit.

## Proof

```
$ bin/seat/backend.sh get herdr:w6R:p1
working
$ bin/seat/backend.sh get hermes:fd2ee4d0
ready
$ bin/seat/backend.sh explain hermes:fd2ee4d0
backend[1]{target,state,reason,recovery,detail}:
  "hermes:fd2ee4d0","ready","","",""
$ bin/bridge/ratatoskr.sh who --local | grep hermes | head -2
  "…","hermes","-","Ok","ready","no","hermes session"
  "…","hermes","-","Audit vaults tech stack","ready","no","hermes session"
```

```
$ bash bin/seat/tests/test_backend_door.sh
test_backend_door: 19 passed, 0 failed
```

The test proves the five things a person cannot check by eye: a bare target is herdr; a session
prefix resolves to the real id and its state comes from the runtime's table; a paused session is
**refused** by `prompt` and never replayed; `recover` prints the lost input before anything is
discarded and discards nothing without `--yes`; and both backends answer one vocabulary.

## What is not proved, and is said so

`ymir_hermes` being callable **from a Hermes agent** needs `hermes plugins install mcp-serve`,
which is not installed here — §13.6 item 2, the operator's decision. The door exists and is
seated for every harness that already speaks MCP; the Hermes half is unproved.

## A note for the next hand

On this seat the relay unit is written and **not enabled**: its `ExecStart` is the pinned
runtime, and that pin predates this branch. `bin/agents/eir-doctor.sh check` says exactly that
in the `agentroad` row — an enabled-but-failed unit is worse than an absent one, so the surface
fails on it by name. After the merge and a runtime update, `systemctl --user enable --now
ratatoskr-relay` is the one command left.

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #798
