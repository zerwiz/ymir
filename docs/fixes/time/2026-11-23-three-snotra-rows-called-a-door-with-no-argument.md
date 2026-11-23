# Three Snotra rows called a door with no argument

**Component:** time (the cron ledger) · **Date:** 2026-11-23

## What was wrong

`config/cron.yaml.example` carried three rows that invoke a Snotra door with a positional
argument the row never passes:

```
@dev 17:00 systems/snotra/services/cron/snotra-friday-synch.sh run
@dev 09:00 systems/snotra/services/cron/snotra-grooming.sh run
@dev 10:00 systems/snotra/services/cron/snotra-card-moves.sh watch
```

Each door takes a meeting directory, or a board name, as its second word. Called with the
verb alone, each prints its own usage block and exits **2**, so every working day produced
three HIGH cron failures on any seat that inherits the example:

```
snotra-grooming.sh run       rc=2
snotra-card-moves.sh watch   rc=2
snotra-friday-synch.sh run   rc=2
```

Measured on a dev seat, 2026-11-23, exactly as above.

## What it is now

The three rows call the guarded composite that already exists for this work,
`systems/snotra/services/cron/snotra-cron.sh <verb>`:

```
@dev 17:00 systems/snotra/services/cron/snotra-cron.sh friday-synch
@dev 09:00 systems/snotra/services/cron/snotra-cron.sh grooming
@dev 10:00 systems/snotra/services/cron/snotra-cron.sh card-moves
```

The composite resolves the meeting directory (`meetings | head -1`), **skips cleanly when
there is none** (`no meetings`, exit 0 — RULES/25: a clean skip is a pass), and dispatches
the same verbs. The doors keep their usage refusal, which is right: a door told nothing
should say so.

## How it was proved

- The three doors, called as the old rows called them, exit `2` and print usage (above).
- `snotra-cron.sh`'s own dispatch accepts `friday-synch`, `grooming` and `card-moves`, and
  every verb that needs a meeting iterates `meetings` with an emptiness guard.
- The example is the fallback the cron runner reads when the home has no row for a job
  (`bin/time/nornir-cron-start.sh`), so fixing the example fixes it for every seat that
  inherits it, not only this one.

## What is not fixed here

The two mail rows (`bin/time/nornir-job-gna-mail.sh`, `bin/time/nornir-job-snotra-mail.sh`)
fail with `rc=3` on a seat whose warden entry reads `enabled: off`. That is a **different
fault**: a door deliberately switched off is being reported as a failure instead of a named
skip. It needs its own change in the warden contract, and is not touched here.

## CHANGE LOG

- 2026-11-23 — review-mend: added missing heading for #916
