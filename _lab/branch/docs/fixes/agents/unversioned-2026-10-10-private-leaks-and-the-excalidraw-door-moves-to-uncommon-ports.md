## agents · unversioned · 2026-10-10 — private leaks stopped, the excalidraw door moves to uncommon ports

### What

A batch of small, related corrections carried in the working tree:

- **Generated dispatch briefs no longer risk the public repo.** `bin/backend/fm-brief.sh`
  writes `data/<task-id>/brief.md` under the active firstmate home, and the brief
  **interpolates the machine's real repo path** — so a committed one publishes the
  operator's home, exactly what `private-guard` catches. `.gitignore` now ignores
  `bin/data/`, and the already-committed briefs under `bin/data/` (dag-runes-p1,
  snotra-live-tail, snotra-live-ui) are removed.
- **`.pi/extensions/eindri.ts` and `herdr.ts`** no longer name the operator's real
  home in a comment (Rule 07); the comment now teaches the rule in the public
  placeholder form.
- **The excalidraw door's services move to uncommon ports** (the ports were common,
  and `collab` sat on `3002`): `EXCALIDRAW`/dev `4172 → 7311`, `TTD_BRIDGE`
  `4173 → 7313`, `TICKETS` `4174 → 7314`, `COLLAB` `3002 → 7312`.
- **`compliance-check.sh` and `private-guard-identity.test.sh`** point at the moved
  guard paths (`bin/gates/guards/secret-guard.sh`, `bin/gates/guards/private-guard.sh`)
  after the bin/ move.

### Verified

- `git check-ignore bin/data/x` confirms the briefs are ignored.
- The extensions resolve ports from `process.env.*_PORT || <uncommon default>`, so a
  seat can still override each.
- `compliance-check.sh` resolves the guards at their canonical paths.

### Files

- `.gitignore`
- `bin/data/dag-runes-p1/{brief,context,prompt}.md` (removed)
- `bin/data/snotra-live-tail/brief.md`, `bin/data/snotra-live-ui/brief.md` (removed)
- `.pi/extensions/eindri.ts`, `.pi/extensions/herdr.ts`
- `.pi/extensions/excalidraw/index.ts`, `.pi/extensions/excalidraw/paths.ts`
- `.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh`
- `.agents/tests/private-guard-identity.test.sh`
