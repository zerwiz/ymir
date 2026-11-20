# Every message carries a target, and one door owns the click

**Date:** 2026-11-09 · **Plan:** 230 (N1/N2), 231 §4 (R4) · **Component:** notify
**Law:** RULES/25 (a green that hides a borrow is not a green), plan 230's own rule

## What was wrong

A toast that libnotify draws as clickable and that does nothing on click is worse than a toast that
is plainly not clickable — it teaches the operator to stop trying. Two shapes of the fault lived on
in four places:

- `systems/snotra/services/cron/snotra-cron.sh` sent `notify-send -a Snotra "Meeting digest" …` with
  no action: clickable, dead.
- `bin/gates/wedge-notify.sh` and `bin/host/crash-sense.sh` chose their own notifier and sent a
  bare sentence, so each would have invented its own action or none.
- the hotline's desktop leg (`systems/snotra/services/tts-lease/ymir-say.sh`) called the notifier
  directly — and its `--exec` click was being **eaten by its own flag parser**, so an approval toast
  could not approve anything. Measured while repointing it: the parser consumed `--exec` in a
  `*) shift ;;` branch before `EXEC_ARGS` looked at `"$@"`, and by then `"$@"` was empty.

## What was built

`bin/notify/open-target.sh` — one door with two jobs:

```
open-target.sh <kind> <value>      open it (this is what a click runs)
open-target.sh toast …             send the toast, and make the click real
open-target.sh resolve <kind> <v>  does it exist? change nothing
open-target.sh --check             what this seat can open and show with
```

Four kinds, resolved in one place: `file:` (absolute or home-relative), `plan:<n>` (the ledger file
for that number), `pr:<url>`, and `yl:<route>` (`http://127.0.0.1:3888/#/<route>` when the gate
answers, a named refusal when it does not).

The three-way title rule from plan 230 §2: a verified target keeps its title and carries
`--action=default=Open` (libnotify) or `--exec` (Omarchy's own notifier); a **missing** target says
`(target missing)` and files one finding with the hotline; a message with **no** target says
`(no link)`. A dead link is fixed, not clicked again.

`bin/notify/send.sh` gained `--target <kind>:<value>`: the Rune line carries it, and the desktop leg
forwards it to the door.

## The four repointed senders

```
sender                                            target it now carries
bin/gates/wedge-notify.sh                         file:<the wedge alarm log it just wrote>
bin/host/crash-sense.sh                           yl:processes (the process board; a crash has no page of its own)
the hotline's desktop leg (ymir-say.sh)           whatever send.sh was given, else (no link)
systems/snotra/services/cron/snotra-cron.sh       file:<the digest it just wrote>
```

`grep -rn notify-send` outside `bin/notify/` now returns **nothing** — not even a comment, because
the rule is machine-checkable and a comment that names the old road is still a match.

## Verified

`bash bin/notify/tests/test_open_target.sh` — every kind, and both dead paths, offline:

```
file: existing resolves · missing → exit 3, "target missing"
plan: 231 resolves to the ledger file · 99999 refused
pr:   the url resolves · a bare number refused
yl:   resolves against a stand-in gate on its own port · a down gate → exit 4, named
title: (no link) · (target missing) · a good target carries the click
open: --dry-run opens nothing and says what it would open
```

`open-target.sh --check` on this seat: `xdg-open`, `omarchy-launch-editor --inline`, the gate up on
3888, `omarchy-notification-send`.

## CHANGE LOG

- **2026-11-09** — The target door, the `--target` flag on the hotline, the four repointed senders,
  and the `--exec` parser fault in the desktop voice (plans 230 N1/N2, 231 R4).
