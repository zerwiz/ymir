# Revert: the public-surfaces change in Hlidskjalf

**Date:** 2026-11-22 · **Component:** hlidskjalf (`metadata.ts`, `main.cjs`) ·
**Errand:** `revert-hlidskjalf-surfaces`

## What was reverted

At the operator's word — *"All you did. Revert"* — the two Hlidskjalf files changed by
`surfaces-from-the-home` (PR #850) are restored to their state before that PR:

- `apps/hlidskjalf/src/data/metadata.ts` — the public hall URL is spelled again
- `apps/hlidskjalf/electron/main.cjs` — the comment names a host again

## Why

The operator said the Hlidskjalf changes are Heimdall's to make, not the heart's. The reader
(`bin/gimle/surfaces.py`) and its gate remain, so any other code that wants to use them may.

## CHANGE LOG

- 2026-11-22 — reverted at the operator's word.
