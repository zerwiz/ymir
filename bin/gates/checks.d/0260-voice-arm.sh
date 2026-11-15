#!/usr/bin/env bash
# voice-arm — Rödd knocks on the arm, and refuses when nobody is holding it (plan 223).
gate voice-arm   "Rödd knocks on the arm, and refuses when nobody is holding it (plan 223)" \
               bash "$ROOT/bin/voice/tests/test_rodd_arm.sh"
