# An alarm did not say which machine raised it

**Date:** 2026-11-20 · **Component:** notify (`bin/notify/send.sh`) · **Errand:** `alarm-host`

## What was wrong

At the operator's word: *"Make alarm lines name the machine they came from — starting with the cron notifier and
the garmr and skirnir senders — so a dev machine's failure does not read as the heart's, and prove it with one
line from each sender."*

Measured that evening, on his phone: a burst of eleven cron failures arrived in one paste, and they came from
**three different machines** — a sweep and a nightly the heart does not even schedule, a guardian alarm from a dev
seat, and two genuine failures on the heart. Every line read the same:

```
[cron/HIGH] job failed (rc=1): bin/records/gimle-tunnels-check.sh --quiet — no output
```

Nothing in it named the machine, so a dev machine's `@dev`-gated job read as the heart falling apart, and the
operator spent an evening chasing failures that were not his.

## What was built

All three senders — the cron notifier, Garmr's brain (`bin/ward/garmr/brain.py`) and the assistant's escalation
timer (`systems/skirnir/services/escalation-timer.sh`) — speak through **one door**: `bin/notify/send.sh`. So the
tag belongs there, once, and no sender can forget it:

```
[<machine> · <source>/<SEVERITY>] <the message, untouched>
```

| fact | where it comes from |
|---|---|
| the machine | `hostname -s`, lowercased, resolved once when the line is built |
| a relay naming another machine | `YMIR_NOTIFY_HOST` — for a sender that speaks on behalf of one it is not |
| the message | unchanged after the tag, so a message may itself contain a separator |

A second seam was needed to prove it: `--print-line` prints the constructed line and delivers nothing, so a person
or a test can see exactly what would go to the phone.

## The proof

One line from each sender, through the door each of them actually calls:

```
$ bin/notify/send.sh --source cron      --severity HIGH --message "job failed (rc=1): bin/x.sh — no output" --print-line
[<machine> · cron/HIGH] job failed (rc=1): bin/x.sh — no output
$ bin/notify/send.sh --source garmr     --severity HIGH --message "job failed (rc=1): bin/x.sh — no output" --print-line
[<machine> · garmr/HIGH] job failed (rc=1): bin/x.sh — no output
$ bin/notify/send.sh --source assistant --severity HIGH --message "job failed (rc=1): bin/x.sh — no output" --print-line
[<machine> · assistant/HIGH] job failed (rc=1): bin/x.sh — no output
```

and the gate:

```
$ bash bin/notify/tests/test_send_names_the_machine.sh
  ok   a cron line names this machine first
  ok   a garmr line names this machine first
  ok   a assistant line names this machine first
  ok   a relay may name the machine it speaks for (YMIR_NOTIFY_HOST)
  ok   the message survives whole
  ok   the message after the tag is untouched
send-names-the-machine: 6 passed, 0 failed
```

## What this does not decide

- **Every machine must take this change before the fleet is legible.** The tag is built by the sender's own copy
  of the door, so a machine still running an older release keeps sending untagged lines until it updates. The two
  dev machines were measured 32 commits behind the same evening, running a release from before this change.
- **The burst itself is not fixed.** A line that names its machine is easier to ignore correctly; the alarms that
  repeat until someone decides something are plan 332's business, not this door's.

## CHANGE LOG

- 2026-11-20 — written the evening eleven failures from three machines arrived as one.
