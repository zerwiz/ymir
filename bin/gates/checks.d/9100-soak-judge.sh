#!/usr/bin/env bash
# PLAN 293 part 7 — a worker cut from another unmerged branch records that branch in its packet, and
# the gather merges the base FIRST. Gathered in the wrong order the dependent lands before its base.
gate soak-judge "the leak soak's registry, desk guard, PR mapping and verdict all bite" \
     bash "$ROOT/bin/gates/tests/test_soak.sh"
