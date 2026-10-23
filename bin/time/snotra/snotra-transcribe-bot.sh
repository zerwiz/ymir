#!/usr/bin/env bash
# snotra-transcribe-bot.sh — the meeting's own audio becomes the record's text.
#
#   snotra-transcribe-bot.sh run    <meeting-dir> [--force] [--model FILE]
#   snotra-transcribe-bot.sh status <meeting-dir>
#
# Refuses audio that is not the meeting's own stream (`is_meeting_stream: true` from harvest.json —
# Rule 33), refuses to overwrite a newer transcript without --force, records its engine/model/span in
# `evidence/bot/transcribe.json`, and treats fewer than 50 words as a FAILURE, not a transcript.
#
# Exit: 0 ok · 1 failure (no audio, no words, whisper missing) · 2 usage
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
case "${1-}" in
  -h|--help|"") sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
exec python3 "$ROOT/bin/time/snotra/snotra-transcribe-bot.py" "$@"
