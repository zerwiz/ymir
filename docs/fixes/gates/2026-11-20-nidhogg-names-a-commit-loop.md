# Níðhöggr names a writer that loops on a branch

**Date:** 2026-11-20 · **Component:** gates (`bin/gates/nidhogg.sh`) · **Plan:** 339 (appended 2026-11-20
evening) · **Errand:** `trouble-panel`

## What was wrong

PR #840's branch received ten identical commits (`judge: change-log for #840`) within minutes. The helm's own
push to the branch was refused (*"fetch first"*). Níðhöggr only watched panes, for a repeated command or a
stalled screen. A writer looping on a git branch was a loop he could not see.

## What was built

`nidhogg.sh commits [--repo DIR]… [--window S] [--max N] [--json]` asks the same question of git. It flags one
branch that took the same commit subject more than `--max` times (default 2, `LOOP_COMMIT_MAX`) inside
`--window` seconds (default 3600, `LOOP_COMMIT_WINDOW`).

- It reads local and remote-tracking refs. It never fetches and never writes, and merge commits are not counted.
- One loop carried onto several branches (a gather, the remote copy, `main` after a merge) is **one** row
  naming every branch. Its key is the loop's first commit.
- Exit 3 when a loop is found, the same trip signal `scan` uses.

The trouble panel's `loops` signal carries this verdict and does not judge for itself (`bin/ward/trouble.py`).

## The proof

On the dev machine, live, against the source checkout:

```
$ bin/gates/nidhogg.sh commits --repo <source checkout>
nidhogg-commits[4]{branch,count,subject,repo}:
  "<four branches carrying it>",20,"judge: change-log for #840",…
  "<five branches carrying it>",9,"judge: change-log for #842",…
```

The #842 loop had already reached `main`. `bin/ward/tests/test_trouble.sh` §6 proves three identical
commits trip the default line, and a line of three does not trip on three.

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #874
