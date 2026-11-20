#!/usr/bin/env bash
# plan-sync.sh — mirror a project's plan ledger onto its board, one card per plan (plan 335, phase 3).
#
#   plan-sync.sh --project <registry-id> [--dry-run] [--include-old]
#
# The ledger and the board are read from the project's row in the home's registry (its `board:` block);
# nothing about an installation is written here. The logic is plan_sync.py beside this file.
# Docs: docs/features/plan-sync.md
set -uo pipefail
HERE="${BASH_SOURCE[0]%/*}"
export YMIR_ROOT="${YMIR_ROOT:-$(readlink -f "$HERE/../..")}"
if [ -z "${YMIR_HOME:-}" ] && [ -r "$YMIR_ROOT/bin/vault/hoard-lib.sh" ]; then
  . "$YMIR_ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
  command -v ymir_home_root >/dev/null 2>&1 && ymir_home_root YMIR_HOME 2>/dev/null && export YMIR_HOME
fi
exec python3 -I "$HERE/plan_sync.py" "$@"
