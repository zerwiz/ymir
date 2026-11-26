# The head says to answer the sender

## What went wrong

The fixed core did not say that a stamped message is answered to its sender.

## What changed

One line in `saga-head-core.md` names `reply.sh` and the turn-end answer.

## Proof

`bin/time/tests/test_saga_head.sh`.

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #966
