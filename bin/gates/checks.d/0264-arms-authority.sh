#!/usr/bin/env bash
# arms-authority — a spawn says which authority it used, and is refused by name when it has
# none (plan 310 §5.3).
gate arms-authority "a spawn names the lease or the arm it acted under, and is refused with neither (plan 310)" \
               bash "$ROOT/bin/voice/tests/test_arm_authority.sh"
