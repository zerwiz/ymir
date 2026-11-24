# The Claude arm holder now hears its wakes, and Rödd hears its answers

**Date:** 2026-11-24 · **Component:** rodd (the arm's road to a Claude seat)

## What was wrong

The operator said: "youre the arm holder. but it dont wake u". Two faults were measured.

- **The wake carried nothing.** `.claude/hooks/ymir-arm.sh` did rewake the Claude seat, but only with the bare line
  `signal: wake queue`. The seat saw no message and no instruction, so the wake sat in the queue until the next
  session start.
- **The answer went nowhere.** `bin/voice/rodd-room.sh` read the state directory as column 7 of
  `rodd-arm.sh who`. The `who` header has grown (`seat,role,charter,host,fleetrole,fleet,pin,…`), so column 7 is now
  the pin. Every reply was written to a stray `<pin>/rodd/room.jsonl` under the caller's directory, and Rödd's real
  room never got it.

## What changed

- On a `signal:`, the hook now prints the waiting wakes (`saga-wake-drain.sh drain`) and the two commands that
  answer them: `rodd-room.sh reply "<text>"` and `saga-wake-drain.sh ack`.
- `rodd-room.sh` finds `state_dir` by its name in the `who` header, and refuses anything that is not an absolute path.

## Proof

- `bash bin/voice/rodd-room.sh path` prints the state directory's `rodd/room.jsonl`, not the pin.
- `bin/voice/tests/test_rodd_arm.sh`: 71 passed, 0 failed.
- `bin/voice/tests/test_rodd_helm.sh` fails 11 checks both with and without this change. That fault already existed, and it is left for the follow-up.
