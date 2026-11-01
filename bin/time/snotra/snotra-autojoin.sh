#!/usr/bin/env bash
# bin/time/snotra/snotra-autojoin.sh -> systems/snotra/services/ear/snotra-autojoin.sh — RETIRED SHIM
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_d/../../.." && pwd)"
_new="$_root/systems/snotra/services/ear/snotra-autojoin.sh"
if [ ! -e "$_new" ]; then
  printf 'snotra: the door moved to systems/snotra/services/ear/snotra-autojoin.sh and is not there\n' >&2
  exit 127
fi
exec "$_new" "$@"
