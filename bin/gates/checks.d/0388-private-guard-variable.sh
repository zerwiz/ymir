#!/usr/bin/env bash
# private-guard-variable — the private ward reads $YMIR_HOME as design and still refuses a resolved
# path or a real realm.
#
# RULES/04 — a variable is the design; a RESOLVED path or a real name is the leak.
gate private-guard-variable "the private ward reads \$YMIR_HOME as design and still refuses a resolved path or a real realm" \
     bash "$ROOT/.agents/tests/private-guard-variable.test.sh"
