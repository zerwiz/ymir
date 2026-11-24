# A tell says how the arm holder is woken, and Hermes gets a road

**Component:** voice (plan 369, item 1) · **Built on:** PR #926

## What was wrong

`rodd-arm.sh tell` printed `delivered: yes` once the line was in the queue. That was true of the queue
only. A Claude holder is woken by its Stop hook and a pi holder by its watcher, but a Hermes holder
(desktop or terminal) has no wake road, so the line sat unseen while the door reported success.

## What changed

- `bin/voice/hermes-arm-wake.sh` is new. It reads the pending wakes and posts them into the holder's
  Hermes session through `bin/agents/hermes-tell.sh`, with the same contract Claude gets: the text,
  how to answer (`rodd-room.sh reply`) and how to ack (`saga-wake-drain.sh ack`). It says `posted`
  only when the gateway answered; otherwise `failed` with the reason.
- `rodd-arm.sh tell` now prints two more columns, `shown` and `road`. `shown` is `hook` (the holder's
  own hook raises it), `posted` (the Hermes gateway took it) or `no` (no road: queued, nobody woken).
  The leading columns are unchanged.
- `bin/voice/tests/test_arm_wake_harness.sh` covers each harness and never reaches the real gateway.

## Not yet proven

A recorded end-to-end run on a live Hermes desktop and Hermes terminal session is owed. Whether the
gateway's reply surfaces in the desktop chat is the open question Fulla measured; this change makes
the door say `no` or `posted` honestly rather than guess.
