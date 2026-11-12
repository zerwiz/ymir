# Gather a batch into one push and one PR

**Date:** 2026-11-12 · **Component:** forge · **Door:** `bin/forge/gather.sh`

## What was wrong

Errands sent out at the same time each pushed their own branch and opened their own PR. Each one raced
`main`, and each one ran the full gates. The only local merge tool, `bin/backend/fm-merge-local.sh`,
fast-forwards one `local-only` task and nothing more. The Allfather asked: *"Do we have a system for this
to be able to use it over and over?"* We did not.

## What changed

`bin/forge/gather.sh <id…> | --finished` makes one integration worktree from fresh `origin/main` through
`yggdrasil.sh`, merges each errand branch (and any helm branch named), stops on a conflict naming the
branch and the files, and resumes with `--continue <batch>`. It runs `.githooks/pre-push` once on the
gathered head, pushes one branch, opens one PR through `pr-open.sh` listing every errand's acclaim, records
the batch in the well, and appends `done: shipped in PR <url>` to each errand's status. `--dry-run` shows
the plan and changes nothing; `--no-pr` stops after the gates.

## Proof

`.agents/tests/gather.test.sh` (28 cases) builds a scratch repository with a bare origin and passes:
dry run, finished detection, one gate run, one push, one PR, a conflict and its resume, a refusing gate,
and a refused unsigned PR.
