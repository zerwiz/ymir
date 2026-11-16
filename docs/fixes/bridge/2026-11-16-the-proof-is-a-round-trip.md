---
component: bridge
date: 2026-11-16
plan: 303
step: 7
---

# The proof is a round trip, and an unproved hop says so

Plan 303 §12.3 step 7.

## Why

This house called its A2A layer working twice, both times because a **card answered**. A card
answering is not a node answering; a file moving is not a message delivered. The only proof
worth having is a round trip: one line from the operator, through agent A, to agent B, back to
A, and into his pane — with a nonce unchanged at every hop, and nobody typing in between.

## What changed

`bin/bridge/a2a-talk.sh prove` — an action on the door that already proves the channel, not a
second prover — over `bin/bridge/a2a-prove.py`.

Three doors, proved in the order a message travels:

| door | what it proves | how |
|---|---|---|
| `queue` | a task is written, claimed and answered, and the file moves | a real task and a real nonce through `ratatoskr.sh` |
| `relay` | the loop answers and reports what it did | `ratatoskr-relay.sh status` |
| `arm` | a machine name is handed to its holder or refused by name | `ratatoskr-arm.sh` |

`--live A B` adds the round trip through two live agents: a task addressed to A asks it to
forward the nonce to B, and the prover waits for the answer. Every hop is waited for; a hop
that does not arrive is `UNPROVED` with the agent's name and the task id — never a green that
only shows a file moved.

## Proof

```
$ bin/bridge/a2a-talk.sh prove --nonce deadbeef
a2a-prove — one nonce, three doors
nonce: deadbeef
queue: …/state/ratatoskr

proof[3]{door,ok,evidence}:
  "queue","proved","task 1794845064-ybz1ia moved inbox → claimed → done, nonce intact"
  "relay","proved","the relay answers status with its counts"
  "arm","proved","a machine the registry does not know is refused by name"

every door answered, and the nonce came back unchanged.
```

```
$ bash bin/bridge/tests/test_a2a_prove.sh
test_a2a_prove: 14 passed, 0 failed
```

The test proves the half a person cannot see by eye: a door that cannot answer is `FAILED` and
named, a failed proof exits 1, and `--live` against an agent that never answers says `UNPROVED`
with that agent's name instead of reporting success.

## What is not proved here

The live round trip through two agents is **attempted, not assumed**: `--live` prints exactly
what happened, and a run that timed out is recorded as unproved with its task id. The plan's
closing proof (§15.5) is the operator's own run, on two machines, after an install and after an
update; this step gives him the command that proves it, not a claim that it already passed.
