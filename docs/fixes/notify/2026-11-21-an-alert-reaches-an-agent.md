# An alert reached the chat and no agent

**Date:** 2026-11-21 · **Component:** notify (`bin/notify/send.sh`), with the cron scheduler and learn-home · **Errand:** `alerts-reach-agents`

## What was wrong

At the operator's word: *"The cron are still not triggering the chat … We must be sending in to the chat wrong."*

Over the night of 2026-11-20 the alarm bot posted the same CRITICAL hound line every 15 minutes for 9 hours, cron
failures that said `no output`, and a CI notice. No agent answered any of them. Four faults stood behind that:

| fault | where | effect |
|---|---|---|
| the bot posted straight to the Bot API | `bin/notify/send.sh`, the telegram leg | a bot's own post never reaches any session as a turn, so no agent was engaged |
| the arm leg was local only | `bin/notify/send.sh`, the arm leg | a dev machine's alert woke only that machine's arm, which was dead for three hours with 67 lines unread |
| CRITICAL skipped dedupe | `bin/notify/send.sh`, the dedupe block (`if severity != "CRITICAL"`) | the hound's hourly key never held; housewatch's 15-minute timer made 36 lines in 9 hours |
| the row's tail was the shared log | `bin/time/nornir-cron-start.sh`, `run_row` | a failing row was described by another row's last line, or by nothing |

The learn-home row also exited 4 with a failure row that printed a literal `$SHELF` (single quotes) and pointed at
home-sync's words instead of carrying them.

## What was built

**The owner road.** A HIGH or CRITICAL line (not `--ask`) is handed to the arm holder that owns its source, through
`bin/fleet/arm-send.sh`, so it arrives as that agent's turn. The owner is the machine named in the line, or the rule in
the home's `config/notify-owners.conf` (template: `config/notify-owners.conf.example`). When the owner's arm does not
answer, the heart's arm holder takes it and the line says so.

**The agent answers the operator.** The turn asks for ONE `telegram_message` with what was found and three buttons:
look, fix, and silence for a day. The raw bot post is held in `<home>/state/notify/pending/` for
`YMIR_NOTIFY_ANSWER_MIN` minutes (default 10). It is posted with *no agent answered* when nobody ran
`send.sh --answered <id>`, so a silent fleet still pages him. A held post that outlives its scheduler is posted by the
next call to the door.

**Dedupe that holds.** One line per group per hour, CRITICAL included, with `(repeated N× since the last line)` in
the next. The group is the source, the key with its stamp segments folded, and the machine. `housewatch.sh` now keys
by surface alone.

**A failing row says why.** Each cron row writes its own stdout and stderr; `cron_row_tail` puts the last three stderr
lines into the notice. learn-home captures home-sync's output, passes it through, and names its last line in the
failure row.

New verbs: `--answered <id>`, `--silence <group> [--hours 24]`, `--flush <id>`, `--flush-due`, each with
`--on <machine>` to run where the alert was raised.

## The proof

```
$ python3 bin/notify/tests/test_alert_owner_road.py
Ran 15 tests … OK
```

It proves, with a fake Telegram and a fake arm wire: an alert from machine A reaches A's arm; with A dead it reaches
the heart's arm and says so; with no arm anywhere the bot posts at once; an unanswered alert is posted raw after the
wait and an answered one never is; 36 CRITICAL repeats over 9 hours make 9 lines, each after the first carrying
`repeated 3×`; a failing row's stderr tail is the reason. `systems/skirnir/tests/test_learn_home_ship.sh` gained three
cases for the exit-4 path (23 pass). The neighbours still pass: `test_send_buttons.py`,
`test_send_names_the_machine.sh`, `test_question_wake.sh`, `test_desk_failsafes.sh`, `test_private_scan_exit.sh`.

## What this does not decide

- **Every machine must take the release.** The owner road is built by the sender's own copy of the door; a machine on
  an older release keeps posting raw.
- **The agent's answer is a behaviour, not a wire.** The turn tells the arm holder what to do; a holder that ignores
  it leaves the raw post to fire after the wait, which is the floor.
- **One extra call per alert.** The owner road may wait up to 30 s per hop (`YMIR_NOTIFY_ARM_TIMEOUT`) on a dead
  machine's road before it falls back to the heart.

## CHANGE LOG

- 2026-11-21 — written the morning after nine hours of one unanswered hound line.

## Addendum: a pid is not a stamp (rework of PR #861)

The review found that the key fold treated any segment of six or more digits as a stamp. The ward watcher keys each
alert per process (`garmr:{title}:{pid}`), so a second process with a 7-digit pid came back `duplicate` and was
silenced for an hour. Machines with short pids behaved differently.

Now only real stamp shapes fold: `20YYMMDD` with an optional hour, minute and second, a 10-digit epoch, and an ISO
date or time. The ISO stamp is lifted from the whole key before the key is split on `:`, because its colons used to
break it into pieces that did not fold. New tests: two pids in a key stay two lines, and an epoch or ISO stamp still
folds.

## Addendum: a number that names a thing is not folded (rework of PR #861)

An alert with no `--key` was grouped by its message with every digit folded. So `new PR #857 opened` and
`new PR #858 opened` became one group, and the second notice was hidden for an hour. Review seats send exactly that
kind of unkeyed notice.

Now only measurements fold: an ISO stamp or a clock time, a number with a unit (`25895s`, `3 min`, `91%`, `2 GB`),
and a number after `age`, `old`, `rc`, `exit` or `took`. Any other number is kept as an identity. New tests: two
PR numbers and two ports stay two lines each, and changing measurements still fold into one.
