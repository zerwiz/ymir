#!/usr/bin/env bash
# bin/time/snotra/snotra-ensure.sh -> systems/snotra/services/ear/snotra-ensure.sh — RETIRED SHIM
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_d/../../.." && pwd)"
_new="$_root/systems/snotra/services/ear/snotra-ensure.sh"
if [ ! -e "$_new" ]; then
  printf 'snotra: the door moved to systems/snotra/services/ear/snotra-ensure.sh and is not there\n' >&2
  exit 127
fi
exec "$_new" "$@"
