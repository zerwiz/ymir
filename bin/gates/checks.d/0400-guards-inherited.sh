#!/usr/bin/env bash
# THE GATE'S OWN DECISION, PROVED (2026-11-14): a ward's finding belongs to a push only when it names
# THIS checkout's copy of a path, never when it names a neighbour checkout's copy of the same script.
gate guards-inherited "a finding in a neighbour checkout is inherited, and a finding in ours is not" \
     bash "$ROOT/bin/gates/tests/test_guards_inherited.sh"
