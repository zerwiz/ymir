# The door that removed nothing — two faults in `housekeeping.sh clean --yes`

**2026-10-24.** Component: `bin/forge/housekeeping.sh`.

## What happened

The tool reported **117 reclaimable** of 59 worktrees and 174 branches, and `clean --yes` removed **37 branches and
zero worktrees** — twice in a row — while `.yggdrasil` stayed at **6.5 GB**. The disk never moved because no
worktree was ever removed.

## Fault 1 — two of the four verdicts were silently skipped

Both the worktree loop and the branch loop accepted only two verdicts:

```bash
case "$v" in
  reclaimable:merged) ;;
  reclaimable:pushed) [ "$MERGED_ONLY" = 1 ] && continue ;;
  *) continue ;;
esac
```

`reclaimable:upstream` and `reclaimable:content-in-main` — the two that describe most of this shelf's history
(rebase and cherry-pick merges leave different SHAs for identical content) — fell into `*) continue`. So the run
reported "removed 0" while its own report still said 117 reclaimable.

## Fault 2 — the path field is not always absolute

```bash
full="$_abs"
[ -d "$full" ] || continue        # skips every worktree printed by its short name
```

The report prints some worktrees with an absolute path and others as a bare name under `.yggdrasil`. The loop
therefore skipped every short one — including the large ones.

## How the reclaim was actually done

By an explicit, auditable loop with four guards, each of which the tool should carry:

1. never the primary checkout;
2. never a worktree with a live process (checked by `/proc/<pid>/cwd`);
3. never a branch that is not already tagged on `origin` (`archive-2026-10-24/*`, 174 tags) **and** covered by a
   verified `git bundle --all`;
4. `git worktree remove` **without** `--force`, so a dirty worktree refuses itself.

Result: **59 → 21 worktrees, 174 → 112 branches, 6.5 GB → 4.5 GB**. The four remaining giants
(`smidja-hoard-models` 695 MB, `main-green` 655 MB, `phase5-remainder` 635 MB, `review-230` 634 MB) hold
uncommitted work and refused themselves — correctly.

## The fix owed

Make the two loops accept `reclaimable:*` and resolve `full` through `$WT_ROOT` when the path is not absolute —
then prove it by removing a known-reclaimable worktree through the door, not by hand. Until that proof exists, this
note is the record that the door does not reclaim, and the work is done by the documented loop above.
