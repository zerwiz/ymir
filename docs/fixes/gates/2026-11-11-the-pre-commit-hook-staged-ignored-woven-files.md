# gates · 2026-11-11 — the pre-commit hook aborted every commit that touched the feature catalogue

## File
- `bin/gates/guards/secret-guard.sh` — the pre-commit hook it installs (`--install`)

## What was wrong
The hook weaves the woven documents and stages the ones that changed. Plan 243 took `FEATURES.md` and
`bin/README.md` out of git (they are built where they are read, and ignored), but the hook still ran
`git add -- FEATURES.md`. Git refuses an ignored path, the hook exited 1, and the commit was abandoned with only
git's "paths are ignored" hint on screen — so a scripted `git commit -q` failed silently and pushed an empty branch.

## Fix
A woven file that git ignores is written and not staged (`git check-ignore -q` before `git add`). The hook was
re-seated with `bin/gates/guards/secret-guard.sh --install`.

## Proof
Before: committing the letter-design change printed the ignored-path hint and left `git log` unchanged. After the
fix and the re-seat: the same commit lands.

## CHANGE LOG

- **2026-11-11** — written with the change (nidavellir, plan 250).
- **2026-11-11** — the same branch also widened `rules-compliance-guard.sh`'s template exemption (`is_shape`) to
  `systems/snotra/services/letters/templates/*`: a letter template is a shape mailed to a reader, exactly like
  `.agents/templates/*`, so a CHANGE LOG inside it would be mailed too.
