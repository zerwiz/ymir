# pr-open keeps a plain merge-commit banner as the first line

**Date:** 2026-11-12 · **Component:** gates · **Follows:** `2026-11-12-the-maker-name-ward.md`

## What was wrong

`bin/forge/pr-open.sh` lifted only a body that opened with the upper-case batch banner above the signature block. A
single errand that opens its body with the plain sentence "Merge with a merge commit, not squash." had the signature
placed above it, so the reader's first line was not the warning.

## What changed

The banner case now also matches the plain sentence, so either form stays the first line of the pull request.

## CHANGE LOG

- **2026-11-12** — written with the change; no other behaviour moved.
