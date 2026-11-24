# A hermes return address is answered by a waiter the sender starts

Date: 2026-11-24 · Component: agents · Plan 365 R2

## What was wrong

A line sent into a desktop Hermes session with `hermes-tell.sh` printed "handed" but never appeared in the desktop chat, so an answer to a `hermes:` address was lost while the door said it had landed.

## What changed

`bin/agents/answer.sh wait <errand>` is a background process the sender starts at dispatch. It blocks until the worker's handoff lands, prints the answer line and exits, and the exit is the wake the sender's harness receives. For a `hermes:` address `answer.sh` reports `sent` only when a live waiter exists; otherwise the answer stays queued. `eindri-dispatch.sh new` prints the exact waiter command for a `hermes:` address.

Proof: `bash tests/test_answer_door.sh` runs a waiter, writes the handoff, answers, and checks that the waiter exits with the line; and that with no waiter the answer is queued, never reported as handed.
