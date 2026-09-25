## runtime · unversioned · 2026-09-25 — participation is opt-in: a session must be seated to take the helm

### Why
Plan 58, Phase 0c — the last measured fault. The nine Ymir Pi extensions deploy
**globally** (`~/.pi/agent/extensions/`), so **every** `pi` session on the machine
loads them and resolves the SAME machine lock. Measured live on 2026-09-25:

```
315702  cwd /home/heimdall                YMIR_HOME only   → holds the lock (the primary)
243567  cwd /home/heimdall/CodeP/learnai  YMIR_HOME only   → SAME lock; could reclaim it
3058387 cwd …/smidja-hoard-models         + BROKK_STATE_OVERRIDE → isolated (a real seat)
```

The discriminator was inverted: the seat was isolated, but the **primary and an
unrelated session were indistinguishable** — both carried only `YMIR_HOME`. And
`gna-pi-watch.ts`'s `startArm` **reclaimed** a missing lock with its own pid, so a
plain `pi` in another project could take the helm.

- **A seat marker.** `bin/saga-session-start.sh`, the one place that acquires the
  lock, now records the seated pid in `$STATE/.seated` (resolved through the same
  home as everything else).
- **The gate.** `gna-pi-watch.ts` gains `isSeatedSession()`: on an ownership of
  **missing**, a session reclaims the helm **only** if its own pid (or an
  ancestor) is the recorded seat — otherwise it **stands down**: no reclaim, no
  delete. A session that already owns or reads another's lock is unchanged
  (`owned` proceeds; `other` is read-only). `releaseLockIfOwned` already deletes
  only what it owns.
- **The primary is not stood down:** the primary's lock is `owned` by ancestry, so
  it never reaches the gated branch. The gate closes only the theft window — a
  missing lock and a session that was never seated here.

galdr-reread: `harness-integration/README.md` (the opt-in seat marker).

### Files
- `bin/saga-session-start.sh`
- `.pi/shared/extensions/gna-pi-watch.ts`
- `.agents/skills/galdr-ymirsystem/assets/harness-integration/README.md`
