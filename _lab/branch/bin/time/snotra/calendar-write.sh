#!/usr/bin/env bash
# bin/time/snotra/calendar-write.sh -> systems/snotra/services/calendar/calendar-write.sh — a shim, plan 231 R2
# allow-superseded-path: this header RECORDS the road, it does not make one
#
# `bin/time/snotra/` was moved into `systems/snotra/` (plan 129, 2026-10-24) and
# `.agents/paths-ledger.yaml` records the move. This file exists for the one caller the plan
# names — Mánagandr's write hand — so a voice tool, a cron row or an old note can call it and
# reach the real door. It execs, so the exit code, stdout and stderr are the door's own.
#
#   create --title T --when <spec> [--duration 45m|1h30m] [--attendees a@x,b@y] [--meet] [--dry-run]
#   move <event-id|title words> --to <spec> [--duration DUR] [--dry-run]
#   status
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_d/../../.." && pwd)"
_new="$_root/systems/snotra/services/calendar/calendar-write.sh"
if [ ! -e "$_new" ]; then
  printf 'snotra: the calendar write door is not at %s\n' "$_new" >&2
  exit 127
fi
exec "$_new" "$@"
