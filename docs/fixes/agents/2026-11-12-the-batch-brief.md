# The batch brief: commit, remember, acclaim — never push

**Date:** 2026-11-12 · **Component:** agents · **Door:** `bin/agents/erindi-brief.sh --mode batch`

## What changed

`erindi-brief.sh` gains a fourth delivery mode, `batch`, for errands dispatched together. Its brief says
`Delivery contract: mode=batch`, forbids any push or PR, asks the worker to run its own tests, leave
`git status` clean, record its work in the well, and acclaim
`committed on eindri/<id> (not pushed): <what, proof>`. That acclaim is what `bin/forge/gather.sh
--finished` looks for. `einherjar-spawn.sh` and `eindri-dispatch.sh` accept the new mode.

## Proof

`.agents/tests/erindi-brief-batch.test.sh` passes (8 cases).
