# The arm watches for a stall; Rödd speaks if it is not cleared

**2026-11-20.** The Allfather, after two workers sat for hours unseen: *"1 yes, this should rodd take care of and
the arm. 2 yes not to small tho. 3 ok. 4 yes."*

## What went wrong

Two errands stood still while the fleet looked busy:

| Errand | Sat | On | Why the sweep missed it |
|---|---|---|---|
| `gimle-catch-up` | 8 h 45 m | one `ssh` command — a background process held the session's stdin and stdout open | the pane held a live agent, so `bin/agents/eindri-liveness.sh` said **ALIVE** |
| `retired-paths` | 1 h 50 m | `bash test_dispatch.py` — a python file handed to bash, waiting on input | same |

`eindri-liveness.sh` asks its own question correctly — *is an AGENT standing in the pane?* — and both panes
answered yes. A pane can be **alive and frozen at the same time**, and no door asked the second question:

- has the **work** moved in the last twenty minutes?
- has **one command** run past its own time limit?

So nothing woke the helm, and nothing reached the operator.

## The change

**1. One door, one question** — `bin/agents/eindri-stall.sh`, run every ten minutes by
`bin/time/nornir-job-eindri-stall.sh` (a Nornir row, `@every:10`, in `config/cron.yaml.example`). For every errand
whose status says `working` it reads the pane by the id in `state/<id>.meta`, normalizes the harness's own
decoration (spinners, ticking durations, clock faces — a redrawing spinner is not progress), and keeps a small
record under `<home>/state/eindri-stall/<id>.state`: the last-lines hash, the footer's token counter, and when the
text last changed.

**Stuck** is no change for **20 minutes**, or one command's `Elapsed` past its limit. On the first detection, once
per stall:

- a durable wake for the helm carrying the errand id, the pane and the pane's last 15 lines;
- one line typed into the worker through the existing send door (`bin/agents/eindri-send.sh`):
  *"STALL CHECK from the arm: you have been on one command for N minutes. Check it, or stop it and say why."*

**2. Rödd speaks if it is not cleared** — ten minutes after that wake, if the pane still has not moved, **one**
message goes to the operator through the notify door (`bin/notify/send.sh`, the Telegram road), naming the errand,
the wait and the last line, with three buttons: look at the pane · stop it · let it run. A clean fleet is silent.

**3. The command time limit, not too small** — `bin/agents/cmd-limit-lib.sh` is the one number: **30 minutes** by
default, **2 hours** when a build, a gate suite or a release declares it, never unlimited. It is read by
`bin/agents/erindi-brief.sh` (rules 7 and 8 of every brief, which carry the ssh rule too), by the stall test, and by
`bin/seat/pi-launcher.sh`, which exports it into the seat's environment. Claude Code's own limit is set in the
worker profile every Claude seat is launched with
(`.agents/harnesses/claude-worker.settings.json`: `BASH_DEFAULT_TIMEOUT_MS=1800000`, `BASH_MAX_TIMEOUT_MS=7200000`).

pi and opencode have **no default-timeout key** in their settings, so a limit cannot be imposed inside those
harnesses. Said plainly rather than papered over: there the worker is handed the rule, and the arm judges the wall
clock and steers the worker when it is passed.

## What proves it

`bin/agents/tests/test_eindri_stall.sh`, wired as the gate `bin/gates/checks.d/0392-the-stall-test.sh` — a
throwaway state dir, a directory of fake panes, a simulated clock, and the send and notify doors replaced by files
that record what would have been typed and sent. 28 assertions, including:

- a moving pane → no wake, no steer, no message;
- frozen 20 minutes → exactly one wake and one steer;
- a second sweep in the same stall → nothing new;
- frozen 30 minutes → exactly one operator message, and never a second;
- the pane moves again → the stall clears, and a **new** stall wakes afresh;
- one command past 30 minutes → stuck on the first look, no quiet window;
- a redrawing spinner is not movement; an advancing token counter is;
- an errand that reported `done` is never judged; a pane that cannot be read is `UNKNOWN`, never a false alarm.

`bin/agents/eindri-stall.sh check` on the live fleet printed 38 seats, 3 of them working, all `MOVING` — no false
alarm on a healthy hall.

## Files

- `bin/agents/eindri-stall.sh` — the stall test (new)
- `bin/agents/cmd-limit-lib.sh` — the one command-limit number (new)
- `bin/agents/tests/test_eindri_stall.sh` — the proof (new)
- `bin/gates/checks.d/0392-the-stall-test.sh` — the gate that runs it (new)
- `bin/time/nornir-job-eindri-stall.sh` — the ten-minute clock (new)
- `config/cron.yaml.example` — the `@every:10` row
- `bin/agents/erindi-brief.sh` — rules 7 and 8 in every brief: the limit, and detaching over ssh
- `bin/seat/pi-launcher.sh` — the seat's environment carries the same number
- `.agents/harnesses/claude-worker.settings.json` — Claude's own bash timeout, set at last
- `.agents/skills/galdr-ymirsystem/assets/brokk-distro-runtime.md` — the arm and the sweep documented
- `docs/features/the-stall-test.md` — the how-to, with its catalogue row
