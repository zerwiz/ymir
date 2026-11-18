## gate · unversioned · 2026-11-18 — a merge is not blamed for main's deletions, and a re-run judges the live PR title

### Why
Two checks were wrong, both measured on PR 819 on 2026-11-18. (1) `no-delete-guard --staged` judged a merge commit against its first parent, so merging `origin/main` into a branch was refused over `.claude/skills`, a path main itself had removed. (2) `pr-identity-guard --ci` read the title and body from the workflow event, and a re-run replays the first event, so a corrected PR title was refused again; only a fresh push re-judged it, costing a 16 to 20 minute gate cycle.

### Files
- `bin/no-delete-guard.sh`
- `bin/gates/guards/pr-identity-guard.sh`
- `.github/workflows/ymir-gates.yml`
- `bin/gates/tests/test_no_delete_merge.sh`
- `docs/fixes/gate/unversioned-two-faulty-checks-no-delete-on-merge-and-title-rerun.md`

### What
During a merge, a file counts as deleted by this commit only if the merged-in parent still has it; a file that side removed is not blamed on the merger. A deletion the merge makes itself is still refused. In CI, `pr-identity-guard` asks `gh pr view` for the live title and body when a token is present and keeps the event as the fallback. The workflow gains `pull-requests: read` and passes `GH_TOKEN` to that one step.

### Verified
`bin/gates/tests/test_no_delete_merge.sh` passes both cases on a scratch repository (main's deletion is clear; the merge's own deletion is refused). `bash -n` is clean on both guards. The CI half is proved by the next re-run of a corrected title, which is not claimed here.

## CHANGE LOG

- **2026-11-18** — opened.
