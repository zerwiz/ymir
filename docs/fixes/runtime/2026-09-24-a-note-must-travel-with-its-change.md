## runtime · 2026-09-24 — a fix note must travel WITH its change, not beside it

### Why
Splitting a fix across two commits — the note first, the code second — produced a pull
request that **claimed a change it did not contain**: PR #184 read as "the ear's unit
template was unreachable" while holding only the fix note, because the code edit had
asserted on a pattern with the wrong indentation and failed silently into the commit.

Two failures, one lesson:

1. **The edit failed and the commit did not.** A `python` edit asserted on a string with
   six-space indentation; the line is indented four. The assertion stopped the edit, but
   the surrounding shell continued and committed the note alone.
2. **The gate then refused the correction.** `bin/fixes-guard.sh` requires the PUSHED RANGE
   to carry a note — the note was already in the previous commit, so the push that carried
   the real one-word change had none. It failed loudly with the remedy, which is exactly
   what a gate should do.

A fix and its note are ONE change: they belong in the same commit, or the first commit
describes work that does not exist yet.

### What
- The real fix (`snotra` added to `PROGRAM_UNIT_SRC` in `bin/fleet-ensure.sh`) and this
  note travel together.
- No code changes beyond that one word.

### Verified
- `PROGRAM_UNIT_SRC snotra` → `tools/mill/systemd/snotra.service`; `bash -n` clean.

### Files
- `bin/fleet-ensure.sh` (the fix, in the same commit as this note)
