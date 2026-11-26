# The engine's brief is stamped

Plan 381.

## What went wrong

The engine seats most errands, and it wrote `prompt.md` with no sender stamp. A worker's first turn then read as the operator's own, so a steer queued into it got a receipt instead of the answer.

## What changed

`_prompt_for` in `src/ymir_runtime/seat.py` writes the `msg-origin.sh` stamp as the first line, ahead of the bearings. A brief that already leads with a stamp keeps that one. If the stamp door cannot answer, a script's stamp is written.

## Proof

`src/ymir_runtime/tests/test_seat.py` and `bin/agents/tests/test_reply.sh`. Not yet proven in a live pane.

## CHANGE LOG

- 2026-11-26 — written with the round-three rework.
