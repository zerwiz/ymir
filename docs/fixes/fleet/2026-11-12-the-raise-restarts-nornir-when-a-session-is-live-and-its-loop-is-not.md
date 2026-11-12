## fleet · 2026-11-12 — the raise restarts Nornir when a session is live and its loop is not

### Why
`nornir.service` is a oneshot with `RemainAfterExit`. Its scheduler loop retires when no session lock is held, but the unit stays `active (exited)`. A session that opened later found the unit green and the schedule dead, and `systemctl --user enable --now` does nothing to an active unit. `ymir-autoboot.sh verify` then read "enabled but not active" and Eir's `autoboot` row said "boot gap".

`raise_units` in `bin/fleet/fleet-ensure.sh` now restarts the unit in exactly that case: the unit is active, no loop carries the scheduler mark, and a live session lock exists. Nothing else is restarted, and a seat with no live session is left alone.

### Files
- `bin/fleet/fleet-ensure.sh`

## CHANGE LOG

- **2026-11-12** — Opened.
