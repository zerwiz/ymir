#!/usr/bin/env bash
# snotra-letter.sh — one letter per participant, from the record, carrying their own tasks.
#
#   snotra-letter.sh render <meeting-dir>            letters/<person>.md + .html — nothing sent
#   snotra-letter.sh draft  <meeting-dir>            one Gmail DRAFT per person, recorded in letters.json
#   snotra-letter.sh status <meeting-dir>            who has a letter, a draft, an approval, a send
#   snotra-letter.sh send   <meeting-dir> --approved  send — needs the operator's word AND an approval
#
# WHAT SHAPES A LETTER: the meeting's record (the only source) and the PLACE's profile
# (`places/<company>/<place>/place.yaml`) for the sign-off window and the cadence. No company's wording,
# task list or deadline lives in this script — a second place writes its own profile and the letter
# follows it.
#
# THE GATE: `send` refuses without `--approved` and without a valid `snotra-approve.sh check <draft-id>`,
# so an agent cannot mail a partner by accident (the 2026-10-23 incident).
#
# Exit: 0 ok · 1 refused or failed · 2 usage
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
case "${1-}" in
  -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/bin/time/snotra/snotra-letter.py" "$@"
