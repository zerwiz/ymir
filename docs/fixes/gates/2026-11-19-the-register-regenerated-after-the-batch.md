# The capability register is regenerated after the batch

**Date:** 2026-11-19 · **Component:** gates · **Door:** `bin/gates/capabilities.sh` · **Register:**
`.agents/assets/agents/capabilities.md`

## What was wrong

The `capability` gate on `main` called the register stale after the gathered batch.

## What was forged

The register was regenerated with `bin/gates/capabilities.sh`. Two things changed:

- `.agents/assets/agents/capabilities/seat.md` gains the row for `bin/seat/tests/test_pi_door_path.sh`, which the
  batch added without a row.
- `.agents/assets/agents/capabilities.md` loses a hand-appended `CHANGE LOG` section (a review-mend line for #825).
  The register is a generated file, so its content must equal the generator's output, and a hand-added section makes
  `--check` call it stale. The record of that mend stays in the git history and in the fix notes.

## Proof (measured)

```
bin/gates/capabilities.sh --check
capabilities --check: current (68 door rows)      rc=0
```
