#!/usr/bin/env bash
# snotra-promote.sh — the register becomes law: accept · reject · hold, and the promotion is recorded.
#
#   snotra-promote.sh list  <meeting-dir>                       every candidate and its state
#   snotra-promote.sh set   <meeting-dir> <ID> accept|reject|hold --by "<name>" [--why "..."] [--dry-run]
#   snotra-promote.sh check <meeting-dir>                       the engine's own validator, first
#   snotra-promote.sh log   <meeting-dir>                       promotions.jsonl, oldest first
#
# A MACHINE MAY PROPOSE; ONLY A PERSON MAY PROMOTE. `--by` is required and is a person's name. The record
# is validated before anything is written, the promotion is APPENDED to promotions.jsonl (never rewritten),
# the result is read back, and setting the same state twice writes nothing.
#
# Exit: 0 ok · 1 refused (validation, unknown id) · 2 usage
set -euo pipefail
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
case "${1-}" in
  -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/systems/snotra/services/approve/snotra-promote.py" "$@"
