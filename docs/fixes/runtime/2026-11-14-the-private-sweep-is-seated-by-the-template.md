# The private sweep is seated by the template

**Plan:** 275 / 287 (the agnostic law's own claim). **Date:** 2026-11-14.

## What was wrong

`AGENTS.md` and `RULES/04` / `RULES/25` (this branch, 2026-11-14) state that a whole-tree scan
for the operator's names, domains and hosts *"runs on the heart's clock twice a day and on every
push"*.

Both halves exist and both ship: the **gate** is `bin/gates/secret-scan.sh` (pre-commit and the
pull-request workflow), and the **clock** is `bin/time/nornir-job-private-scan.sh`. But neither
cron template carried the clock's two rows — `.agents/config/cron.yaml.example`, which seats a
fresh home's schedule, and `config/cron.yaml.example`, which the scheduler falls back to when a
home has no file. This fleet was swept because its own home's `config/cron.yaml` had the rows by
hand; **a new install would not be**, so the law as published was true here and false for every
stranger reading it.

## The fix

Both templates now carry the two rows — `@heart 06:10` and `@heart 18:10
bin/time/nornir-job-private-scan.sh` — with the division of labour written above them: the clock
queues a finding and seats one triage errand, the gate refuses the change. The Galdr asset
`nornir-jobs.md` records the job and the division, so the book and the schedule agree.

## How it was proved

- `bin/gates/guards/cron-guard.sh` passes on both templates (the ward judges every row's path,
  its execute bit and its shape).
- The rows are the same two the operator's own home has run since 2026-11-14.

## CHANGE LOG

- **2026-11-14** — written with the change it describes.
