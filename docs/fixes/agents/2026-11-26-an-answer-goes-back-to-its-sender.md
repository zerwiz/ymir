# An answer goes back to its sender

## What went wrong

An agent that received a message through a Ymir door answered in its own window. The sender never heard it.

## What changed

A new door, `bin/agents/reply.sh`, reads the stamp and answers on the same road. `eindri-send.sh` notes each stamped line for the receiving pane, never sends a second copy of a reply, and `msg-origin.sh` leaves a reply stamp alone and names a Hermes session as a sender. The fixed core says to answer the sender.

## Proof

`bin/agents/tests/test_reply.sh`. Real herdr panes: pi asked Claude and got the answer back, and pi asked pi and got the answer back. Nothing bounced further.
