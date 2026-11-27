# The house clock watches the right lock

**Component:** time (plan 369 item 17)

## What was wrong

The Nornir clock kept retiring with "no live session lock", although the helm was alive. The home's
`state/.lock-path` named a scratch lock that nobody held. A run with a private
`BROKK_MACHINE_STATE_DIR` and no state override had written it there. The clock believed the pointer.

A stop left no trace, so other stops could not be told apart.

## What changed

| Part | Change |
|---|---|
| Lock writer (`state/lock.py`) | A private machine dir never writes the home's pointer. A pointer to a live lock is not repointed. Both say so. |
| Clock (`nornir-cron-start.sh`) | A pointer outside the state dir, or with a dead owner, is refused in `cron.log` and `--status`; the primary lock is watched. |
| Stop | While a session holds the lock, a stop needs that session, the unit's own stop, or `--why "<reason>"`. Every stop, refusal and signal is logged. |
| Trouble panel | New `clock` row. `check` starts a stopped clock once and alerts if it does not stay up. |

`scripts/stop.sh` passes its own reason.

## Proof

`bin/time/tests/test_clock_lock.sh` passes in a scratch home (gate `clock-lock`). The real pointer was
read before and after and did not change.

## Not proved

No release flip or helm restart was run against the real clock.

## CHANGE LOG

- 2026-11-25 — review-mend: added missing heading for #953
