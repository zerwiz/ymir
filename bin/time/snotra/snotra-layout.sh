#!/usr/bin/env bash
# bin/time/snotra/snotra-layout.sh -> systems/snotra/services/record/snotra-layout.sh — RETIRED SHIM (plan 129, 2026-10-24); execs the new door and says so.  # allow-superseded-path: this header RECORDS the move, it does not make it
#
# It exists so a caller nobody has repointed yet still works. It is retired by the dated follow-up in
# docs/fixes/snotra/2026-10-24-snotra-becomes-a-system.md, and .agents/paths-ledger.yaml records the move.
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_d/../../.." && pwd)"
_new="$_root/systems/snotra/services/record/snotra-layout.sh"
if [ ! -e "$_new" ]; then
  printf 'snotra: the door moved to systems/snotra/services/record/snotra-layout.sh and is not there\n' >&2
  exit 127
fi
printf 'snotra: bin/time/snotra/ has MOVED to systems/snotra/ — call systems/snotra/services/record/snotra-layout.sh (plan 129)\n' >&2
exec "$_new" "$@"
