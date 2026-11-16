---
component: bridge
date: 2026-11-16
plan: 303
step: 5
---

# A task for a machine goes to its one arm holder, or is refused by name

Plan 303 §12.3 step 5, §11.

## Why

The relay wakes a **pane**. A task addressed to a machine has no pane — the machine's one
live arm holder is the agent that answers for it, and that holder is a *session with a
lock*, not something herdr can be told to prompt. Sending such a task to a pane would be
typing into whatever happened to be there; leaving it on the shelf would make it look
delivered.

The house already has exactly one door to a holder per direction: `bin/agents/eindri-notify.sh`
resolves the lock owner's pane and speaks into it here, and `bin/fleet/arm-send.sh` carries a
line to another machine's holder over that machine's own road. This step joins them behind
one verb and adds no second wire, no second lease and no second holder.

## What changed

`bin/bridge/ratatoskr-arm.sh <machine> "<one line>"`:

- **the registry decides what a machine is.** A name the fleet registry does not hold is
  refused, by name, and nothing is handed.
- **here**: `eindri-notify.sh --from ratatoskr` speaks into the holder's own pane. No live
  holder is `REFUSED — nobody holds the arm on <machine>`, exit 1.
- **there**: `arm-send.sh` carries the line over that machine's road and keeps the far
  door's own words — including its `nobody holds the arm on <machine>`, which is passed
  through rather than flattened into a generic failure.
- **it says `handed`, never `delivered`.** The task counts as delivered only when the holder
  drains it and the queue carries an answer (RULES/49, 56).
- `--who` is the holder's roll: `heimdall held`, `a-machine no answer`, per machine.
- the relay routes a task whose target has no pane through this door, and records
  `refused — nobody holds the arm on <machine>` as the miss when it is refused.

**You are never the holder.** A worker does not take the arm, and this door reads the lock;
it never mints one.

## Proof

The registry's refusal, live:

```
$ bin/bridge/ratatoskr-arm.sh a-machine-not-in-the-registry "hello"
ratatoskr-arm: refused — a-machine-not-in-the-registry is not in the fleet registry; nothing was handed
$ echo $?
1
```

The holder's roll, live across the fleet:

```
$ bin/bridge/ratatoskr-arm.sh --who
whynot	no answer	ssh: connect to host … port 22: Connection timed out
a-second-machine	held	  "a worker","counsellor"
a-third-machine	held	  "a worker","claude"
aegir	no answer	ssh: connect to host … port 22: Connection timed out
heimdall	held	  "Hœnir","claude"
```

A machine that answers with a holder says `held`; a machine that does not answer says
`no answer` — those are different claims and the roll never confuses them.

```
$ bash bin/bridge/tests/test_ratatoskr_arm.sh
test_ratatoskr_arm: 11 passed, 0 failed
```

The test proves what a live run cannot: a machine with **no** live holder is refused by name
and nothing is handed, on this machine and on a far one, and the relay turns that refusal
into a miss. The two doors it joins are stubbed, so no real holder is ever spoken to.

**What is not proved live, and why.** The only live holder on this machine is the
Allfather's helm, and a worker must never type into it. So the *delivery* leg — a holder
draining a task and answering — is proved with a stub holder, not by waking the helm. That
is a fence, not a gap: the door that speaks to a holder is `eindri-notify.sh`, already in
daily use, and this step adds no new way to reach one.

## What this does not do

It does not give a second machine's agent a second arm, and it does not let one person's
agent act in another person's pane without a task in that person's queue (§7). It does not
route across owners — that is the hub, §10, not this build.
