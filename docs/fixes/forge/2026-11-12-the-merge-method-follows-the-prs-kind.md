# The merge method follows the PR's kind

**Date:** 2026-11-12 · **Component:** forge · **Door:** `bin/forge/merge-method.sh`

## What was wrong

`bin/forge/ship.sh`, `bin/forge/queue-warden.sh` and `bin/agents/pr-seal.sh` all ran
`gh pr merge --squash --delete-branch`. A gathered batch is many errands' commits on one branch.
Squashing erases each errand's history, and git then reports every errand branch as unmerged, so the
branches had to be swept by content. The Allfather asked: *"why are we always squash merging?"*

## What changed

- `bin/forge/merge-method.sh` holds the one choice. `merge_flag_for <head> <body>` prints `--merge` when the head
  branch is `yggdrasil/gather-*` or `gather/*`, or the body says it was gathered by `bin/forge/gather.sh`.
  Every other PR gets `--squash`. `merge_flag_for_pr <pr> [repo]` asks `gh` for both, and a failed ask falls back
  to `--squash`.
- The three merge tools call it instead of hard-coding the flag.
- `bin/forge/gather.sh` writes "merge with a merge commit, not squash" into the PR body it opens.
- RULES/08's batch-road section names the rule, appended.
- Test: `bin/gates/tests/test_merge_method.sh` (8 cases, `gh` stubbed as a fixture).

## Limits

The squash of an ordinary PR is unchanged. A merge commit needs the repository to allow merge commits; if it
does not, `gh` refuses and the tool reports "not merged" rather than falling back silently.

## CHANGE LOG

- 2026-11-12 — written with the change.
