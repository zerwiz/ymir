# 2026-11-01 — the calendar door could not find the gate

**Component:** snotra · **Door:** `systems/snotra/services/calendar/calendar-invite.sh`

## What happened

A meeting was asked for and the door refused: *"the word was not good enough: bash:
/home/heimdall/ymir/systems/bin/time/snotra/snotra-approve.sh: No such file or directory"*.

Two paths were one `..` short after Snotra became a system (plan 129). The script sits at
`systems/snotra/services/calendar/`, so its root is **four** levels up, not three — and the gate it calls had
itself moved from `bin/time/snotra/` to `systems/snotra/services/approve/`.

```
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # → ~/ymir/systems
APPROVE="$ROOT/bin/time/snotra/snotra-approve.sh"               # → does not exist
```

The effect was worse than a broken command: **every invitation and every cancellation with an attendee was
refused**, because the gate check could not run. The door failed safe — nothing was posted and nobody was mailed —
but the capability was dead and the message blamed the approval rather than the path.

## The fix

```
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"          # → ~/ymir
APPROVE="$ROOT/systems/snotra/services/approve/snotra-approve.sh"          # the gate's real home
```

## Proof

The same command that had been refused then created the event and mailed both attendees:

```
created 8gnqs1fc7ik8sto1m0fhcbifs0
meet    https://meet.google.com/ewn-doph-vfd
mail    all
```

Read back through the Calendar API: title *Trello and Control Tower — how we work*, 2026-11-03 09:00–10:00
Europe/Stockholm (08:00Z), status `confirmed`, both attendees `needsAction`, and the approval recorded as
**SENT** — spent by the one post that used it, as the gate requires.

## Owed

A note that the same one-`..`-short pattern may exist in the other Snotra doors that were moved in plan 129: a
door that calls a sibling by path should be checked against the tree it now lives in, not the tree it was written
in.
