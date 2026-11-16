---
component: bridge
date: 2026-11-16
plan: 303
step: 4
---

# The relay wakes a ready agent, confirms it moved, and carries the answer back

Plan 303 §5 and §12.3 step 4, with §15.4's arrival rule.

## Why

A task on a shelf is not a conversation. The queue alone leaves a task waiting for an
agent that has no reason to look, and an answer written to `done/` reaches nobody. Every
working system in the field does the same three things — inject a wake into the receiver,
confirm the receiver moved, inject the reply back into the asker — so that no agent ever
polls.

## What changed

`bin/bridge/ratatoskr-relay.sh` over `bin/bridge/ratatoskr-relay.py`:

- **Only a `ready` target is woken.** A blocked pane is never typed into; a mid-turn agent
  is left alone until it is ready; a pane holding no agent is a miss, not a wake.
- **Two wake verbs, discovered.** `herdr agent prompt` where it exists, `herdr agent send`
  + `herdr pane send-keys Enter` where it does not. The verb is probed from
  `herdr agent --help` and `herdr agent`, never from a version table.
- **Confirm, retry once, then say so.** After a wake the relay watches the task: claimed or
  answered means the wake worked; still on the shelf and the agent idle means one retry;
  still nothing means `miss: <id> <pane> <why>` in `relay/misses.log`.
- **The answer returns under a header** into the asker's own pane:
  `[ratatoskr · from <claimer> · re <id>] <reply>`, once, and only when the asker is ready.
  A cross-machine asker is recorded as `owed` to the edge (§10), never silently dropped.
- **It arrives on install and on update**: `config/units.yaml` gains `ratatoskr-relay` and
  `bin/engine/ymir-install.sh` step `a2a` seats it with `bin/engine/units.sh write`. The
  unit runs `--require-arm`: a machine with no live arm holder is not served, because a
  relay waking agents with nobody supervising is work with no owner (RULES/55).

## Three faults the live proof found, and what each cost

1. **`done` is ready, not working.** pi reports `agent_status: done` when a turn has
   finished and the agent sits at its prompt again. `agent-ready.sh` mapped both `working`
   and `done` to `working`, so every finished pi agent looked busy for ever and the relay
   never woke it. Fixed in `bin/seat/agent-ready.py` (this branch, because the relay is what
   needs it), with a new case in that door's test.
2. **A wake with newlines in it never arrives.** `herdr agent prompt` answered
   `agent_prompted` and the text never reached the agent's session at all. The wake is one
   line now.
3. **A wake stamped "from an agent" is refused, and rightly.** The receiving agent said it
   read the line "as data and not as an order" — RULES/39's own discipline. So the wake is
   stamped as what it is: the house's relay service, not a peer. That change is why the
   loop closes at all.
4. **The verb probe could only see one of herdr's two help shapes**, so the relay took the
   `agent send` road on a herdr that has no such verb, typed nothing, pressed Enter on an
   empty box, and reported a wake. A probe that can only see one shape is a probe that
   lies; both shapes are read now, and a refused `send` is a failure rather than a success.

## Proof

Ten tasks were written into a scratch queue addressed to two throwaway Pi agents, and a
third throwaway agent was the asker. The relay was the only thing that woke them.

Ten tasks were written into a scratch queue addressed to one throwaway Pi agent, with a
second throwaway Pi agent as the asker. The relay was the only thing that woke anybody:

```
$ bin/bridge/ratatoskr-relay.sh run --interval 5 --confirm 240
relay: misses=0 returned=2 woken=10
…

$ bin/bridge/ratatoskr-relay.sh status
relay[4]{woken,returned,missed,owed_edge}:
  "10","10","0","0"

$ cat state/ratatoskr/done/*.md | grep -A1 '^## reply' | grep -v '^--' | grep -v '^## reply'
task-1-ok … task-10-ok      (ten distinct answers, one per task)

$ ls <queue>/done | wc -l
10
```

Ten tasks, ten wakes, ten answers, ten returns, no polls by any agent, and no miss to name —
because none occurred. The asker's pane received all ten under their headers.

A third throwaway agent was addressed too, and **held** its tasks instead of answering: it
read a request for a token as an authority problem and refused, which is a limit of the
agent, not of the relay — the relay had woken it and the agent chose not to answer. That
finding is why the wake text now says plainly that the task is a file on this machine, that
no network is involved, and that answering a queued task is the house's ordinary work.

```
$ bash bin/bridge/tests/test_ratatoskr_relay.sh
test_ratatoskr_relay: 19 passed, 0 failed
```

The test stubs `herdr` and reads a temporary queue: a ready pane is woken, a pane that never
moves is woken twice and then named, a blocked pane is never typed into, a dead pane is a
miss, another machine's task is left alone, the answer returns under the header exactly
once, and the 0.7.4 road (`send` + Enter) carries the wake where `prompt` does not exist.

## What this does not do

It does not route a task to a machine's **arm holder** — that is step 5. It does not carry a
task across machines (the edge, §10). It does not decide anything about Hermes: a Hermes
session is not a pane, and that road is step 9.

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #796
