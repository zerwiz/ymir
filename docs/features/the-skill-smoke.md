# The skill smoke — a skill may not teach a command that is gone

A skill tells an agent which commands to run. The skill smoke checks that every command a skill names still exists,
so an agent never follows a door that moved or a verb that was renamed.

## The command

```bash
bin/agents/skill-smoke.sh                      # every skill on the shipped shelf: ok, GONE, or none
bin/agents/skill-smoke.sh --shelf <dir>        # another shelf (the home's, harness-wide)
bin/agents/skill-smoke.sh --notify             # and tell the arm holder what is gone
```

| State | Meaning |
|---|---|
| ok | every path and CLI verb the skill names exists |
| GONE | at least one is gone; the row names it |
| none | the skill names no command (a note, not a fault) |

A path must exist in the tree, and a shell door must be executable. A `<cli> <verb>` must be named in the CLI's own
`--help`; the CLIs read are `SKILL_SMOKE_CLIS` (default `smidja herdr`). Nothing a skill names is run.

## On the clock

The cron template runs `skill-find.sh --check` every day, the smoke every Monday, and Dellingr's read-only grade
of the knowledge shelf every Sunday.

## If it does not work

- A skill is GONE: change the skill to the door's new path (`bin/records/where.sh <old path>` and the path ledger
  name moves), in the skill's own change.

## CHANGE LOG

- **2026-11-22** — written with the skill smoke (plan 350 D).
