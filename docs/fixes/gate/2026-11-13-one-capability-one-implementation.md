# One capability, one implementation — the ward that keeps a second hearth out

**Date:** 2026-11-13 · **Component:** gate · **Door:** `bin/gates/guards/hearth-guard.sh` · **Plan:** 283

## What it watches

Sessrúmnir carried three hearths — one live, one dead twin one keystroke away, one dark copy of the shared
module — so every repair landed in a file the others did not read. The same night, two extension trees
were byte-identical and both loaded, and no ward noticed: `valknut-load --check` passed while the seat
could not start.

`hearth-guard.sh` fails on exactly two shapes, in the one ward list (`bin/gates/guards.sh`, so pre-push and
CI run the same set):

1. **two hearth components in one app** — the fire is the first capability named; a second implementation
   is a copy, not a feature;
2. **two tracked paths that differ only by case** — one file on a macOS or Windows checkout.

## Proved able to fail

With the deleted twin staged again it printed `"apps/sessrumnir","TWO HEARTHS","2 implementations — keep
ONE file; the rest is a copy every repair misses"` and exited 1. With the twin gone: `"8","0"`, exit 0.

## What it does not see

A copy made at build time (that is a deploy), and an untracked copy (it is not in a push; it is caught the
moment it is staged). Dead files stay `dead-code-guard.sh`'s job — that ward already names three in
bilskirnir, and they were left untouched.

## Files

- `bin/gates/guards/hearth-guard.sh`
- `bin/gates/guards.sh` (one line in the list)

## CHANGE LOG

- **2026-11-13** — written with the ward.
