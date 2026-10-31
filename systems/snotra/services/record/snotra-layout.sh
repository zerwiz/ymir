#!/usr/bin/env bash
# snotra-layout.sh — a meeting folder is a standard, and a stray is a fault.
#
#   snotra-layout.sh check <meeting-dir>   classify every file; exit 1 on a stray
#   snotra-layout.sh apply <meeting-dir>   MOVE each stray into evidence/hand-built/ (never delete)
#   snotra-layout.sh list  <meeting-dir>   the same, one line per stray
#
# The top level holds the source (record.json, harvest.json, letters.json, promotions.jsonl), the
# rendered set the engine owns, the shelves (briefs/ letters/ evidence/), the manifest (README.md,
# PROVENANCE.md) and the named state (trello.json, dispatch.json, signoffs.json, planner.json,
# classification.yaml, access.jsonl, timestamp/). Everything else is a stray — and a second copy of a
# document the engine already renders counts as one. A move is a retirement, never a deletion (Rule 11).
#
# Exit: 0 clean · 1 strays found (or a move failed) · 2 usage
set -euo pipefail
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
case "${1-}" in
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/systems/snotra/services/record/snotra-layout.py" "$@"
