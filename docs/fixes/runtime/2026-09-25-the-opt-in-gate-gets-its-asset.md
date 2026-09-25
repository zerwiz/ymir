## runtime · unversioned · 2026-09-25 — the opt-in gate gets its own asset

### Why
The opt-in gate change (`bin/saga-session-start.sh` + `gna-pi-watch.ts`) was
pushed with the harness-integration asset updated, but `saga-session-start.sh`
is governed by **`brokk-distro-runtime.md`**, not the harness asset — and
`compliance-check.sh`'s `assets` row failed on the stale owner. This records the
seat marker and the reclaim gate where the lock itself is documented.

- **`brokk-distro-runtime.md`** §4 (Gleipnir): the lock file bullet now names the
  primary's machine-global path and the `state/.lock-path` pointer; a new bullet
  records that **reclaim is opt-in** — `saga-session-start.sh` writes
  `$STATE/.seated`, and `gna-pi-watch.ts` reclaims a **missing** lock only for a
  session whose pid (or ancestor) is that seat, standing down otherwise.
- **Proved:** `compliance-check.sh` `assets` row PASS again.

galdr-reread: `brokk-distro-runtime.md` §4.

### Files
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md`
