# A synthetic entry is not the operator

Plan 381.

## What went wrong

The OpenCode hook passed synthetic entries like typed ones, so one would have made a turn look like the operator's.

## What changed

`reply-back.js` marks synthetic entries, and the router does not count them as the operator.

## Proof

`bin/agents/tests/test_reply.sh`, the synthetic case, at the router. The OpenCode hook is built, not yet proven live.

## CHANGE LOG

- 2026-11-26 — written with the round-two rework.
