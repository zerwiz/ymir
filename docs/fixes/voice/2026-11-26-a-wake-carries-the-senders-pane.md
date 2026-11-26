# A wake carries the sender's pane

## What went wrong

A line in the arm holder's wake queue named the agent but not its pane, so there was nothing to answer.

## What changed

`rodd-arm.sh tell` adds the proved pane to an agent's name, after the line's class is read.

## Proof

`bin/voice/tests/test_rodd_arm.sh`.
