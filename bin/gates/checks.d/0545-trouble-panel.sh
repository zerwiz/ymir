#!/usr/bin/env bash
# trouble-panel — 2026-11-20 (plan 339.5): the house says it is in trouble before it is asked.
# Every planted fault is red and its healthy twin is not; a signal turning red is said once and a red
# that stays red is quiet; many at once are one line; Níðhöggr names a commit loop only above its
# line; the fleet reads every owed role over its road and never asks a dark machine.
gate trouble-panel "one trouble reading per machine, a notice only on the turn to red, a row per machine in the fleet" \
     bash "$ROOT/bin/ward/tests/test_trouble.sh"
