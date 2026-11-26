# A wake from an agent is not the operator

Plan 381.

## What went wrong

The wake text did not say who was there, and one voice tool sent an unstamped line.

## What changed

`hermes-arm-wake.sh` says so, every sender in a pane is recorded by `rodd-arm.sh`, and the voice send tool stamps the operator's voice.

## Proof

`bin/voice/tests/test_rodd_arm.sh`.

## CHANGE LOG

- 2026-11-26 — written with the rework.
