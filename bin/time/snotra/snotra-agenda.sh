#!/usr/bin/env bash
# bin/time/snotra/snotra-agenda.sh -> systems/snotra/services/cron/snotra-agenda.sh — RETIRED SHIM
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_d/../../.." && pwd)"
_new="$_root/systems/snotra/services/cron/snotra-agenda.sh"
if [ ! -e "$_new" ]; then
  printf 'snotra: the door moved to systems/snotra/services/cron/snotra-agenda.sh and is not there\n' >&2
  exit 127
fi
exec "$_new" "$@"
