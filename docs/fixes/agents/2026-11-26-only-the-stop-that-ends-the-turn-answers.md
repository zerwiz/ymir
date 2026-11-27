# Only the stop that ends the turn answers

Plan 381.

## What went wrong

The hook sent the unfinished words when another hook refused the stop, and marked the message answered. An answer for the arm holder was typed into its pane. A message from an agent was not told apart from the operator's own.

## What changed

`reply.py` anchors on the final answer in the transcript and waits for the verdict. The arm holder is answered through its wake queue. Only a stamp of the operator's own opens the roads to the operator. A drained wake is owed an answer. `tell.sh` and the spawn briefs stamp the sender's pane.

## Proof

`bin/agents/tests/test_reply.sh`, which drives the real doors. A real Claude pane with a refused stop sent only the final answer.

## CHANGE LOG

- 2026-11-26 — written with the rework.
