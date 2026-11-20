# 2026-09-30 — the elder's sigil doorways in every harness

## What
- Completed the canon: `RULES/02` says harness agent dirs are symlinks to the
  canonical `.agents/agents/`, no mocks — the elder's doorway (`.harness/agents/elder.md`)
  was tracked for the records council but the symlink itself was never committed.
- Added the `elder.md` symlink to all five harness agent dirs: `.claude`, `.codex`,
  `.cursor`, `.opencode`, `.pi`.
- The straggler rode un-shipped on local `main` (commit `7711042`, Sep 24) while
  origin sailed on; this PR ships it, and `main` fast-forwards onto the new origin
  head.

## Verified
- Each `.harness/agents/elder.md` resolves to `.agents/agents/elder.md` (symlink
  targets verified with `readlink`, all five land on the canonical file).
- `git status` clean on the branch apart from the note; `main` clean after the
  fast-forward (0/0 ahead/behind).
- The fixes-guard reads this note (component: agents) in the push range.

## Files
- `.claude/agents/elder.md` → symlink to `.agents/agents/elder.md`
- `.codex/agents/elder.md` → symlink
- `.cursor/agents/elder.md` → symlink
- `.opencode/agents/elder.md` → symlink
- `.pi/agents/elder.md` → symlink
- `docs/fixes/agents/2026-09-30-elder-sigil-doorways.md` — this note