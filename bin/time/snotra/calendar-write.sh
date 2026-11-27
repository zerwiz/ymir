#!/usr/bin/env bash
# bin/time/snotra/calendar-write.sh -> bin/time/managandr/calendar-write.sh — a forwarding stub, plan 374 (A6, 2026-11-25). allow-superseded-path: this header records the move
#
# The calendar is Mánagandr's, not Snotra's (Snotra keeps the meeting ear). The door moved with its history
# (`git log --follow bin/time/managandr/calendar-write.sh`); this stub keeps an old cron row, voice tool or note
# working for one release cycle. It execs, so the exit code, stdout and stderr are the door's own.
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../managandr/calendar-write.sh" "$@"
