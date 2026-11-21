# The dispatch lock sat in the record, and Eir's hoard row was red on every seat

**Date:** 2026-11-21 · **Component:** agents (`bin/agents/eindri-dispatch.sh`) · **Errand:** `open-ends`

## What was wrong

Eir's `hoard` surface was red on the heart and on a second machine with the same line:
`hodd/data/backlog.lock · a runtime artefact inside the record — runtime belongs in $YMIR_HOME/state (plan 331)`.
`eindri-dispatch.sh` line 62 set `LOCK="$DATA/backlog.lock"`, beside the backlog it guards, so every dispatch made
the file again in the record shelf.

## What was built

The lock lives at `$YMIR_HOME/state/eindri/backlog.lock`. A test that overrides the data shelf
(`BROKK_DATA_OVERRIDE`) keeps its lock beside its own data, so no test touches a real home. If the state shelf
cannot be made, the old place is used rather than failing the dispatch.

The stale `hodd/data/backlog.lock` on each seat is removed by the operator once this lands (it is an empty
lock file; nothing reads it).

## Proof

`bash bin/forge/tests/test_gather_notice.sh` — 12 passed; `bash bin/seat/tests/test_seat_reap.sh` — 70 ok.
