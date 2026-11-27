#!/usr/bin/env bash
# bin/time/managandr/calendar-write.sh -> systems/snotra/services/calendar/calendar-write.sh — Mánagandr's write door (plan 231 R2; moved here by plan 374 A6)
# allow-superseded-path: this header RECORDS the road, it does not make one
#
# The calendar is Mánagandr's, not Snotra's (Snotra keeps the meeting ear). The door moved with its history
# (`git log --follow bin/time/managandr/calendar-write.sh`); this stub keeps an old cron row, voice tool or note
# working for one release cycle. It execs, so the exit code, stdout and stderr are the door's own.
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_d/../../.." && pwd)"
_new="$_root/systems/snotra/services/calendar/calendar-write.sh"
if [ ! -e "$_new" ]; then
  printf 'managandr: the calendar write door is not at %s\n' "$_new" >&2
  exit 127
fi
exec "$_new" "$@"
