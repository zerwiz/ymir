# The builder budget — how many builders one machine carries

A **builder** is an agent at work on an errand: it has its own Yggdrasil worktree, its own seat and its own
brief. The builder budget is the number of builders a machine is willing to have standing at once. It is
**the machine's own number**, recorded in its row in the home's fleet registry, and read by one door:
`bin/agents/builder-budget.sh`.

This is the other half of the heavy slot. A heavy job — a build, a type-check, a gate suite — takes a lane
and costs peak memory for as long as it runs (see `docs/features/heavy-slot.md`). A builder is much cheaper:
a few hundred megabytes, most of it waiting. Counting them together is what made the house believe one
builder was the limit of a server that can carry several.

## What it is for

On 14 November 2026 three errands dispatched within one minute took this machine down at load 492. The cure
written down afterwards bundled two different costs into one sentence — *one heavy job at a time* — and the
house read it as *one builder*. On 18 November the Allfather corrected it: *"we can only have one builder at
the time. here. … the server can handle more builders."*

So the budget is one number per machine, and the queue for heavy work is another.

## What you need

- the home on the machine (`$YMIR_HOME`), because that is where the number lives;
- a row for the machine in `$YMIR_HOME/hodd/data/fleet.json` carrying `"builders": <n>`.

That is the whole configuration. Nothing in the repository hardcodes how many builders a box may hold.

## The commands

```bash
bin/agents/builder-budget.sh read            # the number, and where it came from
bin/agents/builder-budget.sh status          # budget · builders standing · room
bin/agents/builder-budget.sh status --json   # the same for a machine reader
bin/agents/builder-budget.sh check           # exit 0 with room, 3 when the budget is full
```

`status` names the builders it counted — pane, state and errand — so the number is never a mystery.

## Who counts as a builder

An agent standing in a Yggdrasil worktree (`…/.yggdrasil/<errand>`), because an errand *is* that: its own
worktree, its own seat. The helm sitting in the main hall is not an errand, and the machine's own keeper is
not one either. The list comes from `herdr agent list` through the one reader of it
(`bin/seat/herdr-agents.py`), so two doors cannot disagree about who is standing.

## Limits

- **The number is not a measurement, it is the operator's declared headroom.** The door reports what the
  registry says; it does not decide whether that number is wise on this box tonight.
- **A door that cannot answer is `unknown`, never zero.** Where herdr cannot answer, or where the machine
  has no row, `status` and `read` exit 4 and say so — a green that hides an unmeasured machine is the false
  green this house has paid for twice.
- **A spawn is warned, not refused, by default.** `bin/agents/einherjar-spawn.sh` prints a
  `builder-budget,full,…` line when the machine is at its budget. It refuses only when
  `YMIR_BUILDER_BUDGET_ENFORCE=1`, because that line raises every worker in the house and a refusal there
  must be proved by a real spawn on a real machine first.
- **Per machine, per user.** Like the heavy slot, this is a local limit, not a fleet-wide one.

## If it does not work

- *It says `unknown` and exits 4.* Either the machine has no row in the fleet registry, or the registry
  cannot be read. Add `"builders": 4` to the machine's row, or pass `YMIR_BUILDER_BUDGET` for one command.
- *It counts fewer builders than there are agents.* That is the rule, not a fault: agents outside a
  worktree are the helm and the keeper, and they are not builders.
- *You raised the number and nothing changed.* The number is read per command, so a spawn already running
  is unaffected; the next spawn sees the new row.

## CHANGE LOG

- **2026-11-18** — written with the door it describes, at the Allfather's word.
