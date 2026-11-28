# A done with no line still reaches the sender

## What went wrong

`eindri-acclaim.sh <id> --terminal done` with no `--line` filed its report and sent the sender nothing. The sender of a
worker on another machine heard no result.

## What changed

A terminal act with no `--line` tells the recorded sender once. The message says that no line was given and no
evidence was weighed, so nothing is proven. The evidence gate itself is unchanged.

## Proof

`bin/agents/tests/test_sender_direct.sh`, with fakes for the pane and the other machine: 48 ok, 0 failed, and the new
case fails without the change.

Across two real machines: in `proof-971-far2` the act with no line sent its message; the sender's pane was gone, so it
reached the sender machine's arm holder as an undelivered answer. In `proof-971-live` a done act with a line and
evidence landed in a live sender pane. A no-line act landing in a live pane on another machine has not been shown. The
runs are in `2026-11-27-a-worker-talks-back-to-its-sender.md` under Second machine.

## CHANGE LOG

- 2026-11-27 — a terminal act with no line reaches the sender.
- 2026-11-27 — appended: the two-machine runs. The no-line message crossed machines and fell back to the arm holder
  when the pane was gone; a done with a line landed in a live pane. "Not yet run across two real machines" is replaced.
