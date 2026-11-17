# The heavy lock the runbook named did not exist — now it does, and the updater holds it

**Date:** 2026-11-17 · **Component:** engine (`bin/heavy-slot.sh`, `bin/engine/update-loop.sh`,
`bin/engine/release-build.sh`) · **Errand:** `heart-update-loop` (plan 002 §6.1 and §8)

## What was wrong

`updating.md`'s first law, written after the two out-of-memory deaths of 2026-11-14, said:

> **one heavy job at a time** — `bin/heavy-slot.sh take` before a build, a type-check, an install or a
> second copy of a service — the second job waits, it does not proceed

Measured on the heart on 2026-11-17: **that file did not exist anywhere in the tree.** A law with no
mechanism is a hope. So a gate suite (6 m 06 s of CPU per pass), a release build and seven errands could
all proceed at once on a box with 11 GB of RAM and 3.0 of 4.0 GB of swap already in use. At 07:20:59 the
kernel fired, the OOM killer took a process inside `herdr-server.service`, and the restart re-created 27
panes as bare shells.

Two doors were also outside any queue of their own: the update loop proved a candidate every fifteen
minutes, and `bin/engine/release-build.sh` — an `npm` install plus three SPA builds — could be started by
hand beside it.

## What was built

`bin/heavy-slot.sh` is the mechanism, and it is one file with two verbs:

| verb | what it does |
|---|---|
| `run -- <command…>` | takes the machine's heavy lock, prints whose job it waits for when the slot is held, runs the command with the hold **inherited**, releases on exit **including on a signal** |
| `status` | who holds it, since when, what for — or that it is free |

The record is a lock file carrying `pid`, `starttime`, `started`, `host`, `name` and `cmd`, created by
writing a temporary file and **linking** it into place — `ln` fails when the target exists, so no reader
ever sees an empty lock and no two takers can both win.

The three things it must never do, each proved by a test:

1. **Leave a lock behind.** A holder that is gone is *reaped*. The record carries the process **start
   time** beside the pid, because a pid is reused: a lock whose pid now belongs to another process is
   stale, and treating it as held would block the machine forever on a coincidence.
2. **Run a second heavy job beside the first.** `run` holds the slot for the whole life of the command.
   A hold is inherited (`YMIR_HEAVY_SLOT_HELD`), so a heavy door called *from inside* a heavy job nests
   instead of deadlocking on its own lock.
3. **Release someone else's lock.** The release is guarded by pid and start time, and the trap fires on
   `EXIT` and on `INT`/`TERM`/`HUP`/`QUIT` alike.

Two heavy doors now take it themselves rather than trusting the caller to remember:

- `bin/engine/update-loop.sh` re-execs under `bin/heavy-slot.sh run --name ymir-update-loop` for every
  heavy verb (`run`, `prove`), so the whole pass — build, prove, mend, witness — is one heavy job;
- `bin/engine/release-build.sh` takes it for any standalone build.

## The proof

Two heavy jobs started at once, on this machine, 2026-11-17 12:23Z. The second prints the holder and
waits:

```
$ bin/heavy-slot.sh run --name 'job-a (the gate suite)' -- sh -c 'sleep 6; echo "A: heavy work done"' &
$ bin/heavy-slot.sh run --name 'job-b (an errand test run)' -- sh -c 'echo "B: ran only after A"'
SLOT,waiting,held
holder[1]{pid,started,starttime,host,name,cmd,running}:
  "826787","2026-11-17T12:23:02Z","560102","example-seat","job-a (the gate suite)","sh -c sleep 6; echo "A: heavy work done"","00:01"
detail,waiting for,job-b (an errand test run) waits for the job above; it runs the moment the slot is free
slot[1]{lock,state,pid,name,waited}:
  "/home/example-seat/.local/state/ymir/heavy-slot.lock","held","828254","job-b (an errand test run)","5s"
B: ran only after A
```

The full test is `bin/engine/tests/test_heavy_slot.sh` (gate `heavy-slot`, 15 assertions): a free slot
says free · a run gives the slot back · the second job prints the holder and does not start beside the
first, then runs after it · `--no-wait` refuses (exit 3) and names the holder · a lock whose holder is
gone is reaped · a lock whose **pid was reused** is reaped · a holder killed by `TERM` gives the slot
back · a heavy job inside a heavy job nests · `status --json` answers a machine.

```
heavy-slot: 15 passed, 0 failed
```

## What this does not decide

Which jobs *are* heavy is a judgement, so the slot does not police it: a door that does not ask for the
slot still runs. Every heavy door in this tree that knows it is heavy now asks — the update loop, the
release build — and the runbook tells a person to start anything heavy through it. Whether the gate suite
itself should take the slot on every machine is a decision the Allfather has not made, and on CI runners
it would serialise a suite that is already alone.
