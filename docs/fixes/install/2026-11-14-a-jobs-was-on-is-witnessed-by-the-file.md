# A Nornir job's `was_on` is witnessed by the file, not by a clock

**Date:** 2026-11-14 · **Component:** install · **Door:** `.agents/migrations/0024-wardens-off-until-named.sh`

## What was wrong

The migration asked systemd whether each door's clock was running, which is right for a timer and
impossible for a Nornir job: `gna-mail`, `snotra-mail`, `git-sync` and `private-scan` are seated by a cron
row, not by a `.timer`. So the two mail jobs — which this machine *was* running — were turned off with no
`was_on` line, and the operator would have had no record that they had ever run.

## What changed

For a job, the file is the witness: a migration-written `enabled: on` (the 0023 record) means the old
install was running it, so that value now records `was_on: <date>` before it is turned off. No new state is
invented — the record comes from what a migration had already written down.

## Proof

`bin/gates/tests/test_wardens_off_until_named.sh` — 35 cases, still green (`was_on` counted as
`^  was_on:`, so the header's prose about the key is not mistaken for a record). On this machine the file now
carries eight `was_on` rows: the six timers that were active, plus `gna-mail` and `snotra-mail`, whose witness
was the 0023 record and whose comment says so.

## CHANGE LOG

- 2026-11-14 — written with the change.
