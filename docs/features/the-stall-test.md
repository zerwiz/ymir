# The stall test — the arm notices a worker that has stopped moving

## What it is

An errand can be **alive and stuck at the same time**. The agent still stands in its pane, so the liveness sweep
reports it as working, while the pane holds one command that has been running for hours.

On 2026-11-20 two errands sat like that and nobody noticed: one for 8 hours 45 minutes on an `ssh` command whose
background process held the session open, one for 1 hour 50 minutes on a python file being run by bash, waiting on
input.

The stall test asks the question the liveness sweep cannot:

- has the pane **moved** in the last twenty minutes?
- has **one command** run past its time limit?

When the answer is yes, the arm wakes the helm, types one line into the worker, and — if nothing has moved ten
minutes later — Rödd sends the operator one message with three buttons.

## What you need

Nothing beyond a running house. The test reads panes through herdr (or tmux as the fallback), and it lives in
`bin/agents/eindri-stall.sh`. Each machine that spawns errands runs its own.

For the Telegram message to arrive, the notify door must be able to reach the phone — the same road the rest of the
house's messages use (`bin/notify/send.sh`).

## The commands

Run it by hand, for one errand or the whole fleet:

```
bin/agents/eindri-stall.sh check            # judge and print — writes nothing, types nothing
bin/agents/eindri-stall.sh check retired-paths
bin/agents/eindri-stall.sh sweep            # judge and ACT: wake, steer, escalate
bin/agents/eindri-stall.sh show             # the stall records as they stand
bin/agents/eindri-stall.sh reset <id>       # the operator's "let it run": forget the stall
```

The clock is the Nornir row `@every:10 bin/time/nornir-job-eindri-stall.sh` — every ten minutes, while any errand
says `working`. It is silent when the fleet is moving.

The time limit on one command lives in one place:

```
bin/agents/cmd-limit-lib.sh seconds        # 1800 — 30 minutes
bin/agents/cmd-limit-lib.sh max-seconds    # 7200 — 2 hours, when declared
bin/agents/cmd-limit-lib.sh rule           # the rule every brief carries
```

## What it does, in order

| When | What happens | How often |
|---|---|---|
| the pane has not moved for 20 minutes, or one command passes 30 minutes | the helm is woken with the errand, the pane and the pane's last 15 lines | once per stall |
| at the same moment | one line is typed into the worker: *you have been on one command for N minutes; check it, or stop it and say why* | once per stall |
| ten minutes later, still unmoved | one Telegram message to the operator, with buttons for **look at the pane**, **stop it**, **let it run** | once per stall |
| the pane moves again | the stall is forgotten; a new stall later will speak again | — |

## Limits worth knowing

- Only errands whose status says `working` are judged. A finished errand is never called stuck.
- A pane that **cannot be read** on this machine (another machine's errand, no herdr) is reported as `UNKNOWN` and
  nothing is done — never a false alarm.
- A spinner redrawing is not movement. The footer's token counter advancing **is**.
- The 20-minute window and the 10-minute escalation are settings: `YMIR_STALL_FROZEN_MIN`,
  `YMIR_STALL_ESCALATE_MIN`. The command limit is `YMIR_CMD_LIMIT_S`.
- pi and opencode have no default-timeout setting in their own configuration, so the limit is handed to the worker
  in its brief and judged by this door. Claude Code's limit is set in its worker profile.

## If it does not work

- **Nothing happens on a stuck errand.** Run `bin/agents/eindri-stall.sh check <id>` and read the row: `IDLE` means
  the status is not `working`; `UNKNOWN` means the pane could not be read from this machine.
- **The wake arrives but no line reaches the worker.** The send door refuses when the input box already holds
  text — it never types over the operator's words. The record then carries `steer_failed=` and the wake says so.
- **The operator message does not arrive.** `bin/notify/send.sh --source errand --severity HIGH --message test`
  proves the road without waiting for a stall.
- **Reset one errand** after a deliberate long wait: `bin/agents/eindri-stall.sh reset <id>`.

## CHANGE LOG

- 2026-11-20 — written with the change it describes: the stall test, the ten-minute clock, the three acts, and the
  one command-limit number.
