# The house was split: a review spawn could never seat

**Date:** 2026-11-06 · **Plan:** 203 (the review road) · **Law:** `RULES/07-config.md` (one resolver, no half-override)

## What was wrong

A queued wake said it plainly: *"eins-the-desk-everywhere review spawn FAILED (rc=1): error: the
house is split — state, data and config resolve to different bases."* The task it was reviewing was
finished and its PR open, so the failure was a follow-on review that never seated — a hole in the
review road, not a bad task.

`bin/agents/eindri-review-spawn.sh` passes a spawn its state and data overrides:

```
BROKK_HOME="$SHARED_ROOT" BROKK_STATE_OVERRIDE="$SHARED_STATE" BROKK_DATA_OVERRIDE="$SHARED_DATA"
```

`BROKK_CONFIG_OVERRIDE` was never passed, so CONFIG kept resolving from `$BROKK_HOME/config`. On this
seat the resolved state is the **home's** (`$YMIR_HOME/state`) while the data was `$PROJECT/data` and
the config `$PROJECT/config` — three houses, one spawn. `einherjar-spawn.sh` compares the three bases
and refuses a split (correctly, and that refusal is the reason two errands once owned two worktrees),
so every review of a finished task died at the door it was trying to open.

## The fix

The state that resolves IS the house the review's records belong to, so `data` and `config` are taken
from **its base**, and all three are passed together:

```
SHARED_BASE="$(dirname "$SHARED_STATE")"
SHARED_DATA="${SHARED_DATA_OVERRIDE:-$SHARED_BASE/data}"
SHARED_CONFIG="${SHARED_CONFIG_OVERRIDE:-$SHARED_BASE/config}"
```

and the spawn is given `BROKK_CONFIG_OVERRIDE="$SHARED_CONFIG"` alongside the other two. `BROKK_HOME`
still points at the project, so worktrees land where they did — what changed is that the three paths a
spawn reads its records from now share one base.

## How it was proved

The refusal is reproducible, so the proof is a before/after on the same command:

```
# the shape the script used to pass — refused
env -u BROKK_CONFIG_OVERRIDE BROKK_HOME=~/ymir \
    BROKK_STATE_OVERRIDE=$YMIR_HOME/state BROKK_DATA_OVERRIDE=$YMIR_HOME/data \
    bin/agents/einherjar-spawn.sh eins-the-desk-everywhere-review ~/ymir --scout --dry-run
  error: the house is split — state, data and config resolve to different bases.
    state: …/ymirhome/state   data: …/ymirhome/data   config:/home/zerwizomar/ymir/config

# the shape it passes now — the split refusal is gone, and the run proceeds to the next check
env -u BROKK_STATE_OVERRIDE -u BROKK_DATA_OVERRIDE -u BROKK_CONFIG_OVERRIDE BROKK_HOME=~/ymir \
    BROKK_STATE_OVERRIDE=$YMIR_HOME/state BROKK_DATA_OVERRIDE=$YMIR_HOME/data \
    BROKK_CONFIG_OVERRIDE=$YMIR_HOME/config \
    bin/agents/einherjar-spawn.sh eins-the-desk-everywhere-review ~/ymir --scout --dry-run
  (passes the house check; stops later on an unrelated model-resolution default)
```

And the review road itself still resolves: `eindri-review-spawn.sh eins-the-desk-everywhere --dry-run
--force` prints the same review id, PR #534, the branch, the brief and the report, with the spawn line.

## Owed

The model-resolution default `einherjar-spawn.sh` falls back to (`llama-swap/qwen3.6-35b-a3b@q4_k_xl-mtp`)
does not resolve on this machine, and that surfaced the moment the house check stopped hiding it. It is
a separate fix and it is named here so it is not mistaken for done.

## CHANGE LOG

- **2026-11-06** — first cut: the third override, the base derived from the resolved state, before/after
  proof of the split refusal, and the review road's own dry-run as the regression check.
