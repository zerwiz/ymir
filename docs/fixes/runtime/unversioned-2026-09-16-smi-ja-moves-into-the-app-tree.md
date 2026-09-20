## runtime · unversioned · 2026-09-16 — Smiðja moves into the app tree

### Why
- **The smithy is an app.** Its 148 source files moved from
  `.agents/skills/smidja-factory/` to `apps/smidja-factory/`, joining
  hlidskjalf, odrerir and sessrumnir under `apps/`.
- **Path-transparent.** `.agents/skills/smidja-factory` is now a symlink to
  `../../apps/smidja-factory`, so every existing path resolves unchanged —
  `scripts/start.sh`, `bin/ymir-install.sh`, `bin/ymir-validate.sh`, and the
  skill loader (`.agents/skills` is a skills path). `node_modules/` stays
  gitignored and is not carried.
- **Still open** (recorded, not done): the root `smidja/` runtime tree
  Amendment A would move to `apps/smidja/`, and Amendment C's per-app GitHub
  repos and npm publishing.

### Files
- *(carried from the frozen CHANGELOG.md)*
