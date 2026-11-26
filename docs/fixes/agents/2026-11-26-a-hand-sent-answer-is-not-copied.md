# An answer sent by hand is not copied by the hook

Plan 381.

## What went wrong

Only `reply.sh` noted that a sender was answered. An answer sent with `eindri-send.sh` was followed by a second copy from the turn-end hook.

## What changed

`eindri-send.sh` notes an agent's own sent line through `reply.sh --sent`. The note is kept per replying agent, so another agent's line to the same pane silences nothing. A script's line and a refused or failed send are not noted. Any line the agent sends that pane during the turn counts, a new question included.

## Proof

`bin/agents/tests/test_reply.sh`: the four hand-sent cases. Not proven in a live pane.

## CHANGE LOG

- 2026-11-26 — written with the round-two rework.
