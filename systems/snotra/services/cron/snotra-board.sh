#!/usr/bin/env bash
# snotra-board.sh — a place declares a board; this door makes it, once.
#
#   snotra-board.sh show                 the places this home declares
#   snotra-board.sh check  <place>       is the board there, with the lists and labels the place names?
#   snotra-board.sh ensure <place>       create what is missing — never a duplicate, never a rename
#
# A board is found by NAME through trello-map.yaml. `ensure` creates it private, in the organisation the
# house's other boards already belong to, then re-reads the board and proves the lists exist. Exit 1 when a
# list or label the place names is still missing afterwards.
set -euo pipefail
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
case "${1-}" in
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/systems/snotra/services/cron/snotra-board.py" "$@"
