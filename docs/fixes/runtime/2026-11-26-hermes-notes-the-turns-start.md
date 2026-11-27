# Hermes notes when a turn began

Plan 381.

## What went wrong

The Hermes hook gave no start time for a turn, so an answer sent by hand during it was never seen.

## What changed

`session_hook.py` notes the start at `pre_llm_call` and passes it with the message at `post_llm_call`.

## Proof

`src/ymir_runtime/tests/test_hermes_session_hook.py`. Built, not yet proven live.

## CHANGE LOG

- 2026-11-26 — written with the round-two rework.
