# eir-register — Eir reads config/surfaces.yaml, mends only safe surfaces unattended, and never
# leaves a broken row without a reason.
#
# Plan 278 — an update finishes the installs.
gate eir-register "Eir reads config/surfaces.yaml, mends only safe surfaces unattended, and never leaves a broken row without a reason" \
     bash "$ROOT/bin/agents/tests/test_eir_register.sh"
