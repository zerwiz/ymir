# fleet-tell: the review's five items

**Component:** fleet (`bin/fleet/fleet-tell.sh`, `bin/fleet/arm-holder-pane.sh`) · **Date:** 2026-11-21

## What was wrong

1. A send shared the 25 s probe limit, but `eindri-send.sh` sleeps 20 s after typing (40 s on a re-send), so a delivered line was killed with 124 and reported as not typed.
2. The row claimed "a wake is raised" without checking it; `rodd-arm.sh tell` refuses when the sender's arm is not held, and that was thrown away.
3. The header comment named a real machine.
4. The far side ran without the herdr socket or `~/.local/bin` on its path, and a missing door (127) was reported as "no agent pane".
5. `--dry-run` exited 1, because every dry-run row counted as failed.

## What changed

- A send has its own limit (`FLEET_TELL_SEND_TIMEOUT`, default twice `EINDRI_SEND_WAIT` plus 30 s). Exit 124 or 5 after a send is reported `sent-unconfirmed`. The pane lookup has its own limit, above the inner limits of `arm-holder-pane.sh` (now 20 s and 10 s).
- A wire that timed out no longer skips the pane fallback; only an unreachable machine (255) does.
- The wake checks its exit code, falls back to the durable wake queue, and the row says `wake=raised` or `wake=not-raised(why)`.
- The example machine is `host-a`.
- The far command sets `PATH` and `HERDR_SOCKET_PATH` first; exit 127 is reported as "door missing on <machine>'s runtime".
- `--dry-run` exits 0.

## Proof

`bin/fleet/tests/test_fleet_tell.sh` gains cases for a slow send, exit 5, exit 124, the wake fallback, a missing door and the dry-run exit.
