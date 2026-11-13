## vault · 2026-11-13 — the home's clock commits the comms logs, so one Telegram line no longer holds it

### What

`bin/vault/home-sync-clock.sh` commits the records the house writes itself (the runes ledger, the room files, the
daily logs) and then pulls and pushes. Any other dirty tracked file holds it, by design: a scratch file must never
travel.

`hodd/memory/comms/*.jsonl` (the Telegram log and its kin) was not on that list. The house appends to it on every
outgoing message, so it was nearly always dirty, and it held the clock every hour. On 2026-11-13 the home on a dev seat
was four commits behind the heart. A plan number was refused as stale, and `home-sync.sh ship` failed because the
dirty runes ledger overlapped the incoming change.

The comms logs merge by union (`hodd/memory/**/*.jsonl merge=union` in the home's `.gitattributes`), exactly like the
runes, so they join the record list. The list is now one `RECORDS` pattern used by both greps, so the two cannot drift.

### Verified

- `bin/gates/tests/test_home_sync_clock.sh` — a throwaway home and remote: dirty runes and a dirty comms log are
  committed and pushed with a clean tree after; a dirty scratch file holds the clock with exit 3 and commits nothing.
  5 of 5 pass; against the old clock, 2 of those fail.

### Not done

Nothing in install or update seats the clock's timer (`--install-timer`); the same holds for the other hourly watchers
in `bin/forge/`. That is its own change.
