# The sender's pane crosses machines

## What went wrong

A line sent to another machine was stamped without the sender's pane, because the stamp was made on the far side.

## What changed

`fleet-tell.sh` and `arm-send.sh` prove the sender's pane on the sender's machine and carry it in the signature.

## Proof

`bin/fleet/tests/test_fleet_tell.sh`, and the cross-machine case in `bin/agents/tests/test_reply.sh` over a fake ssh.
