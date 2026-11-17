#!/usr/bin/env bash
# arms-speak — only a session that can speak may hold an arm, and a watcher is not a speaker
# (plan 310 §1).
#
# The definition lives ONCE, in bin/voice/arm-speak-lib.sh, so the arm door and the heart's own
# guard cannot drift: a live harness whose own transcript is fresh, or a refusal by name.
gate arms-speak  "only a session that can speak may hold an arm — a watcher is refused by name (plan 310)" \
               bash "$ROOT/bin/voice/tests/test_arm_speaks.sh"
