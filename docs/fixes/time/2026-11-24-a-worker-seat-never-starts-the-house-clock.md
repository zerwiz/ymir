# A worker seat never starts or stops the house clock

Date: 2026-11-24 · Component: time (Nornir) and seat

## What was wrong

A herdr worker seat is created with `BROKK_MACHINE_STATE_DIR` and `BROKK_STATE_OVERRIDE` set to one private directory, so it never takes the helm's lock. Its Claude session hook still called `bin/time/nornir-cron-start.sh`. The scheduler it started bound to the seat's lock directory, found no `brokk.lock`, and retired. On the dev machine every `@dev` job missed its run that day. The log also showed `today: unbound variable` and a write into a missing directory.

## What changed

- `nornir-cron-start.sh` refuses to start or stop the clock from a worker seat. A seat is a private machine dir that is also its own state dir and is not the helm's. It prints one named line and exits 0. `--status` and `--last` stay readable.
- A `BROKK_MACHINE_STATE_DIR` that does not exist is refused with its reason, rather than starting a clock that retires.
- The scheduler sets `today` at the top of every pass, so the retirement path no longer hits an unset variable, and it creates its state dir before writing `.cron-retired`.
- `bin/seat/herdr-run.sh` creates the seat's private state dir before the pane is made.

## Proof

`bash .agents/tests/nornir-seat-guard.test.sh`. The test uses a fake root with a stub notify sink, so it cannot page anyone.
