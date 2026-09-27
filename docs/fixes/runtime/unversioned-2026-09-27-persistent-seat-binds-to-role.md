# runtime · 2026-09-27 — the persistent seat: the heart's scheduler binds to the role, not a session

## Why
`bin/nornir-cron-start.sh` retires its loop the moment the machine's session lock
(`…/ymir/brokk.lock`) is absent or its holder dead — correct for a dev body (it
killed the 2026-09-23 8-orphan-loop leak), but fatal for the **always-on heart**
plan 51 Part 7 moves to the record box: there is no interactive Brokk session
there, so `nornir.service` started `active (exited)` with the loop retired and
**the heart's record crons (observer · briefing · housekeeping · git-sync ·
vault-sync · forgejo) never fired**. Verified live on the old heart: its
`nornir.service` was `active (exited)` with `cron retired - no live session lock`
in its log.

The rejected alternative was a deliberate **fake session lock** (a `sleep
infinity` pid in `brokk.lock`): it satisfies the retire check but would then
**refuse a real Brokk seat** on the heart, because Gleipnir refuses a live,
different owner. Plan 51 Part 7 states the intent plainly: *"the scheduler binds
to the machine's role, not a session."*

## What
- `bin/nornir-cron-start.sh` honours **`BROKK_NORNIR_PERSIST=1`**: the loop skips
  the session-retire check and stays up with no lock until `--stop` or the unit
  stops it. The default is unchanged — every ordinary seat stays session-scoped,
  so the orphan leak cannot return.
- The heart sets it from its unit environment (a `nornir.service.d` drop-in); the
  behaviour is inert elsewhere.

## Files
- `bin/nornir-cron-start.sh`
- `.agents/skills/galdr-ymirsystem/assets/nornir-jobs.md` (§1, the scheduler)

## Verified
- `bash -n bin/nornir-cron-start.sh` — clean.
- On the heart with `BROKK_NORNIR_PERSIST=1` and **no** session lock, the loop
  stays up (`cron: running pid=… jobs=11`) and `bin/ymir-autoboot.sh verify` reads
  `nornir` active.
- Without the flag (a dev seat), the loop still retires on a dead lock.
