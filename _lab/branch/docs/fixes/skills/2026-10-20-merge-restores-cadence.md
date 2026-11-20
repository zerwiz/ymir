## skills · unversioned · 2026-10-20 — the merge restores cadence and open floor

### What

The merge of `main` into `feat/meeting-outcomes` resolved the schema conflict with main's
version and the script conflict with the branch version. The first resolution took main's
script, which does not yet carry `_cadence()` or the open-floor section. This commit
restores both from the branch commit that introduced them, so #371 carries the cadence,
the everyone line and the open floor.

### Verified

- `_cadence()` and `## 5. Open floor` are present.
- Python parses; schema JSON parses.

### Not verified

- A full render in this worktree; no real transcript is used.
