#!/usr/bin/env bash
# nornir-day-gate — a WEEKLY schedule row actually fires.
#
# PLAN 305. `@heart Mon 09:15 …` was a shape Nornir did not understand: named in
# state/.cron-invalid and never fired, while --status still counted it declared. The day gate is
# now parsed by the same one parser the loop and the start-time warning share, and this gate
# proves the whole matrix on a fake clock: fires on its day, waits on every other, fires once,
# and a day it cannot read is named loudly instead of going silently dead.
gate nornir-day-gate "a weekly row fires on its day and a day Nornir cannot read is named (plan 305)" \
     bash "$ROOT/.agents/tests/nornir-schedule-shapes.test.sh"
