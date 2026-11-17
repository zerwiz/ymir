---
component: bridge
date: 2026-11-16
plan: 303
step: 6
---

# The bridge names itself: harness, pane, and an address a peer can dial

Plan 303 §11 and §12.3 step 6, with §15.4's arrival rule.

## Why

Every session's A2A bridge was spawned with the same arguments: one bind address, no name, no
id, no state directory. Measured on this seat: two sessions on one box collided on the port,
the loser answered "Connection closed" with no card at all, and both shared one inbox so one
agent's mail was the other's.

Worse, the wrapper that WOULD have fixed it lived only in `~/.local/bin` on this seat — in no
repository, seated by no installer — so no other machine could ever have it. And where a name
was made, it was `brokk-<number>` with `model=pi`, whatever harness the bridge belonged to:
two agents of any other harness were indistinguishable and RULES/44 was broken by
construction. Every card advertised `127.0.0.1`, which no other machine can dial.

## What changed

`bin/bridge/a2a-bridge-session.sh` is the wrapper now, in the tree, and `bin/bridge/a2a-mcp.sh`
points every harness's `a2abridge` entry at it — so it arrives on install and after every
update.

- **identity**: `<harness>-<pane>` — `pi-w6R-p1`, `claude-w39-p23`, `hermes-…`. The harness is
  `A2A_HARNESS`, else detected from the session's own environment, else `unknown`. A harness
  that cannot be named is `unknown`, never `brokk`.
- **address**: the name the fleet registry gives this machine. The bind is that name's own
  address where it resolves here, every interface where it does not, and loopback only on a box
  that advertises loopback — a card that names an address nobody can dial is the fault this
  step exists to end.
- **one inbox per session**: the state dir is `…/state/<id>`.
- **a port without a graveyard**: a reservation whose `pid` is gone is swept before the span is
  exhausted, so a bridge can always start. Measured before the fix: `8393` and `8394` named
  pids that no longer existed.
- `--identity` prints who the bridge will be; `--dry` prints the exact argv and claims nothing.

## Proof

```
$ HERDR_PANE_ID=w6R:p1 bin/bridge/a2a-bridge-session.sh --identity
a2a-bridge[7]{harness,name,id,bind,advertise,state,skills}:
  "pi","pi-w6R-p1","pi-w6R-p1","<this machine's tailnet address>","<this machine's registry name>","…/state/pi-w6R-p1","ymir,agents-find-and-answer"

$ HERDR_PANE_ID=w39:p23 A2A_HARNESS=claude bin/bridge/a2a-bridge-session.sh --dry
… -name claude-w39-p23 -id claude-w39-p23 -bind <this machine's tailnet address>:8391
   -advertise-host <this machine's registry name> … -model claude
```

```
$ bash bin/bridge/tests/test_a2a_bridge_identity.sh
test_a2a_bridge_identity: 11 passed, 0 failed
```

The test proves the four claims a person cannot check by eye: a pi session is `pi-<pane>`, a
claude session is `claude-<pane>` and never `brokk`, an unnameable harness is `unknown`, a
fleet seat advertises its registry name and never loopback, a box with no registry advertises
loopback, `--dry` claims no port, and a dead reservation is released.

**Not proved here**: a card actually being dialled from another machine. That is step 7's
proof (`a2a-prove.sh`), because a card that answers is not a node that answers.

## What this does not do

It does not replace a2abridge with anything, and it does not retire the announce road — that
is step 9's business and the plan's P6. It does not carry Hermes sessions (§14, step 9).

## CHANGE LOG

- 2026-11-16 — review-mend: added missing heading for #796
