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
