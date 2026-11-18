# The arm cannot be held by a watcher, and a tell cannot wait forever

**2026-11-17 · component: runtime · plan 001 §4 F3 (the dead desk), plan 310 (the arms and the crown)**

## What happened

All morning of 2026-11-17 the heart's arm read **held**, with a heartbeat three seconds old, while every
`pi` on that machine was dead. Its own lease says who was holding it:

```
pid=2289 role=unknown session=2286 heartbeat=1794917606 state=/home/example-heart/Documents/ymirhome/state
   2289 /usr/bin/python3 -m ymir_runtime watch run
```

A supervisor with no mind. A tell was handed to that arm and nothing answered — not because the tell was
lost, but because the thing holding the arm has no model heartbeat to answer *with*. The claim looked
alive, so nothing escalated.

## What was forged

**A speech gate at the top of `hold`** in `bin/voice/rodd-arm.sh`. The verdict is the lock module's own:
`ymir-state.sh lock session-pid` walks the process ancestry and returns the live **harness** when one
stands there, and the calling shell when none does. So a caller whose resolved session is its own shell
has no agent in its tree — a watcher, a cron, a `sleep` — and it is refused, with the fact named. One
implementation answers "who can speak" (`src/ymir_runtime/state/lock.py`); the gate only asks it.

The change is **additive** — a block at the top of `cmd_hold` and one extra field in its output row. It is
not a rewrite: another errand (`arms-and-crown`, plan 310) also touches this door.

**`bin/voice/rodd-tell-deadline.sh`** — the second half, a new door rather than a change to `tell`: a
`signal` wake with a `rodd-` key that is still in the queue past its deadline (default 300 s) is
unacknowledged by definition, and it escalates **once** to the operator through `bin/notify/send.sh`. The
key is written to `<state>/.rodd-tell-escalated` so a sweeper that runs every few minutes does not turn
one unanswered tell into a hundred messages. `list` reads and never acts.

## What it proved

```
# a caller with no agent harness — a transient service, the shape of `ymir_runtime watch run`
$ systemd-run --user --wait --pipe --quiet bash -c '… rodd-arm.sh hold'
rodd-arm: the helm is NOT taken: this session cannot speak — no agent harness stands in its process tree
          (the lock resolves it to pid 2141736, a shell whose parent is systemd), and a watcher has no
          model heartbeat to answer a tell with
exit_code=3

# the same door, from a real agent session (the control): it passes the gate and reaches the holder gate
rodd-arm: the helm is held by another live session (pid 450806) — a hold never steals; release it first
```

## The fault this door committed, and the mending

While proving it, `list` was written to run the escalation arm — so merely *listing* expired tells sent
three synthetic HIGH messages to the notifier (keys `rodd-tell:rodd-1794917461`,
`…544`, `…576`, payloads *"somebody to the arm holder: the window is too wide"* and *"hmm"*). `list` now
reads and never acts, and the door takes `YMIR_RODD_ESCALATE_SINK` so a test or a replay can never reach
the operator's phone. A proof that rings the alarm it proves is not a proof.

## What is not closed

The arm **daemon** writes its own lease and does not pass through `hold`, so it is still possible for the
`watch run` service to write `role=unknown` with a shell session. Refusing *that* is the engine's change
(plan 310 §5), not this door's; the deadline escalation is what makes the residue harmless in the meantime.

## Where the proof lives

`bin/seat/tests/test_desk_failsafes.sh` asserts the gate's wording and, on a host with a user manager,
runs the refusal from a transient service.

## CHANGE LOG

- 2026-11-18 — review-mend: added missing heading for #818
