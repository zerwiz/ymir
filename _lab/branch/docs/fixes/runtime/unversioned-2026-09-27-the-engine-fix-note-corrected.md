## runtime · unversioned · 2026-09-27 — the engine fix note, corrected (Brokk steer 001)

### Why
The fix note `docs/fixes/runtime/unversioned-2026-09-27-the-engine-seats.md` (this
branch's record for plan 58 Phase 1) reported the indented python heredoc in
`bin/agents/einherjar-spawn.sh`'s `agent_yaml_local_providers` as a wart this errand had
observed and deliberately left alone.

That report was wrong twice over, and a supervisor caught it:

1. **It was already someone's fix.** The heredoc is normalized by PR #215
   (`yggdrasil/model-resolve-indent`). Describing it as an untouched fault in a new
   note invites the next reader to fix it twice.
2. **It is the same file this branch edits.** An engine handoff and a heredoc fix in
   one file must be proven compatible, not assumed compatible.

### What
- The fix note now says the heredoc is **preserved, not touched**: the base tree
  carries it, PR #215 normalizes it, and this branch does not enter that region.
- The compatibility is **proven, not asserted**: `git merge-tree --write-tree
  origin/yggdrasil/model-resolve-indent HEAD` exits 0, and the merged tree carries
  BOTH the column-zero heredoc and the engine handoff (`engine-first (plan 58,
  Phase 1)` present exactly once).
- `src/ymir_runtime/harness.py` resolves harness/model/effort itself, so the bash
  heredoc is not on the engine's road at all; it stays only for the old road until
  the adapter's own resolution retires.

### Files
- `docs/fixes/runtime/unversioned-2026-09-27-the-engine-seats.md` (the corrected entry)
- `docs/fixes/runtime/unversioned-2026-09-27-the-engine-fix-note-corrected.md` (this one)
- `bin/agents/einherjar-spawn.sh` (unchanged in this correction — verified, not edited)
