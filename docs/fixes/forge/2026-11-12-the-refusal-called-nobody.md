# forge · 2026-11-12 · The refusal called nobody

## What

`bin/forge/review-mend.sh` was built to turn a refusal into work. It printed:

```
next: fixer:review-mend-<pr>
brief: bin/agents/erindi-brief.sh -> state/eindri-reports/pr-<pr>.md
```

— and stopped. **It named a fixer and seated no one.** A REFUSE therefore sat until a hand noticed, which is
precisely the fault the door existed to end.

The Allfather, after the tenth time: *"why dont he call anyone to resolve the problems.. we have said this sooo
many things now. its becomming pretty enoying."*

## Why

The door was written for the *judge*, whose hands stop at the record, and the seating of a worker was left to
"whoever drains the queue". That is a promise, not a mechanism — and a promise is the thing this house keeps
replacing with a door.

## The fix

On a refusal the door now **seats the fixer**:

1. scaffolds the errand (`bin/agents/erindi-brief.sh <id>`);
2. writes the findings into the brief's `# Task`, verbatim, with the instruction to prove each with the command
   the ward names;
3. creates the worktree and restores `.pi/extensions` (the known worktree fault);
4. spawns through `bin/agents/einherjar-spawn.sh --force` — the one spawn path;
5. prints `seated{errand,pane}` so the arm can speak to it.

`--no-seat` keeps the old naming-only behaviour for a dry run.

## Proof

`bash -n bin/forge/review-mend.sh` clean; `review-mend.sh <pr> --dry-run --no-seat` unchanged; a live run on a
refused PR prints `seated{errand,pane}` and the errand appears in `herdr agent list`.

## Change log

- **2026-11-12** — written with the fix, after a refusal sat for hours with nobody assigned.
