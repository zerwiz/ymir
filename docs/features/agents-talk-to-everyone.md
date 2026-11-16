# Agents that find and answer each other — the whole road in one page

## What it is

Ymir now has one loop that lets any agent find any other, hand it a task, and get an answer
back — across harnesses (pi, Claude, Codex, Hermes) and, for a machine's own arm holder, across
machines.

Five doors, each of which owns one question:

| question | door |
|---|---|
| can this agent take a turn right now? | `bin/seat/agent-ready.sh <target>` |
| who is there, on this machine and the fleet? | `bin/bridge/ratatoskr.sh who` |
| hand it a task | `bin/bridge/ratatoskr.sh send <target> "…"` |
| wake it and carry the answer back | `bin/bridge/ratatoskr-relay.sh` (a user unit) |
| reach a machine's own holder | `bin/bridge/ratatoskr-arm.sh <machine> "…"` |

One answer is handed back: `bin/bridge/ratatoskr.sh reply <id> "…"`, or `answer <id> "…"` to do
both. Every target is written `herdr:<pane>`, `hermes:<session>` or bare — and bare is herdr, so
nothing that worked before changed shape.

And one proof you can run yourself:

```bash
bin/bridge/a2a-talk.sh prove --live <agent-a> <agent-b>
```

## What you need

- herdr (the directory and the panes), `python3`, and the fleet registry for cross-machine rows.
- For Hermes sessions: a configured Hermes profile. Ymir never touches your keys.
- For the arm door: a live arm holder on the machine you write to.

## Do it — one round trip

Ask who is there:

```bash
bin/bridge/ratatoskr.sh who
```

Check the target can take a turn:

```bash
bin/seat/agent-ready.sh herdr:w1:p2
```

Send it work, and let the relay do the rest:

```bash
bin/bridge/ratatoskr.sh send herdr:w1:p2 "summarise the open pull requests"
```

The agent is woken, works, answers with `ratatoskr answer <id> "…"`, and the reply arrives in
**your** pane under `[ratatoskr · from w1:p2 · re <id>]`.

Prove the whole loop with a nonce:

```bash
bin/bridge/a2a-talk.sh prove --live w1:p2 w1:p3 --nonce cafebabe
```

## Limits — the honest ones

- **Handed is not delivered.** A task on a shelf is handed; only a reply makes it delivered
  (RULES/49, 56). The relay never says otherwise, and a miss names the pane and the reason.
- **A paused Hermes session is refused, never replayed.** `blocked: lost turn, run recover` is a
  report for a person; `bin/seat/backend.sh recover hermes:<id>` shows the lost input and
  discards it only with `--yes`.
- **The headless Hermes road is stated, not claimed.** There is no `hermes mcp serve` at v0.22.6;
  the MCP plugin and the API server are the operator's decisions.
- **The relay unit runs from the pinned runtime.** On a seat whose pin predates this code the
  unit is written but will not start; `bin/agents/eir-doctor.sh check` says so in `agentroad`.
- Nothing here opens a port beyond loopback, and a wake never reaches another person's pane
  without a task in their queue.

## If it does not work

- `blocked: trust prompt` — the pane is standing on a harness dialog. Answer it; the relay will
  not type into it.
- `the relay is not seated` / `the relay unit is enabled but FAILED` — from `eir-doctor check
  agentroad`; `bin/engine/units.sh write ratatoskr-relay`, then enable it.
- `dark: the road answered nothing` in `who` — that machine's ssh road failed.
  `bin/fleet/roads.sh check` names which machines answer.
- Nothing comes back — read the relay's misses: `bin/bridge/ratatoskr-relay.sh status`.

## CHANGE LOG

- **2026-11-16** — written with the nine-step build it describes (plan 303 §12.3, §14).
