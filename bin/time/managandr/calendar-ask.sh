#!/usr/bin/env bash
# bin/time/managandr/calendar-ask.sh -> systems/snotra/services/calendar/calendar-ask.sh — Mánagandr's read door (plan 374 A6).
#
# The calendar is Mánagandr's: what is on the day, and when a meeting fits. Its engine still lives inside the meeting
# ear's system (systems/snotra/services/calendar/, plan 129); moving the service out is a later errand. Until then
# every caller reaches the calendar through this door, so the move will change one line. It execs, so the exit code,
# stdout and stderr are the engine's own.
#
#   what [at]            the next 7 days (or one day)
#   free <minutes>       when a meeting of that length fits
#   probe                is the Google consent still good?
set -euo pipefail
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root="$(cd "$_d/../../.." && pwd)"
_new="$_root/systems/snotra/services/calendar/calendar-ask.sh"
if [ ! -e "$_new" ]; then
  printf 'managandr: the calendar read door is not at %s\n' "$_new" >&2
  exit 127
fi
exec "$_new" "$@"
