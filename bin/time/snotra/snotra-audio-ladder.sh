#!/usr/bin/env bash
# snotra-audio-ladder.sh — the meeting's sound gets smaller AFTER its words are safe.
#
#   snotra-audio-ladder.sh plan   <meeting-dir>                   what would shrink, and by how much
#   snotra-audio-ladder.sh apply  <meeting-dir> [--offload DIR]   verify → compress → strip → report
#   snotra-audio-ladder.sh status <meeting-dir>                   the sizes now
#
# THE ORDER IS THE LAW: verify the harvest → require a non-empty transcript → compress the audio to
# Opus 16 kbps mono → drop the duplicated `pcm` from the capture log (timing and speakerIndex stay) →
# offload if a cold shelf is given. No transcript, no shrinking. Nothing here deletes text.
#
# Exit: 0 ok · 1 refused (no transcript, failed verification, duration moved) · 2 usage
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
case "${1-}" in
  -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/bin/time/snotra/snotra-audio-ladder.py" "$@"
