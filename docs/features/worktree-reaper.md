# The worktree reaper — a closed errand's worktree goes, its branch stays

> **Status:** shipped 2026-11-20 (plan 339.4). The session sweep reaps; `sweep` alone is a dry run.

## What it is

Every errand works in its own git worktree. Before this, nothing removed them: the trees
piled up until the disk was full. The reaper is the other half of the road that made them.

- Every road that makes a worktree **records** it: the path, the repository, the branch, the
  errand, the owner and the road.
- When the errand **closes `done:`** and its work is held elsewhere — merged into the default
  branch, parked on `refs/parked/<errand>`, or pushed to a remote branch — the worktree is removed.
- When it **closes `failed:`**, the worktree is kept **seven days**, then removed.
- **Branches are never deleted.** The work stays reachable after the folder is gone.

## What you need

Nothing for Ymir's own errands: every road records by itself, and the session sweep
(`bin/seat/seat-reap.sh --sweep`, run when a session takes the arm) reaps.

For **another worker system** that fills a folder with linked worktrees, list that folder in
`$YMIR_HOME/config/worktree-roots.yaml`. The shape is `config/worktree-roots.yaml.example`.

## The commands

| Command | What it does |
|---|---|
| `bin/forge/worktree-reap.py sweep` | the **dry run**: every tree with its verdict and why; removes nothing |
| `bin/forge/worktree-reap.py sweep --all` | the same, including open and recordless trees |
| `bin/forge/worktree-reap.py sweep --apply` | removes what the dry run marked `reap:` or `forget` |
| `bin/forge/worktree-reap.py list` | the ledger, as the roads recorded it |
| `bin/forge/worktree-reap.py roots` | the folders it walks, and where each came from |
| `bin/seat/seat-reap.sh --list` | the seat sweep's dry run, with the worktree dry run after it |

## The verdicts

| Verdict | Meaning | On `--apply` |
|---|---|---|
| `reap:done-merged` · `reap:done-parked` · `reap:done-pushed` | closed done, work held elsewhere | removed, branch kept |
| `reap:failed-expired` | closed failed seven or more days ago | removed, branch kept |
| `reap:landed-*` · `reap:idle` | an exterior root's tree whose work is held | removed, branch kept |
| `forget` | the folder is already gone | the record and git's entry are pruned |
| `keep:dirty` | uncommitted changes | **never removed** — named in every sweep |
| `keep:in-use` | an agent stands in it | never touched |
| `keep:done-unlanded` | closed done, but the commits are on no remote | kept — gather or park them |
| `keep:failed-held` | closed failed less than seven days ago | kept, days left shown |
| `keep:open` · `keep:no-record` | the errand is still working, or has no status | kept — an open errand is never guessed closed |

## Limits

- An errand closes when its status file's last line starts `done:` or `failed:`. A worker that
  never writes one keeps its tree until it does.
- A tree a bare shell holds is closed through `seat-reap.sh --shell` first; if the shell will not
  close, the tree stays.
- `YMIR_WORKTREE_REAP=off` turns every `--apply` into a dry run.

## If it does not work

- **A tree you expected gone is still there:** run `bin/forge/worktree-reap.py sweep --all` and
  read its `why` column.
- **An exterior folder is not walked:** `bin/forge/worktree-reap.py roots` shows whether the home
  config was read; a child counts only when it holds a `.git` *file* (a linked worktree).

## CHANGE LOG

- 2026-11-20 — first written.
