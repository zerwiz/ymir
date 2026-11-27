# A done with no line still reaches the sender

## What went wrong

`eindri-acclaim.sh <id> --terminal done` with no `--line` filed its report and sent the sender nothing. The sender of a
worker on another machine heard no result.

## What changed

A terminal act with no `--line` tells the recorded sender once. The message says that no line was given and no
evidence was weighed, so nothing is proven. The evidence gate itself is unchanged.

## Proof

`bin/agents/tests/test_sender_direct.sh`, with fakes for the pane and the other machine: 48 ok, 0 failed, and the new
case fails without the change. Not yet run across two real machines.

## CHANGE LOG

- 2026-11-27 — a terminal act with no line reaches the sender.
