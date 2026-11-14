#!/usr/bin/env bash
# portability — GNU-only callers may fall, never rise (RULES/05).
gate portability "GNU-only callers may fall, never rise (RULES/05)"    bash "$ROOT/bin/gates/checks/portability-ratchet.sh" check
