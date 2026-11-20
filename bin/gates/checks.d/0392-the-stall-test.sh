#!/usr/bin/env bash
# the-stall-test — a working errand that stops MOVING is caught, once, and Rödd tells the operator.
#
# The fault (2026-11-20): two errands sat 8h45m and 1h50m on one command and the liveness sweep
# judged both ALIVE, because an agent still stood in the pane. A pane can be alive and frozen at
# once. The runbook section "When a worker is stuck — the arm watches, Rödd speaks" is the
# contract; this gate holds the door that carries it.
gate the-stall-test "a working errand that stops moving is caught once, steered once, and told to the operator once" \
     bash "$ROOT/bin/agents/tests/test_eindri_stall.sh"
