---
component: bridge
date: 2026-11-16
plan: 303
step: 2
---

# The directory is herdr, on every machine — and a machine that does not answer is a row

Plan 303 §5 and §12.3 step 2.

## Why

Discovery in this house was **opt-in**. An agent existed to a peer only after somebody
ran `a2abridge bridge … -directory …` by hand, so in practice nobody existed. The one
peer that had been announced outlived its agent: measured, the directory on this seat
listed `claude-pts/29` from the dead worktree `no-helm-no-errand` — a card answering for
a pane that was gone.

A directory that must be told what is alive rots. A directory that reads what is alive
cannot. herdr already knows every pane and every agent in it, and a dead pane vanishes
from `herdr agent list` by itself, so there is no announce step to forget.

## What changed

`ratatoskr who` (`bin/bridge/ratatoskr.sh who` over `bin/bridge/ratatoskr-who.py`):

- **this machine first** — one `herdr agent list`, and for each pane the state from
  `bin/seat/agent-ready.py`, so the row carries the same four words the ready-check
  answers with, including the reason a blocked pane is blocked.
- **then every machine the fleet registry names** (`hodd/data/fleet.json`), in parallel,
  each over its own ssh road: the remote `herdr agent list` and its arm holder are read
  in ONE round trip, through the `eindri-notify.sh --status` door that already resolves
  the arm rather than a second copy of that logic.
- **a machine that does not answer is a row**: `dark: the road answered nothing`, or the
  reason herdr is absent there. Silence would read as "no agents", which is a different
  and much more dangerous claim.
- **the arm** is marked on the pane that holds it. When the arm pane holds no agent herdr
  lists — measured on one seat, whose arm names `w2:p3` and whose herdr lists no agent
  in it — the directory adds a row naming that, because a wake sent there reaches a shell.
- `--local`, `--machine NAME`, `--no-arm`, `--json`.

herdr's JSON is read from stdout **or** stderr: herdr answers a present agent on stdout
and a missing one on stderr with exit 1, and a reader that watches one stream calls every
empty pane "unsure".

## Proof

```
$ bin/bridge/ratatoskr.sh who
who[28]{machine,harness,pane,name,state,arm,road}:
  "heimdall","claude","w39:p23","Crashed Claude session recovery","working","yes","local"
  "heimdall","claude","w4E:p1","Foreman Elixir pull","ready","no","local"
  "heimdall","claude","w6T:p1","afa-probe-trust2","blocked: trust prompt","no","local"
  "a-third-machine","-","-","-","dead","-","dark: the road answered nothing"
  "a-second-machine","pi","w2:pA","a worker","working","no","tailnet"
  "the-heart","-","w2:p3","(the arm)","dead","yes","the arm pane holds no agent herdr lists"
  "a-second-machine","pi","w3:p2B","a worker","ready","yes","tailnet"
  "a-fourth-machine","-","-","-","dead","-","dark: the road answered nothing"
```

27 rows in 7.1 s wall clock across four machines, two of them dark. The harness named on
every row is herdr's own; the arm is the holder's own pane, resolved by the door that owns
that resolution.

```
$ bash bin/bridge/tests/test_ratatoskr_who.sh
test_ratatoskr_who: 15 passed, 0 failed
```

The test stubs `herdr` and `ssh` on `PATH` and reads a fixture fleet registry, so no real
machine is asked and no live agent is touched.

## What this does not do

It does not send anything (step 3) and it wakes nobody (step 4). Hermes sessions are not
yet rows here — that is 9a, because a Hermes session has no pane and needs the backend
adapter to be addressed at all.
