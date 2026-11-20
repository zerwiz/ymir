## skills · unversioned · 2026-09-11 — Galdr/Tyr assets: symlink, not copies

### Why
- **Fix:** `tyr-check/assets` is now a **symlink** to the canonical
  `galdr/assets`, so the two can never drift. A background process had been
  rewriting the registry, flipping the sync gate red; a symlink makes drift
  structurally impossible. Compliance back to 8/8 stable.
- **Verified:** compliance 8/8, smoke 8/8, lint 4/4.

### Files
- *(carried from the frozen CHANGELOG.md)*
