#!/usr/bin/env bash
# arms-lease — the lease is a file, not a feeling: written, renewed, and reclaimed by the
# machine without asking anyone once its heartbeat stops (plan 310 §4).
gate arms-lease  "a lease is written, renewed, and reclaimed by the machine when its heartbeat stops (plan 310)" \
               bash "$ROOT/bin/voice/tests/test_arm_lease.sh"
