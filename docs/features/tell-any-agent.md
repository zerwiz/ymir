# Tell any agent — one door

## What it is

An agent on this machine can live in five places:

- a herdr pane (a worker, or a Claude or pi seated there);
- the arm holder (one session per machine);
- a plain terminal window you started by hand;
- the Hermes gateway (the process the Hermes desktop rides on);
- the Hermes CLI in a terminal.

Each place has its own road. `bin/agents/tell.sh` is one door to all of them. You name the agent, and the door finds the
road and tells you which one it took.

## What you need

- **For herdr panes:** `herdr`.
- **For terminal windows:** Wayland on Hyprland, and `wtype`. See
  [Tell an agent in a terminal window](tell-an-agent-in-a-terminal-window.md).
- **For Hermes:** a running Hermes gateway with its API server enabled. That means `API_SERVER_ENABLED`,
  `API_SERVER_PORT` and `API_SERVER_KEY` set in Hermes's own `.env` (under `HERMES_HOME`, default `~/.hermes`). The door
  reads the key there each time and never copies or prints it.

## The commands

```bash
bin/agents/tell.sh --list                          # every agent it can reach, and the road to each
bin/agents/tell.sh arm "the build is green"        # the arm holder
bin/agents/tell.sh my-errand "read the new brief"  # a herdr pane, by errand name or pane id (wXX:pY)
bin/agents/tell.sh window:claude "status?"         # an agent in a terminal window, by pid or word
bin/agents/tell.sh hermes "what is on my calendar?"            # Hermes, a fresh session
bin/agents/tell.sh hermes:desktop "add this to the plan"       # the conversation the desktop is on
bin/agents/tell.sh hermes:<session-id-or-title> "and then?"    # a named Hermes session
bin/agents/tell.sh --dry-run hermes:desktop "x"    # show the road, hand nothing
```

`--from "<who>"` names the sender. Without it the line is signed `script tell`, or by `YMIR_MSG_FROM` when that is set.

Hermes has its own door too, with a few more verbs:

```bash
bin/agents/hermes-tell.sh --where       # the listener, whether a key is present, the desktop's session and window
bin/agents/hermes-tell.sh --sessions    # the sessions a tell can address, and whether each is busy
bin/agents/hermes-tell.sh --new "…"     # prints the new session's id, so you can continue it with --session
```

## What it promises

- **Every line is stamped `[from <who>]`.** An agent never mistakes another agent's line for the operator's word.
- **The result is *handed*, never *done*.** Hermes answers inline, and its answer is printed. A pane or a window answers
  in its own screen.
- **One line only.** A long message goes in a letter file, and the line points to it.

## Limits

- **A busy Hermes session is refused.** That means one that is mid-turn or has subagents still running. Hermes's API
  has no per-session lock, so a second turn would race the first. Wait, or pass `--force` to `hermes-tell.sh`.
- **The Hermes key is only sent over loopback.** `HERMES_TELL_ALLOW_REMOTE=1` overrides this.
- **If the desktop window is closed,** a `hermes:desktop` line lands in the conversation and shows when the window
  opens.
- **Another machine is not reached yet.** `<machine>:<who>` is refused by name. Use `bin/fleet/arm-send.sh` or
  `eindri-send.sh --machine` until plan 340.5 lands.
- **The window road refuses while you are on a call.** It checks `bin/desk/in-call.sh holder` first.

## If it does not work

- **"no agent answers to …":** run `tell.sh --list`, then use the exact name or id it shows.
- **"the Hermes gateway's API is not configured":** set `API_SERVER_ENABLED=true` and `API_SERVER_PORT` in Hermes's
  `.env`, then restart the gateway. Do this only while no Hermes turn is running.
- **"is busy: …":** Hermes is working in that session. Read `hermes-tell.sh --sessions` and try again when it shows
  `ready`.
- **HTTP 403:** `API_SERVER_KEY` is missing from Hermes's `.env`. Hermes will not continue a named session without it.
