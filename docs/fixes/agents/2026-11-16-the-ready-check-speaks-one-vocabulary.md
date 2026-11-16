---
component: agents
date: 2026-11-16
plan: 303
step: 1
---

# The ready-check speaks one vocabulary, and names the dialog that would swallow the message

Plan 303 §12.3 step 1. the Allfather's word: *"build the system. don't stop before it works."*

## Why

The relay in §5 wakes an agent and then confirms it moved. It cannot do either without
one answer to one question: **can this target take a turn right now?** Nothing in the
tree could answer it.

- `bin/seat/agent-state-lib.sh` answers for herdr alone — `working`/`idle`/`done`/`unknown`
  — which is herdr's vocabulary, not the house's, and it knows nothing of Hermes.
- herdr says `blocked` for *every* dialog, so a pane standing on the Claude folder-trust
  prompt looked exactly like a pane standing on a permission form. A relay that injects
  into the first one types into a dialog and the message is gone with no error anywhere.
- Hermes has no pane at all. Its runtime records what it owes in `session_admissions`,
  and a session whose last turn may have run before the gateway died is paused with
  `unknown_execution` — a state that must be *reported*, never retried through.

Measured on this machine before writing anything: two panes (`w4E:p1`, `w4E:p2`) had sat
`blocked` on the folder-trust prompt, and `herdr agent explain` was the only place the
reason existed at all (`rule: live_blocked_form`, `evidence: "… Quick safety check: Is
this a project you created or one you trust? …"`).

## What changed

`bin/seat/agent-ready.sh`, a door over `bin/seat/agent-ready.py`. Four words for both
backends:

| answer | means |
|---|---|
| `ready` | the target can take a turn now |
| `working` | mid-turn; a message queues behind it |
| `blocked: <why>` | it exists and cannot take a turn — and this is the part a person acts on |
| `dead` | the target is not there |

- **herdr**: `agent get` for the state, `agent explain` for the reason. `blocked` is
  classified from herdr's own evidence text: the folder-trust signature becomes
  `blocked: trust prompt`; any other dialog is named by herdr's rule
  (`blocked: prompt (permission)`); an `idle` agent whose input box is not drawn is
  `blocked: not at an input prompt`, never `ready` (the launch fault of plan 291 row 5).
- **Hermes**: `hermes sessions list` is the directory, the runtime's own
  `session_admissions` table is the state (read `mode=ro`, by the last admission).
  `unknown` → `blocked: lost turn, run recover`; `queued`/`started` → `working`; a
  settled session → `ready`, because `hermes chat --resume` still takes a turn.
- **Targets**: a bare `<pane>` or `herdr:<pane>`; `hermes:<id-prefix-or-title>`. A bare
  target is herdr, so nothing that works today changes shape.
- **Exit codes** carry the same answer for a script: `0` ready · `1` working · `2` blocked
  · `3` dead · `64` usage · `65` the reader itself failed. Several targets answer with the
  worst of them — the one a person must act on.

One reader, one door: the shell door adds nothing, so the vocabulary is decided in one
file.

## Proof

```
$ bin/seat/agent-ready.sh w6T:p1          # a throwaway Claude pane started on a fresh folder
blocked: trust prompt
$ echo $?
2

$ bin/seat/agent-ready.sh w6S:p1          # the same probe, its trust prompt answered
ready
$ echo $?
0

$ AGENT_READY_HERMES_DB=/tmp/afa-hsnap/state.db bin/seat/agent-ready.sh \
    hermes:fd2ee4d0 hermes:9e11172e hermes:59087a9
hermes:fd2ee4d0	working
hermes:9e11172e	working
hermes:59087a9	ready
```

The two Hermes rows above were read from a snapshot of the live `state.db` taken at
15:05Z. Both of the Allfather's sessions were **mid-turn** at that moment, so the
paused reading (`blocked: lost turn, run recover`) is proved against a fixture of the
runtime's own table in `bin/seat/tests/test_agent_ready.sh`, not claimed from a live
session that could not be disturbed.

```
$ bash bin/seat/tests/test_agent_ready.sh
test_agent_ready: 19 passed, 0 failed
```

The test stubs `herdr` and `hermes` on `PATH`, keeps `HOME` and the Hermes store under a
temporary directory, and never types into a pane it did not start.

## What this does not do

It does not wake anything — that is step 4. It does not list the fleet — that is step 2.
It does not decide the Hermes headless road (§13.6 items 2 and 3 stay the Allfather's).

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #791
