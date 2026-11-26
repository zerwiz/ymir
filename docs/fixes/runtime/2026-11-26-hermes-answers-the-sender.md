# Hermes answers the sender

## What went wrong

A Hermes turn ended without answering whoever sent the message.

## What changed

The session hook handles `post_llm_call` and hands the message and answer to `reply.sh`.

## Proof

`src/ymir_runtime/tests/test_hermes_session_hook.py`, with a fake reply door. Not yet seen in a live Hermes session.
