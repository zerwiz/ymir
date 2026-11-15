# agents · 2026-11-09 · The pane door was built, and never called

## What

`bin/agents/eindri-notify.sh` exists to speak a line into the session that holds the arm. It was built on
2026-11-08 at the Allfather's word — and on 2026-11-09 it reported:

```
arm-holder[1]{lock_owner,alive,pane}:
  "324636","yes","NOT FOUND"
```

Two faults, both invisible because nothing measured the door:

**1 · Nothing called it.** `bin/agents/eindri-acclaim.sh` — the terminal act of every errand — wrote the
status line, the report shelf and the wake, and stopped there. `bin/agents/erindi-brief.sh` never told a
worker that a file-only report has reached nobody. So every errand in flight reported into shelves and the
arm holder read panes.

**2 · Its resolution could not find the pane.** It matched the lock's pid against each pane's
`process-info`. The lock names a SESSION pid; the pane runs `pi` under a different pid. So even a caller
would have got "NOT FOUND" — and the refusal, printed to stderr, was easy to miss among green rows.

## Why

A door that nobody calls and cannot resolve is the same class of fault as the stale `Host` block that beat
a correct one in `~/.ssh/config`, or the deploy script that verified a build nobody served: the mechanism
existed, the wiring did not. And the wiring was never proved because no test ran the door end to end.

## The fix

- `eindri-acclaim.sh` now **injects** through the door as part of its terminal act, and prints
  `eindri-acclaim[4]{agent,kind,detail,pane}` with `pane":"injected — w2:p3"` or `pane":"failed — <why>`.
  A failed delivery is loud and named, never silent.
- `eindri-notify.sh` resolves the pane in declared order: **(0)** `state/.arm.pane`, the pane the arm holder
  names for itself; **(1)** the lock pid; **(2)** the lease's session id. It says which link answered
  (`via`), so the next fault is one line away.
- `erindi-brief.sh` teaches every errand the rule: *a report that lands in a status line, a shelf and a
  queue has reached three shelves and no person.*
- `RULES/49` is written: **no message is delivered until the receiver speaks.** The only proven channels
  are the herdr pane and the Gna arm; a new channel is guilty until its proof command answers.

## Proof

```
$ bin/agents/eindri-notify.sh --status
arm-holder[2]{lock_owner,alive,pane,via}:
  "324636","yes","w2:p3","the arm holder named its pane (/home/zerwizserver/Documents/ymirhome/state/.arm.pane)"

$ bin/agents/eindri-notify.sh --from arm-voice-test -- "the pane door now resolves: this line is the proof"
injected[1]{from,pane,owner}:
  "arm-voice-test","w2:p3","324636"
```

And the line arrived in the arm holder's chat as a turn — which is the only proof this rule accepts.

## Owed

The arm holder does not yet write `state/.arm.pane` itself at session start; the file was written by hand
tonight. A Pi extension on `session_start` is the durable half, named in plan 234 P2.

## Correction 2026-11-14 — the machine and person names above are roles

Under the agnostic law (`AGENTS.md`, `RULES/04`, `RULES/25`) the machine and person names above are
read as roles: the fleet's always-on heart. The entry above is append-only (`RULES/06`), so it stands exactly as
it was written and this correction is added, not a rewrite — that is why no name is repeated here.
Whether the old lines are ever redacted is the Allfather's decision.

- **2026-11-14** — dated correction appended: the names above are read as roles (plan 288 step 8).

## CHANGE LOG

- 2026-11-14 — review-mend: added missing heading for #758
