# The skill smoke: a skill that teaches a gone command is named

**Date:** 2026-11-22 · **Component:** agents (`bin/agents/skill-smoke.sh`) · **Plan:** 350 part D

## What was wrong

A skill tells an agent which commands to run. When a door moves or a CLI verb is renamed, the skill keeps teaching
the old one, and nothing checks it. On the night of 2026-11-21 an agent followed `smidja teams` after the verb had
become `smidja team list`.

## What was built

- `bin/agents/skill-smoke.sh` reads every `SKILL.md` on a shelf. For each command a skill names, it checks one of
  two things. A path (`bin/…/x.sh`, `scripts/…`, `.agents/…`) must exist, and a shell door must be executable. A
  `<cli> <verb>` must be named in the CLI's `--help`, for the CLIs in `SKILL_SMOKE_CLIS` (default `smidja herdr`).
  Nothing a skill names is run, so it is safe on the clock.
- A skill naming a gone command is `GONE`, with the command. A skill naming none is `none`, a note rather than a
  fault. `--notify` sends the GONE list to the arm holder through the Veil.
- The cron template now carries the checks on the clock:
  - `skill-find.sh --check`, daily on the heart.
  - The skill smoke, weekly.
  - Dellingr's read-only grade of the knowledge shelf, weekly. The plan asks for monthly, and the clock has no
    monthly shape.
- The `where.sh` coverage on every PR already runs as `subsystem-docs-guard`. The library of modes (plan 347) is
  not yet built, so it has no row.

## What it found on its first run

Seven shipped skills teach `bin/brokk-*.sh` doors that no longer exist: `eindri-homes`, `gjallarhorn-relay`,
`hvild-afk`, `jord-projects`, `muninn-stow`, `syn-recovery` and `vor-diagnostics`. Rewriting them is each skill's
own change, so they are named here, not changed.

## Proof

- `bash bin/agents/tests/test_skill_smoke.sh` — 6 passed.
- The gate row `skill-smoke` (`bin/gates/checks.d/0549-skill-smoke.sh`) runs it.
