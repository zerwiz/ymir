## runtime · unversioned · 2026-09-23 — vault shadow, cron leak, standalone drain, stale MCP check

### Why
Four runtime defects the new smoke test (PR #152) and the session exposed:

1. **An empty plaintext shadowed the secrets vault.** `bin/hodd.sh`
   `resolve_secret` accepted `[ -r ]`, so a **0-byte** `hodd/secrets/platform.env`
   won over the 7.6 KB `platform.env.age` — every secret read as absent and
   `emit secrets/platform.env` returned nothing. Now only a **non-empty**
   plaintext wins, so the encrypted vault is used.
2. **The cron loop leaked.** Nornir was started by every session (including
   seats) but nothing retired it when the session ended — **8 orphan loops** from
   ended seats were found running. The scheduler now retires when its state's
   session lock is gone (no lock, or the holder is dead/zombie), mirroring the
   watcher. `bin/nornir-cron-start.sh --stop` still works by hand.
3. **`saga-wake-drain.sh` read the code tree.** Run standalone it resolved
   `$BROKK_HOME/state`, so it reported **"0 pending"** while the hoard queue held
   unhandled wakes. It now resolves the operator's state through
   `bin/hoard-lib.sh`, and gains an **`ack`** action to drop the queues once the
   wakes have been handled (the `WAKE_ACK_REQUIRED` promise had no tool).
4. **Eir's `mcp` surface was stale.** It demanded `a2abridge` in both harness
   configs; the fleet moved to `well/bolthorn/skuld/firecrawl` (Pi) and `engram`
   (OpenCode). It now validates what is actually configured; the real
   connection proof lives in `smoke_test.sh` (PR #152).

### Files
- `bin/hodd.sh`
- `bin/nornir-cron-start.sh`
- `bin/saga-wake-drain.sh`
- `bin/eir-doctor.sh`

### Verified
- `hodd.sh emit` decrypts and emits **74 keys** even with an empty plaintext present.
- The cron loop starts, then **retires** with no live session lock (`cron retired` in the log).
- `saga-wake-drain.sh ack` drops the queue (`0 bytes`).
- `bash -n` clean on all four.
