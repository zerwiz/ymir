## gate · 2026-11-14 — the branch is brought up to current main

PR #752 (`eindri/safe-send`) was **BEHIND** main. `git merge origin/main` was made into the branch — a merge, never a rebase and
never a force-push — and it merged **cleanly**: no file conflicted, so nothing was resolved and no generated file
(`queue.md`, `INDEX.md`, the woven catalogue) was hand-merged; those are regenerated only by their own doors.

The delivery gate asks every push to carry a note and a bare merge carries none, so this is that record. The merge
commit beside it is the whole change.
