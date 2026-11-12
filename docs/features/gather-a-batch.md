# Gather a batch — many errands, one push, one PR

When you send several Eindri out at the same time, each one commits on its own branch and stops.
Then one command merges all of their branches, runs the gates once, and opens one pull request.
This page explains how to use it. The law is `RULES/08`, in its section appended 2026-11-12.

## What it is

`bin/forge/gather.sh` is the helm's door for a batch of errands. It:

1. makes one integration worktree from a fresh `origin/main`;
2. merges each errand branch into it, in the order you gave;
3. stops on a conflict and tells you the branch and the files;
4. runs the pre-push gates once, on the merged result;
5. pushes one branch and opens one PR that lists every errand and its one-line acclaim;
6. writes the batch to the well, and marks each errand `done: shipped in PR <url>`.

The PR is still the Allfather's to merge. The door never merges into `main`.

## Why use it

One push per errand means every errand races `main` and every errand runs the full gates.
Gathering means one rebase point, one gate run and one review. Everybody still goes through the
gates, because the gates judge the merged result.

## What you need

- The errands were briefed with `--mode batch`, so they commit and do not push:

  ```bash
  bin/agents/erindi-brief.sh <id> <repo> --mode batch
  ```

- Each finished errand acclaimed `committed on eindri/<id> (not pushed): ...`.
- A house and fleet name for the PR signature, from `--house` and `--fleet` or from
  `GATHER_HOUSE` and `GATHER_FLEET`. The door never invents them.

## The commands

| Command | What it does |
|---|---|
| `bin/forge/gather.sh --list-finished` | lists errands that are done and not pushed |
| `bin/forge/gather.sh --finished --dry-run` | shows what it would merge, and changes nothing |
| `bin/forge/gather.sh --finished` | gathers every finished errand into one PR |
| `bin/forge/gather.sh alpha beta hoenir/helm-test` | gathers named errands, plus a helm branch |
| `bin/forge/gather.sh <ids…> --no-pr` | merges and gates, but does not push or open a PR |
| `bin/forge/gather.sh --continue <batch>` | resumes a batch after you resolved a conflict |

A bare name like `alpha` means the branch `eindri/alpha`. A name with a slash is used as it is,
so a helm branch such as `hoenir/helm-test` can ride in the same batch.

## When there is a conflict

The door stops with exit code 3 and prints the branch, the files and the worktree path. Then:

1. go to that worktree and fix the files;
2. run `git add` on them and `git commit --no-edit`;
3. run `bin/forge/gather.sh --continue <batch>`.

The batch name is printed when the batch starts. Each batch's record is kept in
`state/gather/<batch>.manifest`.

## Limits

- Only local branches are gathered. An errand that pushed its own PR is not a batch errand.
- An errand already on `origin/main`, or already marked shipped, is skipped by `--finished`.
- If the gates refuse the merged head, nothing is pushed. Fix it in the worktree, commit, and run
  `--continue`.

## If it does not work

- **"no local branch eindri/<id>"** — the errand did not commit, or used another branch name.
  Check with `git branch --list 'eindri/*'`.
- **"the PR signature needs --house and --fleet"** — pass them, or use `--no-pr`.
- **"nothing to gather"** — no errand is finished and unpushed. Check `--list-finished`.

## Documents need none of this

A push that changes only documents may land on `main` directly. The exact set of files is in
`RULES/08`, and `bin/gates/guards/branch-guard.sh --documents <base> <head>` tells you whether a
range qualifies.
