#!/usr/bin/env bash
# snotra-project.sh — the record projected onto the place's boards, by kind, verified.
#
#   snotra-project.sh plan   <meeting-dir>          what would be filed, where — no writes
#   snotra-project.sh apply  <meeting-dir> [--move] create/update idempotently, verified after write
#   snotra-project.sh verify <meeting-dir>          read the boards back and diff against the record
#   snotra-project.sh status <meeting-dir>          the same, as a status
#
# THE SHAPE IS NOT IN THIS FILE. Board, lists, labels and cadence come from
# `hodd/identity/places/<company>/<place>/place.yaml`, which cites the meeting decisions it comes from.
# Boards and lists are resolved by NAME through `hodd/identity/trello-map.yaml`; a typed id is refused.
#
# A card carries `record-key: <meeting-id>:<item-id>` in its description. That key is the idempotency:
# a second run updates the same card, never makes a twin. A card whose key sits in a list the place did
# not name is DRIFT — reported, and left where a human put it (--move is the operator's call).
#
# Exit: 0 ok · 1 drift or missing cards · 2 usage
set -euo pipefail
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
case "${1-}" in
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/systems/snotra/services/cron/snotra-project.py" "$@"
