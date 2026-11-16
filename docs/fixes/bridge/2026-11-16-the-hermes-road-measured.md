---
component: bridge
date: 2026-11-16
plan: 303
step: 8
---

# The Hermes road: the pane is proved, the headless road is stated

Plan 303 §12.3 step 8 and §13.4.

## What was measured, and what it means

Hermes has two shapes, and they are not the same road.

**A Hermes agent in a pane** is reached exactly like any other agent: `herdr agent start …
--kind hermes` seats it, and from there the ready check, the queue and the relay treat it as
a pane. Measured here: `herdr agent start --help` offers `hermes` among its kinds, and
`hermes sessions list` answers.

**A Hermes session behind a gateway** has no pane at all. It is addressed by session id, and
its state is the runtime's own admission — `unknown` means a turn may have run before the
gateway died, and Hermes will not resume without being told. That is
`blocked: lost turn, run recover`, and `bin/seat/agent-ready.sh` already answers it.

**A throwaway Hermes profile cannot be started here without the operator's keys.** Measured:
an isolated `HERMES_HOME` in a pane bootstraps its own runtime and then stops at
`It looks like Hermes isn't configured yet -- no API keys or providers found. Run: hermes
setup`. Configuring that profile would mean putting the operator's credentials in a scratch
directory, which is his decision, not a worker's. So the throwaway-Hermes half is **unproved**
and is recorded as unproved rather than described as working.

**The headless road is stated, not claimed.** There is no `hermes mcp serve` in v0.22.6 —
MCP arrives only through `hermes plugins install mcp-serve`, and switching that (or the API
server) on is §13.6 items 2 and 3, the operator's decisions. This step does not decide them.

## What is proved instead

The **round trip the pane road rests on** was proved live on this machine, twice, with
throwaway agents in panes this worker owned:

```
$ bin/bridge/a2a-talk.sh prove --live w6W:p1 w6X:p1 --nonce cafebabe
proof[4]{door,ok,evidence}:
  "queue","proved","task 1794845069-cnee5v moved inbox → claimed → done, nonce intact"
  "relay","proved","the relay answers status with its counts"
  "arm","proved","a machine the registry does not know is refused by name"
  "live","proved","the round trip came back with the nonce intact"
```

and, before that, ten tasks between three throwaway agents: ten wakes, ten answers, ten
returns, no polls, no misses.

```
$ bash bin/bridge/tests/test_hermes_road.sh
test_hermes_road: 5 passed, 0 failed
```

The test asserts the four facts a person cannot check by eye — that this herdr can seat a
Hermes agent, that Hermes answers its own sessions door, that a Hermes session answers in the
one vocabulary, and that an unknown session is `dead` rather than guessed — and it asserts the
fifth by absence: **there is no `hermes mcp serve` here**, so the headless road stays stated.

## What is owed, and to whom

The Allfather: a throwaway Hermes profile with its own keys (or his word that the two live
sessions may be used for the A→B→A between a Hermes and a Claude), and the §13.6 decisions on
the API server and on bots-versus-sessions. Until then a Hermes agent is addressed by pane,
which works today, and by session, which the ready check already answers for.
