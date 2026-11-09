#!/usr/bin/env bash
# bin/assistant/assistant-brief.sh -> systems/skirnir/services/assistant-brief.sh — the SHIM (plan 227 S1.5).
#
# The Allfather named this path when he asked for the database ("the door bin/assistant/assistant-brief.sh"),
# and bin/assistant/ is the shelf a human and a cron row call. The behaviour lives once, in
# systems/skirnir/, where plan 149 moved it — so this file names the move and execs the real door.
#
#   refresh · show [date] · recall <question> · status   (see the engine's help)
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_d/../.." && pwd)"
_new="$_root/systems/skirnir/services/assistant-brief.sh"
if [ ! -e "$_new" ]; then
  printf 'assistant-brief: the door is systems/skirnir/services/assistant-brief.sh and it is not there\n' >&2
  exit 127
fi
exec "$_new" "$@"
