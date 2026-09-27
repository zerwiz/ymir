## install · unversioned · 2026-09-26 — the a2a step's TOON row count 29 → 30

### Why
The `toon` compliance gate (proving every TOON block matches its declared row
count) was red on PR #205's CI: the installation step table's header said
`install[29]` but the block holds **30 rows** — the branch's `a2a` row joined
main's already-merged `mesh` row, and the count was not updated with it.

### What
`installation.md` — `install[29]{...}` → `install[30]{...}`. The header now
names the real count; compliance-check's `toon` row passes (15/15).

### Files
- `.agents/skills/galdr-ymirsystem/assets/installation.md`