#!/usr/bin/env bash
# THE REVIEWER'S ITEM 1 (2026-11-12) — the door that writes main's branch protection must first read all of
# it. `require-check.sh` defaulted to a check named `gates` while main's required context is
# `whole-tree`, so `--apply` would have replaced the only check guarding main with a name GitHub has
# never seen. This gate holds the door to that: it adds, never replaces, and never quietly re-arms
# "require branches to be up to date" (turned off on purpose 2026-11-15, plan 295 §S2).
gate the-door-keeps-the-checks "require-check.sh adds a required check without dropping or re-arming one" \
     bash "$ROOT/bin/gates/tests/test_require_check_keeps_the_checks.sh"
