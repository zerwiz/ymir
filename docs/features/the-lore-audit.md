# The lore audit — does every system the saga tells of have a working door?

The saga and the homepage name about forty systems. The lore audit measures each one against the door that should
keep it, on your machine, and says which are true.

## What you need

Nothing beyond the repo. For the weekly watch, add the row `@heart Mon 09:30 bin/records/lore-audit.sh watch --notify`
from `config/cron.yaml.example` to your home's `config/cron.yaml`.

## The commands

```bash
bin/records/lore-audit.sh run                       # a Markdown table: every system, its door, command, output, verdict
bin/records/lore-audit.sh run --json                # the same, one JSON line per system
bin/records/lore-audit.sh run --out <file>          # and keep it
bin/records/lore-audit.sh watch --notify            # measure, and tell the arm holder what turned false
```

| Verdict | Meaning |
|---|---|
| true | the door exists and its command bore the claim out |
| partial | the door exists, but its command did not bear the claim out tonight |
| false | there is no door |
| planned | the house records the system as not yet built |

## The claims

Each row of `docs/lore-claims.tsv` holds the system, the claim in the saga's words, the door, one read-only
command, and the regex its output must match (or `rc0`). Add a row when the saga gains a system.

## Limits

- A true row proves the door answered its probe, not every word of the saga's sentence.
- A probe runs on this machine. A system that lives on another machine (the heart's tunnels, the A2A card) reads as
  partial here, and its row says so in the audit.

## If it does not work

- A row is partial and should not be: run its command by hand from the repo root, and read the output.

## CHANGE LOG

- **2026-11-22** — written with the lore audit (plan 350 A).
