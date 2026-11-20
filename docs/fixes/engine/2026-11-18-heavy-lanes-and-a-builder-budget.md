# One heavy job was read as one builder — the lanes are now counted, and the builder budget is its own number

**Date:** 2026-11-18 · **Component:** engine (`bin/heavy-slot.sh`) and agents
(`bin/agents/builder-budget.sh`, `bin/agents/einherjar-spawn.sh`) · **Errand:** `heavy-lanes`

## What was wrong

At the Allfather's word: *"we need to make a thing for zerwiz server we can only have one builder at the
time. here. … we need to update the runbooks in ymir home. the server can handle more builders."*

The house had one sentence for two different costs. `bin/heavy-slot.sh` (built 2026-11-17 after the box died
at 07:20:59) is an **exclusive** machine-wide lock: one heavy job, and the second waits. The runbook written
around it then said the same thing about **workers** — the home contract's law 7, its `dispatch_law` row
*"one heavy lane per machine"*, the heart's `updating.md` law 1, and step 5 of
`hodd/docs/runbooks/developing-with-the-heart.md`. Read together they said: this machine carries one builder.

That is not what the night taught. Three errands did not kill the box by existing; **the builds inside them
did** — a dependency install, a full application build, a type-check, each a peak-memory event. An agent is a
few hundred megabytes and mostly waiting. Measured on the heart while this note was written: 11.6 GiB
total, 6.8 GiB available, 8 cores — a box that can hold several agents and only a couple of builds.

## What was built

| door | what changed |
|---|---|
| `bin/heavy-slot.sh` (2.0.0) | the exclusive lock became **counted lanes**: `lanes` resolves `YMIR_HEAVY_SLOTS` → this host's own `lanes` in the home's fleet registry → 1, and `run` takes the lowest free lane, naming every holder when all are held |
| `bin/agents/builder-budget.sh` (new) | `read` · `status [--json]` · `check` — the machine's `builders` number, the builders standing, and the room left |
| `bin/agents/einherjar-spawn.sh` | prints `builder-budget,full,…` when a machine is at its budget; refuses only under `YMIR_BUILDER_BUDGET_ENFORCE=1` |
| gates | `heavy-slot` re-aimed at counted lanes · new gate `builder-budget` |
| docs | `docs/features/heavy-slot.md` corrected · new `docs/features/builder-budget.md` · both catalogue fragments · the runtime asset |

**The numbers are the machine's, not the repo's** (Rule 07 · Rule 25). Nothing here hardcodes a lane count:
lane 1 keeps the original lock path, so an existing single lock **is** lane 1 and an old caller and a new one
cannot disagree; lane N is `heavy-slot.<N>.lock` beside it. The heart's own row in the home's fleet registry
now carries `lanes: 2` and `builders: 4` in this host's own row.

**Who counts as a builder** is a rule, not a guess: an agent standing in a Yggdrasil worktree
(`…/.yggdrasil/<errand>`), because an errand *is* that. The helm in the main hall is not an errand. The list
comes from `herdr agent list` through its one reader (`bin/seat/herdr-agents.py --tsv`), so two doors cannot
disagree about who is standing.

**A door that cannot answer is `unknown`, never zero.** No registry row, an unreadable registry, or a herdr
that cannot speak all exit 4 and say so — the false green this house has paid for twice.

## The proof

```bash
$ bin/heavy-slot.sh lanes
lanes[1]{count,source}:
  "2","the fleet registry's own row"

$ bin/heavy-slot.sh status
lane[2]{lane,lock,state,pid,name,started,running}:
  "1",".../heavy-slot.lock","free","","","",""
  "2",".../heavy-slot.2.lock","free","","","",""

$ bin/agents/builder-budget.sh status
budget[1]{host,builders,source}:
  "<the host>","4","the fleet registry's own row (hosts.<the host>.builders)"
standing[1]{count,why}:
  "0","agents standing in a Yggdrasil worktree, per herdr agent list"
room,4,this machine may take 4 more builder(s)
```

Both gates are green on this machine, 2026-11-18:

```
heavy-slot: 20 passed, 0 failed      # was 15; +5 lane assertions
builder-budget: 9 passed, 0 failed
```

The five new `heavy-slot` assertions prove the part the old test could not: two lanes let two heavy jobs run
**beside** each other (`b` lands in the order while `a` still sleeps, and `b` never prints `SLOT,waiting`),
both lane files are given back, a third job with both lanes held is refused (exit 3) and **names both
holders**, and `status --json` reports the machine's lane count.

## What this does not decide

- **The builder refusal is off by default.** `bin/agents/einherjar-spawn.sh` is the one road that raises
  every worker in the house, and this session did not hold the lock, so no spawn was raised to prove a
  refusal there. The advisory line is proved by the door's own gate and by `bash -n`; the hard refusal waits
  for a real spawn on this machine and a second one from a release.
- **Whether 2 lanes and 4 builders are the right numbers for this box.** They are the operator's declared
  headroom, written in his own registry row; the doors report what the row says, they do not second-guess it.
- **What is still heavy.** The slot does not police it. A door that never asks for a lane still runs beside
  everything else.

## CHANGE LOG

- 2026-11-18 — written with the change, at the Allfather's word.
