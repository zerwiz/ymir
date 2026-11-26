# Hermes answers the sender

## What went wrong

A Hermes turn ended without answering whoever sent the message.

## What changed

The session hook handles `post_llm_call` and hands the message and answer to `reply.sh`.

## Proof

`src/ymir_runtime/tests/test_hermes_session_hook.py`, with a fake reply door. Not yet seen in a live Hermes session.

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #966

- 2026-11-26 — part of plan 381, an answer goes back the way it came.
