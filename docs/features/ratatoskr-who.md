# Who is there — every agent on every machine, read from what is alive

## What it is

`bin/bridge/ratatoskr.sh who` is the house's directory. It lists every agent standing
right now on this machine, and on every machine the fleet registry names, with its
harness, its pane, its state and whether it holds the arm.

Nothing has to announce itself. herdr already knows the panes, and a pane that is gone
disappears from its list by itself — so the directory cannot go stale, because there is
nothing cached in it to go stale.

A machine that does not answer is not left out. It is a row saying `dark`, with the road
that failed, because "no agents there" and "nobody could ask" are different claims and
only one of them is true.

## What you need

- herdr running on this machine, and on the machines you want to see.
- An ssh road to each fleet machine, as `bin/fleet/roads.sh` seats it.
- `python3`.

## Do it

Everything, everywhere:

```bash
bin/bridge/ratatoskr.sh who
```

One row per agent:

```
who[28]{machine,harness,pane,name,state,arm,road}:
  "heimdall","claude","w39:p23","Crashed Claude session recovery","working","yes","local"
  "heimdall","claude","w6T:p1","afa-probe-trust2","blocked: trust prompt","no","local"
  "a-second-machine","pi","w2:pA","a worker","working","no","tailnet"
  "a-third-machine","-","-","-","dead","-","dark: the road answered nothing"
```

Read it like this:

- **machine** — which box the pane is on.
- **harness** — `claude`, `pi`, `hermes`, `codex`, whatever herdr detected.
- **state** — the same four words the ready check answers with: `ready`, `working`,
  `blocked: <why>`, `dead`.
- **arm** — `yes` on the one pane that holds this machine's arm.
- **road** — `local`, `tailnet`, or `dark: <why>`.

Only this machine:

```bash
bin/bridge/ratatoskr.sh who --local
```

Only one machine:

```bash
bin/bridge/ratatoskr.sh who --machine a-second-machine
```

For a script, `--json` prints the same rows as objects with `machine`, `harness`, `pane`,
`name`, `state`, `arm` and `road`.

## Limits

- The directory is only as wide as the fleet registry. A machine that is not in
  `hodd/data/fleet.json` is never asked.
- On a far machine the reason behind a `blocked` is not carried over the road: the row
  says `blocked: dialog`. Run `bin/seat/agent-ready.sh <pane>` on that machine for the
  reason.
- Hermes sessions are not rows here yet. A Hermes session has no pane; it is listed once
  the Hermes backend lands.
- It reads. It never sends, wakes or steers.

## If it does not work

- `ratatoskr-who: herdr did not answer on this machine` — herdr is not running. Raise it
  and ask again. The door refuses rather than printing an empty directory.
- A `dark` row that should not be dark — check the road itself:
  `bin/fleet/roads.sh check` names which machines answer and which are dark.
- `(the arm)` in a row with `dead` — the arm holder's named pane holds no agent herdr can
  see. A wake sent there goes to a shell; re-seat the arm.

## CHANGE LOG

- **2026-11-16** — written with the change it describes (plan 303 §12.3 step 2).
