# CHANGELOG

All significant runtime, policy, and architectural changes for the Ymir platform.
Entries are appended chronologically; never rewritten.

## 2026-09-11 — Smiðja views are repo-local

- **Change:** Removed the last external dependency. `bin/factory-observe.sh`
  (which defaulted to `~/command/factory/factory_data/factory.db`) is gone;
  `bin/smidja-observe.sh` reads the repo's own
  `smidja/smidja_data/smidja.db` read-only and reports absence honestly.
- **API:** `/api/factory` replaced by `/api/smidja/{health,sessions,sessions/:id,decisions,stats}`
  (`bun:sqlite`, read-only).
- **UI:** four Hlidskjalf gates added — Sessions, Trace, Decisions, Stats —
  reading the smithy's trace. No `command`/`factory` references remain in the
  runtime or portal.
- **Verified:** `tsc` + `vite build` green, SPA 200, endpoints honest-absent,
  Galdr compliance 8/8, smoke 8/8.

## 2026-09-11 — Gleipnir lock PID binding fix

- **Problem:** The session lock (`state/.lock`) was written with the digest
  helper's PID (a short-lived child) instead of the live Pi harness PID. The
  harness adapter (`gna-pi-watch.ts`) reported "no live session holds the lock"
  and refused to arm the watcher.
- **Root cause:** `BROKK_SESSION_PID` was never injected into the spawn chain.
  `gleipnir_lock_acquire` fell back to `$$` (helper PID).
- **Fix:** `.pi/extensions/syn-turnend-guard.ts` and
  `.pi/extensions/gna-pi-watch.ts` now pass `BROKK_SESSION_PID: String(process.pid)`
  in the spawn env, so the lock binds to the live Pi process.
- **Impact:** Session lock reclamation works on next Pi session start/reload.
  The stale lock (dead PID) is overwritten by the live PID.
