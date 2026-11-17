#!/usr/bin/env bash
# arms-tell-deadline — a tell carries a deadline, and an unacked tell escalates instead of
# waiting for ever (plan 310 §5.4).
gate arms-tell-deadline "a tell carries a deadline, and an unacked tell escalates on it (plan 310)" \
               bash "$ROOT/bin/fleet/tests/test_arm_send.sh"
