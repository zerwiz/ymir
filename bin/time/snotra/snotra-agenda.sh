#!/usr/bin/env bash
# snotra-agenda.sh — the agenda card that drives the next meeting (DEC-20261022-04).
#
#   snotra-agenda.sh plan   <meeting-dir> [--date YYYY-MM-DD]   what the card would say — no writes
#   snotra-agenda.sh apply  <meeting-dir> [--date YYYY-MM-DD]   create/update it in the place's agenda list
#   snotra-agenda.sh verify <meeting-dir> [--date YYYY-MM-DD]   is it there, in the right list
#
# The points come from the record in the room's own order: what is still `proposed` → actions due by the
# date → **open questions last, always**. The board and the list come from the place profile; the date
# comes from `--date` or from the place's cadence (Monday, `monday_at`). Idempotent by `record-key`.
#
# Exit: 0 ok · 1 drift or missing · 2 usage
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
case "${1-}" in
  -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/bin/time/snotra/snotra-agenda.py" "$@"
