# A turn the operator began stays with the operator

Plan 381.

## What went wrong

The turn-end hook sent the whole final answer to every agent heard in a turn, including a turn the operator began. An agent that drained or steered into it received words meant for the operator.

## What changed

`reply.py` asks who is in the turn: a line typed with no stamp, or stamped as the operator, makes it the operator's. Each agent sender then gets a short receipt. Lines a harness writes itself (task notices, system reminders, Ymir's operational input, synthetic entries) do not count as the operator. The rule also covers a line of the operator's that joins a turn an agent began.

## Proof

`bin/agents/tests/test_reply.sh`: the receipt cases and the harness-line cases. Not proven in a live pane.

## CHANGE LOG

- 2026-11-26 — written with the round-two rework.
