# forge · 2026-11-20 — a slimmer worktree leaves a vendored folder out

## Files

- `bin/forge/yggdrasil.sh` — `create` takes `--skip <dir>` (repeatable) and `--slim`
- `bin/forge/tests/test_yggdrasil_slim.sh` — the default is unchanged; skip, slim, and both refusals
- `docs/features/yggdrasil-and-utgard-isolation.md` — the how-to names the two flags

## Why

A repository that tracks a large folder its errands never edit paid for that folder again in every
worktree. Measured on the dev machine on this day: one such repository tracks a vendored `base/` of
22,109 files and about 2.1 GB, and its worktree folder had grown to 7.5 GB. The disk had filled to
100 % two days before, and worktrees were the largest single cost (plan 336, plan 339.4).

## Fix

`yggdrasil.sh create` already writes a per-worktree sparse-checkout to leave `.pi/extensions/` out
(RULES/13). The same mechanism now takes more exclusions, and only when asked:

- `--skip <dir>` leaves one tracked top-level folder out. Repeat it for more.
- `--slim` reads `<repo>/.worktree-slim` (one folder per line, `#` comments) and skips each one.

A skipped folder is checked: it must be a plain relative path (no `..`, not `.git`), and it must be
gone after the checkout. An unsafe name, or `--slim` without the file, refuses and removes the
worktree and branch it had just made. The tree reads clean because sparse-checkout marks the files
skip-worktree; they are still in every commit. Without a flag the output and the layout are the same
as before, which the test proves.

## Not done here

The collaboration kit's own `scripts/worktree.sh` has no such flag yet. The kit was being
rewritten in an open pull request at the time, so the flag was kept to the house's own road.
