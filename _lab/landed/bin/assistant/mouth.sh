#!/usr/bin/env bash
# bin/assistant/mouth.sh -> systems/skirnir/services/mouth.sh — RETIRED SHIM (plan 149, 2026-10-31); execs the new door and says so.  # allow-superseded-path: this header RECORDS the move, it does not make it
#
# It exists so a caller nobody has repointed yet still works. It is retired by the dated follow-up in
# docs/fixes/assistant/2026-10-31-skirnir-becomes-a-system.md, and .agents/paths-ledger.yaml records the move.
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_d/../.." && pwd)"
_new="$_root/systems/skirnir/services/mouth.sh"
if [ ! -e "$_new" ]; then
  printf 'skirnir: the door moved to systems/skirnir/services/mouth.sh and is not there\n' >&2
  exit 127
fi
printf 'skirnir: bin/assistant/ has MOVED to systems/skirnir/ — call systems/skirnir/services/mouth.sh (plan 149)\n' >&2
exec "$_new" "$@"
