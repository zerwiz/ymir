# runtime · 2026-11-12 · Nobody synced the home, and nobody updated on a merge

## What

The Allfather asked two questions that should have had a one-word answer each:

*"are we pulling and pushing ymir home on updates in it?"* — **No.** `nornir-job-git-sync.sh` runs at 00:00 in
**fetch** mode only. The home's local commits never left this machine, so the tree fell fifty to eighty commits
behind the heart every day, and every reconciliation was a hand at one in the morning, racing another seat.

*"are we updating ymir on merges?"* — **No.** `bin/engine/update-loop.sh` had an `install` verb that printed
`installed (dry-run not implemented fully)` and wrote **nothing**. A door that reports success and does nothing
is the fault this house keeps paying for.

## Why

Both were written as doors and never given a clock. The house has a habit of building the mechanism and leaving
the wiring to "whoever remembers", and the cost is a night's work done by hand every night.

## The fix

1. **`bin/engine/update-loop.sh install`** now writes `ymir-update-loop.service` + `.timer`, enables, starts and
   reports their state. Seated: every 15 minutes, and it ran within the minute.
2. **`bin/vault/home-sync-clock.sh`** — the home's own clock, hourly: fetch, commit ONLY the records the house
   writes itself (the runes, the room files, the daily log — append-only unions, never scratch), pull with a
   union merge, and push if clean and ahead. A dirty tree is HELD and named, never swept. `--install-timer`
   seats it; it is active.

## Proof

```
$ bash bin/vault/home-sync-clock.sh
home-sync-clock,pulled=23,pushed=4,left=0
$ systemctl --user is-active home-sync-clock.timer ymir-update-loop.timer
active
active
```

## Change log

- **2026-11-12** — written with both clocks, after the question was asked twice.
