#!/usr/bin/env bash
# snotra-attrib.sh — who said it: the track, the person, and the evidence for both.
#
#   snotra-attrib.sh list  <meeting-dir>                      each track: seconds, frames, and its name (or —)
#   snotra-attrib.sh sample <meeting-dir> [--seconds N]       a spoken probe per track, so a person can recognise it
#   snotra-attrib.sh set   <meeting-dir> speaker-00 "Name" --by "<who confirms>" [--why "…"]
#   snotra-attrib.sh check <meeting-dir>                      which track spoke at each evidence timestamp
#   snotra-attrib.sh apply <meeting-dir> --by "<name>"        write decided_by + attribution{} into the record
#
# The capture log carries a speakerIndex per frame; a decision's evidence carries a timestamp. The door votes
# over the frames around that instant (±4 s): the winner must hold 60 % of them, or the answer is `unclear` and
# NOTHING is attributed. Naming a voice is a person's claim — `--by` is required and appended to speakers.jsonl,
# so a re-naming is a new line and the old claim is never erased.
#
# Exit: 0 ok · 1 refused/failed · 2 usage
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
case "${1-}" in
  -h|--help|"") sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/bin/time/snotra/snotra-attrib.py" "$@"
