#!/usr/bin/env bash
# snotra-harvest.sh — the meeting's OWN audio, out of the bot's store, verified.
#
#   snotra-harvest.sh status   <meeting-dir>            what the bot holds, and what is staged here
#   snotra-harvest.sh fetch    <meeting-dir> [--force]  pull the audio, verify it byte-for-byte
#   snotra-harvest.sh verify   <meeting-dir>            re-check the staged audio against the store
#   snotra-harvest.sh speakers <meeting-dir> [--force]  split the capture log by speakerIndex into WAVs
#   snotra-harvest.sh signal   <meeting-dir> [--force]  audit the STT log: `ok:true, text:""` is FAILURE
#
# WHY: the bot records the meeting's own stream (per-participant audio + a per-frame speakerIndex).
# Nothing in Snotra reached that store, so meeting folders held the room microphone and no transcript.
# Rule 33 forbids the microphone as a Snotra record; this is the legitimate source, and the only one
# that can say WHO said it.
#
# WHERE THE BYTES GO: staging outside the vault —
#   ${XDG_STATE_HOME:-~/.local/state}/ymir/snotra-harvest/<meeting-folder>/
# The vault receives `harvest.json` only (text, small). Rule 30: audio is evidence with a fuse, and a
# git repository is not a media store.
#
# Exit: 0 ok · 1 the door answered no (size mismatch, empty transcription, unreadable store) · 2 usage
set -euo pipefail
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
case "${1-}" in
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/systems/snotra/services/ear/snotra-harvest.py" "$@"
