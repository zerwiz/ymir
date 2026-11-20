#!/usr/bin/env bash
# push-road — a push costs minutes, not a quarter-hour, and is refused only for what it adds.
#
# PLAN 339.1 (2026-11-20). One push took over thirteen minutes and failed on four wards. The proof
# runs in a throwaway clone: the fork-point scope, commits-only judging, the budget wall, the masked
# mailbox, parking off until named, secret --range, the exec bit, the gate stamp, the NDA ward on
# added lines, and gather's catch-up of a moved base.
gate push-road "a push is judged once, on what it adds, inside its budget (plan 339.1)" \
     bash "$ROOT/bin/gates/checks/push-road.test.sh"
