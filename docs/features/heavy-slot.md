# The heavy slot — one heavy job at a time

The heavy slot is the machine's one queue for heavy work. A gate suite, a release build, a dependency
install or anything else that eats a gigabyte takes the slot first; a second heavy job waits, says whose
job it is waiting for, and runs the moment the slot is free. Nothing heavy ever runs beside the updater.

## What it is for

The heart is a small server carrying the gate, the board, the documents, the whiteboard, the booking, the
meeting engine, the well and the MCP. It is **not a build server**, and treating it as one is what killed
it twice in one night in November 2026, and again at 07:20 on the 17th. The runbook has said "one heavy job
at a time" since 14 November; the slot is how that is enforced rather than hoped for.

## What you need

- a shell on the machine that is doing the heavy work;
- nothing else. The lock lives at `${XDG_STATE_HOME:-$HOME/.local/state}/ymir/heavy-slot.lock`, and
  `YMIR_HEAVY_SLOT` points it somewhere else when you need to (a test fence, another user).

## The commands

Start a heavy job through the slot rather than beside it:

```bash
bin/heavy-slot.sh run -- bin/gates/ci-verify.sh
bin/heavy-slot.sh run --name "release build" -- bin/engine/release-build.sh HEAD
```

Ask who holds it:

```bash
bin/heavy-slot.sh status
bin/heavy-slot.sh status --json
```

`status` exits 0 when the slot is free and 3 when it is held, so a script can ask without parsing prose.

Two flags matter:

- `--no-wait` refuses instead of queueing (exit 3) and names the holder — the right choice for a cron row
  that must not pile up;
- `--wait-max SECONDS` gives up after that long, naming the holder.

The command runs with the hold **inherited**, so a door you call from inside a heavy job (the updater
calling the gate suite, say) nests instead of waiting on your own lock.

## Limits

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
