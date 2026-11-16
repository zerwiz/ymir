# Hermes in the loop — two shapes, one vocabulary

## What it is

Hermes is a worker harness, like pi and Claude, and Ymir reaches it two ways.

**A Hermes agent in a pane** is an ordinary pane agent. herdr seats it with
`herdr agent start <name> --kind hermes --pane <id>`, and from there the ready check, the
queue and the relay treat it exactly like any other agent: it is woken, it answers, and its
answer comes back to whoever asked.

**A Hermes session behind a gateway** has no pane. It is addressed by its session id (or a
prefix of it, or a title), and its state comes from the runtime's own admissions table — so a
session whose last turn may have run before the gateway died shows as
`blocked: lost turn, run recover`, never as ready.

## What you need

- Hermes installed (`hermes --version`). Ymir guarantees the runtime exists; it never touches
  your profile or your keys.
- For the pane road: herdr, which offers the `hermes` kind.
- For a session: a configured Hermes profile. A profile with no API keys stops at
  `hermes setup` — that is Hermes asking you, not Ymir refusing.

## Do it

Ask what a Hermes session can do right now:

```bash
bin/seat/agent-ready.sh hermes:fd2ee4d0
bin/seat/agent-ready.sh "hermes:Audit vaults"
```

The answer is one of the house's four words, and a paused session says what to do:

```
blocked: lost turn, run recover
```

See every Hermes session on the machine beside every pane:

```bash
bin/seat/agent-ready.sh --all
```

Send a task to an agent standing in a pane — including a Hermes one — through the queue:

```bash
bin/bridge/ratatoskr.sh send herdr:w1:p2 "summarise the open pull requests"
```

The relay wakes it, and the answer returns to your own pane under a header.

Prove the loop end to end, with a nonce:

```bash
bin/bridge/a2a-talk.sh prove --live w1:p2 w1:p3 --nonce cafebabe
```

## Limits — and these are deliberate

- **A throwaway Hermes profile needs its own keys.** Measured: an isolated `HERMES_HOME` boots
  its own runtime and stops at `hermes setup`. So a proof against a *throwaway* Hermes is not
  run here; the round trip is proved between throwaway agents in panes instead.
- **The headless road is stated, not claimed.** There is no `hermes mcp serve` in v0.22.6;
  MCP comes from `hermes plugins install mcp-serve`. Switching that on, or the API server, is
  the operator's decision and Ymir does not make it.
- A paused session is **never** resumed by a tool. `run recover` means a person recovers it;
  sending into it would replay a turn nobody saw.

## If it does not work

- `dead` for a session you can see in the Hermes app — the id prefix did not resolve. Hermes
  ids are `local-<hex>`; quote any unique part of it, or part of the title.
- `blocked: hermes store unreadable` — the Hermes home is not where this seat looks. Check
  `~/.hermes/state.db` exists and is readable.
- A pane that will not start Hermes at all — the throwaway shows why: an unconfigured profile
  stops at setup. Run `hermes setup` in your own profile.

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 8).
