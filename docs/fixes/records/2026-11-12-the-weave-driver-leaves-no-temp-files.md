# The weave merge driver leaves no `.merge_file_*` behind

When PR #691 merged at 12:07 on 2026-11-12, 18 files named `.merge_file_<random>` appeared at the repo root of the main checkout. Each held a copy of a generated index (a `bin/*/INDEX.md`). Git writes the driver's inputs as such temp files and removes them itself, but only when the driver returns normally. The driver for woven documents runs the inventory scripts, and an interrupted run left the inputs on disk.

## What changed

- `bin/records/regenerate-on-merge.sh` removes the base and theirs inputs on every way out, including a signal. It leaves the output file, which is git's to read. It also sweeps any `.merge_file_??????` orphan older than an hour in the directory it runs in.
- `.gitignore` names `.merge_file_*`, so a stray can never be committed.
- `bin/gates/tests/test_regenerate_on_merge_cleanup.sh` holds both behaviours.

The 18 existing files in the main checkout are untracked and were not touched from this worktree. The helm removes them with `rm -f .merge_file_??????` at the checkout root.

## CHANGE LOG

- **2026-11-12** — Opened.
