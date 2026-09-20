## sessrumnir · unversioned · 2026-09-16 — the visualizer finds its DB, and the seat-hall actually builds

### Why
Two more readers left behind — both discovered by *starting the apps*, not by any
gate. Each failed silently in its own way.

- **`scripts/start.sh` pointed the smithy at a repo path that no longer holds the
  DB.** `0003-private-data-separation` moved it to `$YMIR_HOME/smidja/smidja.db`,
  but the starter still passed `CMD_DB=<repo>/apps/smidja/smidja_data/smidja.db`
  — so the visualizer API died on boot with `smidja.db not found` and `:8437`
  answered nothing. It now resolves the same pair `bin/smidja-bootstrap.sh` does
  (home first, in-repo fallback, `SMIDJA_DB` override). The asset already
  *described* this resolution; the code now implements it.
- **`bin/sessrumnir-ensure.sh` never built the app.** `[ "$built_present" ]` tests
  a **literal, non-empty string** — always true — so `ensure --install` skipped
  `build_app` and reported `built: no` with exit 0. Sessrúmnir only built when the
  build was run by hand. Now `built_present` (the function) is called.
- `galdr-reread`: `.agents/skills/galdr-ymirsystem/assets/smidja.md` — the DB
  path, the `scripts/start.sh` DB resolution, and the observer's read list.

### Files
- *(carried from the frozen CHANGELOG.md)*
