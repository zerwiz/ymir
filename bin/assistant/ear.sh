#!/usr/bin/env bash
# ear.sh — a voice note in, the words out. The meeting ear's engine, used by the assistant's own bot.
#
#   bin/assistant/ear.sh <audio-file> [--lang en]
#
# Whisper lives in `snotra-whisper.service` (:10300, CUDA, small.en) — the same ear Snotra uses in a
# meeting, so there is one transcription path in this house and not two. If the service is down the
# local `whisper-cli` is the fallback; if neither answers, the caller is told so, never given a guess.
set -u
FILE="${1:-}"; LANG_CODE="en"
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --lang) LANG_CODE="${2:-en}"; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$FILE" ] && [ -r "$FILE" ] || { printf 'ear: no audio file\n' >&2; exit 2; }
URL="${WHISPER_URL:-http://127.0.0.1:10300/inference}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# whisper wants 16 kHz mono PCM
ffmpeg -hide_banner -loglevel error -y -i "$FILE" -ar 16000 -ac 1 "$TMP/16k.wav" 2>/dev/null \
  || { printf 'ear: could not decode the audio\n' >&2; exit 3; }

OUT="$(curl -s -m 120 "$URL" -F "file=@$TMP/16k.wav" -F response_format=json -F temperature=0 2>/dev/null)"
TEXT="$(printf '%s' "$OUT" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("text","").strip())
except Exception: print("")' 2>/dev/null)"
if [ -n "$TEXT" ]; then printf '%s\n' "$TEXT"; exit 0; fi

# the fallback: the local binary, same models directory
CLI="${WHISPER_CLI:-$HOME/whisper.cpp.src/build/bin/whisper-cli}"
MODEL="${WHISPER_MODEL:-$HOME/whisper.cpp.src/models/ggml-small.en.bin}"
if [ -x "$CLI" ] && [ -r "$MODEL" ]; then
  "$CLI" -m "$MODEL" -f "$TMP/16k.wav" -l "$LANG_CODE" -nt 2>/dev/null | tr -s ' ' | sed '/^$/d' && exit 0
fi
printf 'ear: neither the whisper service nor the local model answered\n' >&2
exit 4
