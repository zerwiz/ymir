# Every seating door stamps the sender

Plan 381.

## What went wrong

Several doors typed a brief into a pane with no stamp, so the worker read it as the operator's word.

## What changed

`herdr-run.sh`, `claude-seat.sh`, `seat-wire.sh`, the backend prompt and the seat render now stamp, and say that an agent's message is not the operator.

## Proof

`bin/agents/tests/test_reply.sh` for the backend prompt; the seat tests.

## CHANGE LOG

- 2026-11-26 — written with the rework.
- 2026-11-26 — plan 381, round three: the engine road, the default one for `einherjar-spawn.sh` and `eindri-start.sh --id`, handed the brief over before any stamp, so a worker's first turn read as the operator's. `_prompt_for` in `src/ymir_runtime/seat.py` now writes the `msg-origin.sh` stamp as the first line of `prompt.md`, ahead of the bearings; a brief that already leads with a stamp keeps that one. Proof: `src/ymir_runtime/tests/test_seat.py` and `bin/agents/tests/test_reply.sh`.
