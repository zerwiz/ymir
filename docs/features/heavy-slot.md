# The heavy slot — the machine's heavy lanes

The heavy slot is the machine's queue for heavy work — and it is a **counted** queue, not a single seat.
A gate suite, a release build, a dependency install or anything else that eats a gigabyte takes a lane
first; when every lane is held, the next heavy job waits, says whose job it is waiting for, and runs the
moment a lane is free.

How many lanes a machine carries is **the machine's own number**, recorded in its row in the home's fleet
registry (`hosts.<host>.lanes`). A hand-held laptop carries one; the server carries as many as its
operator has measured it can. Nothing about the number is baked into the repository.

## What it is for

The heart is a small server carrying the gate, the board, the documents, the whiteboard, the booking, the
meeting engine, the well and the MCP. It is **not a build server**, and treating it as one is what killed
it twice in one night in November 2026, and again at 07:20 on the 17th. The runbook has said "a heavy job
goes through the slot" since 14 November; the slot is how that is enforced rather than hoped for.

> [!IMPORTANT]
> **One lane is not one builder.** On 18 November 2026 the Allfather corrected the other half of the
> lesson: *"we can only have one builder at the time. here. … the server can handle more builders".* The
> first version of this door was exclusive, so it made "one heavy job" and "one builder" the same
> sentence, and an eight-core machine sat behind a single seat. The lanes are now counted, and how many
> **builders** a machine may hold is a separate number — see `docs/features/builder-budget.md`.

## What you need

- a shell on the machine that is doing the heavy work;
- nothing else. Lane 1's lock lives at `${XDG_STATE_HOME:-$HOME/.local/state}/ymir/heavy-slot.lock`, and
  lane N's is the same name with `.<N>` before `.lock` — so an existing single lock *is* lane 1, and an old
  caller and a new one cannot disagree about where the machine's heavy work is recorded. `YMIR_HEAVY_SLOT`
  points the whole set somewhere else when you need to (a test fence, another user).

## How many lanes

```bash
bin/heavy-slot.sh lanes      # the count, and where it came from
```

The order of resolution: `YMIR_HEAVY_SLOTS` if it is set, then this host's own `lanes` in
`$YMIR_HOME/hodd/data/fleet.json`, then the documented default of **1**. A registry that cannot be read is
not an error — it is one lane, which is the safe floor for any machine.

## The commands

Start a heavy job through the slot rather than beside it:

```bash
bin/heavy-slot.sh run -- bin/gates/ci-verify.sh
bin/heavy-slot.sh run --name "release build" -- bin/engine/release-build.sh HEAD
```

Ask who holds them:

```bash
bin/heavy-slot.sh status
bin/heavy-slot.sh status --json
```

`status` prints every lane — free or held, with the holder's pid, name and how long it has run — and exits
0 when every lane is free and 3 when any is held. `status --json` carries `lanes`, `held`, `state` and
`full`, so a script can ask without parsing prose.

Two flags matter:

- `--no-wait` refuses instead of queueing (exit 3) and names the holders — the right choice for a cron row
  that must not pile up;
- `--wait-max SECONDS` gives up after that long, naming the holders.

The command runs with the hold **inherited**, so a door you call from inside a heavy job (the updater
calling the gate suite, say) nests instead of waiting on your own lock.

## Limits

- **One lane is one heavy job, never one builder.** Builders have their own budget
  (`bin/agents/builder-budget.sh`); a builder that starts a build takes a lane *for the build*, and stands
  in its own seat meanwhile. Raising the lanes does not raise the builder budget, and the other way round.
- **The slot does not police what is heavy.** A door that never asks for the slot still runs. The two heavy
  doors that know it — `bin/engine/update-loop.sh` (its whole pass) and `bin/engine/release-build.sh` — ask
  for it themselves, and this page is the instruction for every other job.
- **The command's exit code is the slot's exit code**, so a wrapper in a timer behaves exactly as the job
  does: `0` proved, anything else failed.
- **A killed holder frees the slot.** The trap fires on `INT`, `TERM`, `HUP` and `QUIT`: the job is stopped
  first, then the lock is given back.
- **A dead holder is reaped, not waited on.** The record carries the process start time beside its pid, so
  a lock left by a process that is gone — even one whose pid has since been reused — is cleared by the
  next job.

## If it does not work

- *The slot says held, and nothing is running.* Ask `bin/heavy-slot.sh status`: if the pid it names is not
  in `ps`, take the slot once by hand (`bin/heavy-slot.sh run -- true`) — it reaps the stale lock. The lock
  file itself is safe to inspect and never needs deleting by hand.
- *A job waited a long time.* The holder is named in the output, with how long it has been running. On the
  heart that is usually the update loop or a release build; the holder's name is the answer to "why is this
  slow", and the slot's whole purpose is that the answer exists.
- *Two machines.* The slot is **per machine and per user** — the fault it stops happens between processes
  on one box. It is not a fleet-wide lock and does not pretend to be.

## CHANGE LOG

- **2026-11-18** — the slot became the machine's **counted lanes**: two lanes on the server, one on a hand,
  read from `hosts.<host>.lanes` in the home registry. Written at the Allfather's word — *"the server can
  handle more builders"* — because the exclusive lock had taught the house to confuse a heavy job with a
  builder.
- **2026-11-17** — the page was written for the change that made it true (plans 001–005, 312).
