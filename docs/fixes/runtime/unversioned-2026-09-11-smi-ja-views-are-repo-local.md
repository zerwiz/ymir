## runtime · unversioned · 2026-09-11 — Smiðja views are repo-local

### Why
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

### Files
- *(carried from the frozen CHANGELOG.md)*
