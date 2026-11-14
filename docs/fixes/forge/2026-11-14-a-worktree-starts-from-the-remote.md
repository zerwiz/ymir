## forge · 2026-11-14 — a new worktree starts from the remote's tip, never a stale local branch

### Why

Workers seated tonight carried dozens of commits that were not theirs: `yggdrasil.sh create` based every new worktree
on the local `main`, which had drifted from `origin/main` after squash-merged PRs (59 local-only commits). A branch
built on it drags every one of them into its review. `RULES/45` (start on the latest) says otherwise.

### What changed

`bin/forge/yggdrasil.sh create` fetches the base branch and starts from `origin/<branch>` when it exists; an explicit
`--base <ref>` (or a ref with a slash) is honoured as given.

### Proof

`bash -n` passes; a worktree created after the change reports `origin/main` as its base, and
`git rev-list --count origin/main..<new branch>` is 0 before the worker's first commit.
