## records · 2026-11-14 — the four registries are brought up to current main

### Why

PR #746 (`feat/the-four-registries`) was **BEHIND** main, not conflicted: main moved on while the PR sat open,
so the branch was no longer based on the tree it will merge into.

### What was done

`git merge origin/main` into the branch — a merge, never a rebase and never a force-push. It merged **cleanly**:
no file conflicted, so nothing was resolved and no generated register was hand-merged. The registers are derived
by their own doors (`bin/records/registry-audit.sh`, `bin/gates/registers.sh`) and were left to them.

### What this note is

The delivery gate asks every push to carry a fix note, and a bare merge carries none; this is that record, not a
code change.
