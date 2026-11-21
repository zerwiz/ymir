#!/usr/bin/env bash
# night-report.sh — what the fleet did overnight, written for the operator to read in the morning.
#
#   bin/day/night-report.sh                 gather, tick his list, write the report, ship it, send one message
#   bin/day/night-report.sh --dry-run       print the report and the message; write, tick and send nothing
#   bin/day/night-report.sh --dry-run --json   the gathered facts, for a surface
#   bin/day/night-report.sh --fallback      a seat standing in for the heart: stands down when today's exists
#   bin/day/night-report.sh --since 2026-11-20T22:00 --repo owner/name …
#
# It reads every seat's errands (state/*.status and state/eindri-reports/, over each seat's ssh road),
# the PRs of every repository the project registry names, the Runes ledger, the boards' decision cards
# and his list (life/personal/me/todo.md). It writes hodd/docs/status/YYYY-MM-DD-night-report.md in
# the home, ticks only what is proven done (appended, never rewritten), and ships through
# bin/vault/home-sync.sh. The logic is bin/day/night_report.py; the how-to is
# docs/features/night-report.md.
#
# Exit: 0 written (or a stated stand-down) · 1 the home is not there or could not be pulled · 2 usage.
set -uo pipefail
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1-}" in -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
command -v python3 >/dev/null 2>&1 || { printf 'night-report: python3 is not on PATH\n' >&2; exit 1; }
exec python3 "$_here/night_report.py" "$@"
