#!/usr/bin/env bash
# 0010-logretta-stack — seat the council's roster on an existing home.
#
# Rule 25: "a move is a migration" — and by the same reasoning, a NEW capability that
# needs a file in the home is not installed until the home has it. The council
# (plan 92) ships in `.pi/extensions/logretta/`; without a stack it is a loud skip.
#
# This migration only calls the ensure door, which:
#   · copies the TEMPLATE to <home>/config/logretta-stack.yaml when ABSENT
#   · never overwrites an existing stack (the models on it are the operator's)
#   · validates it with the extension's own parser
#
# Idempotent: a home that already carries a valid stack is told so and nothing is written.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

ENSURE="$ROOT/bin/pi/logretta-ensure.sh"
if [ ! -x "$ENSURE" ]; then
  printf '0010-logretta-stack[1]{state}:\n  "skip","bin/pi/logretta-ensure.sh is not present"\n'
  exit 0
fi

"$ENSURE" ensure
