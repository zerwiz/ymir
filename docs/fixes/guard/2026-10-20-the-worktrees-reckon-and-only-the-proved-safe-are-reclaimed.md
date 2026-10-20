# The worktrees reckon themselves — and only the proved-safe are reclaimed

**Date:** 2026-10-20 · **Component:** `guard` (git hygiene) · **Plan:** 66 §7 neighbour

## The problem, measured

`.yggdrasil/` held **5.9 GB across 55 worktrees**, and the repo **144 local branches** — most
carrying work that had long since landed on `origin/main`. Every one of them costs disk, and the
opposite risk is worse: an over-eager cleanup deletes the one commit that existed nowhere else.

## What landed

`bin/forge/housekeeping.sh` — `report` (default) · `report --json` · `check` · `clean [--yes]`.

Each worktree and branch gets one of five verdicts: `reclaimable:merged`, `reclaimable:pushed`,
`keep:dirty`, `keep:unpushed:N`, or `keep:detached|main` — and `clean` removes only the first
two, **after re-asking each verdict immediately before acting**.

```
report  → "origin/main",56,144,120,7,4     # base, worktrees, branches, reclaimable, unpushed, dirty
check   → exit 1 while any work is unpushed
clean   → a plan; clean --yes reclaims and prints what it refused
```

## The laws it keeps

- `git worktree remove` **without --force** and `git branch -d` (**never -D**): even a bug here
  cannot delete unmerged work.
- the main checkout and `main` are never candidates;
- a dirty tree is never touched, and neither is a branch whose commits exist on no remote;
- the cron row (`@heart 00:45`) is **report-only** — it writes `hodd/memory/worktrees/<date>.md`
  and exits non-zero when work is unpushed. Reclaiming stays a human's `--yes`.

## Verified

```
.agents/tests/housekeeping.test.sh · 12/12, against a FIXTURE repo (bare origin + five states)
  merged → reclaimable and removed · pushed → reclaimable and removed
  dirty → kept and REFUSED · unpushed → kept and REFUSED, branch survives
  check exits 1 while unpushed · clean without --yes removes nothing
```

**Two bugs the fixture caught in the script itself**, both now fixed and commented:
1. the no-upstream branch counted `BASE..HEAD` from the *repo root* (main's commits) instead of
   `-C "$path"` (the worktree's) — it called real local work "0 unique commits";
2. the initial label set had `keep:unmerged`, which is a *different* remedy from `keep:unpushed`;
   a commit on no remote is now always `keep:unpushed:N`, because the remedy is the same — push it.
