## gate · unversioned · 2026-10-12 — the inventory's called-by counted the seat too — the correction

### Why
Correction to the note before it: filtering the shelf WALK to tracked files was not enough. analyse() computed each door's called-by by iterating BIN.rglob('*') INSIDE the per-file loop, so the counts still came from the filesystem (untracked scripts included) and still differed from a clean checkout — brokk read 41 locally against 38 clean. The callers are now a TRACKED bin list computed once (BIN_TRACKED), which also removes the walk-per-file. Proven by generating the register both in the working tree and in a clean 'git worktree add --detach' checkout: byte-identical.

### Files
- `bin/gates/inventory.sh`