# The ready check — can this agent take a turn right now?

## What it is

One question, one answer, for both backends Ymir drives. `bin/seat/agent-ready.sh`
tells you whether an agent standing in a herdr pane, or a Hermes session, can take a
turn at this moment — and when it cannot, it says **why** in words you can act on.

The four answers are the whole vocabulary:

| answer | what it means | what you do |
|---|---|---|
| `ready` | the target can take a turn now | send it the message |
| `working` | it is mid-turn | wait; a message queues behind the turn |
| `blocked: <why>` | it exists and cannot take a turn | clear what the reason names |
| `dead` | the target is not there | pick another target |

The two reasons that matter today are `blocked: trust prompt` — the pane is standing
on a harness's "do you trust this folder?" dialog, and anything typed into it goes to
the dialog, not the agent — and `blocked: lost turn, run recover`, a Hermes session
that was mid-turn when its gateway died, which Hermes will not resume without being
told to.

## What you need

- `python3`.
- herdr running, for panes. Hermes installed, for sessions.
- Nothing else: no service, no key, no port.

## Do it

Ask about one target:

```bash
bin/seat/agent-ready.sh w6R:p1
```

Ask about a Hermes session by the short id or by part of its title:

```bash
bin/seat/agent-ready.sh hermes:fd2ee4d0
bin/seat/agent-ready.sh "hermes:Audit vaults"
```

Ask about everything on this machine — every herdr agent and every Hermes session, one
row each:

```bash
bin/seat/agent-ready.sh --all
```

Several targets at once print a row each, and the exit code is the worst of them:

```bash
bin/seat/agent-ready.sh w6R:p1 w4E:p1; echo $?
```

A script reads the exit code instead of the text: `0` ready, `1` working, `2` blocked,
`3` dead, `64` usage, `65` the reader itself failed. Add `--json` for a list of rows
carrying `target`, `backend`, `state` and `word`.

## Limits

- It answers for **this machine only**. A pane or session on another machine is asked
  over that machine's own road, which is the directory's job, not this door's.
- It never wakes anything. It reads; the relay sends. A `ready` answer is permission to
  send, not a delivery.
- Hermes state is read from the runtime's own admissions table, read-only. On a machine
  where Hermes has never run, every `hermes:` target is `dead`.
- The paused reason is a report, never a retry. Do not send into
  `blocked: lost turn, run recover`: recover the session first.

## If it does not work

- `blocked: herdr did not answer` — herdr is not running, or is not on `PATH`. Raise it
  (`bin/seat/herdr-ensure.sh`) and ask again.
- `blocked: hermes store unreadable (…)` — the Hermes home is not where this seat looks.
  Check `~/.hermes/state.db` exists and is readable.
- `dead` for a pane you can see on screen — the pane holds a bare shell, not an agent.
  `bin/seat/seats.sh list` shows the panes herdr actually knows an agent in.

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 1, the
  errand `agents-find-and-answer`).
