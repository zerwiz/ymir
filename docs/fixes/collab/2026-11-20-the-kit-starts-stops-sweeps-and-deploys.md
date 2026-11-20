# The kit starts, stops, sweeps and deploys a task — and switches development stacks off

**2026-11-20 · component: collab**

## What was wrong

The kit closed worktrees, but a task left more than a folder: a dev server still listening, a test database, a
development stack running all night beside the ones in production, and release images nobody removed. On one
machine the container storage had to be deleted during the cleanup, and podman then failed to start because its
configured driver did not match the filesystem. The operator's words: *"we should not have 1000 containers; only
the ones in prod need to be up all the time; we need to be able to turn it off when we're not developing."*

## What was forged

| Door | What it does |
|---|---|
| `scripts/work.sh start` | refuses under the disk floor or over the leftover budget and prints what to clean; fetch --prune; worktree from `origin/<default>`; record; dev stack on |
| `scripts/work.sh stop` | checks, commit, push, pull request; stops the tracked processes, ports and test databases; merged → everything removed, else "waiting for merge" with an expiry |
| `scripts/work.sh sweep` | the daily cleanup and the session start: close, salvage, prune, dev stacks off, doctor |
| `scripts/stack.sh` | `status`, `on`, `off` per app from the machine's `~/.config/collab-kit/stacks.yaml`; `prod` is never stopped and naming one is refused; `unknown` is never touched |
| `scripts/deploy.sh` | the storage driver chosen by filesystem and said aloud; disk floor; one-builder lock; labelled build; ship; the project's hook; two tags kept; rollback printed on failure |
| `docs/how-we-work.md` | the one page |

## What was run

```
python3 bin/collab/tests/test_work.py   → Ran 12 tests … OK
  start refused at low disk · start turns the dev stack on, never a prod piece · stop after merge removes the
  worktree, branch, caches and the tracked process · stop not merged waits with an expiry · sweep closes and
  reports · off refuses a prod piece · off then on restores the dev stack healthy · deploy keeps exactly two
  tags · a failed hook keeps the previous release and prints the rollback · btrfs picks the btrfs driver
bash bin/collab/tests/test_collab.sh    → every case passed
```

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #841
