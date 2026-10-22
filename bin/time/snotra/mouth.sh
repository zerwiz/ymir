#!/usr/bin/env bash
# mouth.sh — text in, a Telegram voice note out.
#
#   bin/assistant/mouth.sh "text" <out.ogg>
#
# Kokoro (the resident server on :8765) speaks it, `speech-text.py` normalises what may be SPOKEN
# (contractions expanded, punctuation folded), and ffmpeg encodes OGG/Opus — the only format Telegram's
# sendVoice accepts. The voice is the switcher's (~/.local/bin/kokoro-voice), the same one F11 and the
# assistant's own mouth use: one voice for the whole house.
set -u
TEXT="${1:-}"; OUT="${2:-}"
[ -n "$TEXT" ] && [ -n "$OUT" ] || { printf 'mouth: usage: mouth.sh "text" out.ogg\n' >&2; exit 2; }
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOICE="${KOKORO_VOICE:-}"
if [ -z "$VOICE" ] && [ -x "$HOME/.local/bin/kokoro-voice" ]; then
  VOICE="$("$HOME/.local/bin/kokoro-voice" 2>/dev/null | sed -n 's/.*voice: \([a-z_0-9]*\).*/\1/p' | head -1)"
fi
VOICE="${VOICE:-af_nicole}"
SERVER="${KOKORO_URL:-http://127.0.0.1:8765/v1/audio/speech}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

SPOKEN="$(printf '%s' "$TEXT" | python3 "$SCRIPT_DIR/speech-text.py")"
curl -s -m 120 -o "$TMP/say.wav" -X POST "$SERVER" -H 'content-type: application/json' \
  -d "$(python3 -c "import json,sys;print(json.dumps({'model':'kokoro','input':sys.argv[1],'voice':sys.argv[2],'response_format':'wav'}))" "$SPOKEN" "$VOICE")" \
  || { printf 'mouth: the synthesiser did not answer\n' >&2; exit 3; }
[ -s "$TMP/say.wav" ] || { printf 'mouth: empty audio\n' >&2; exit 4; }
# hold the voice: the idle-stop must never lower the card under a conversation (2026-10-23)
bash "$SCRIPT_DIR/../time/snotra/tts-lease.sh" touch 2>/dev/null || true
python3 "$SCRIPT_DIR/audio-tighten.py" "$TMP/say.wav" 2>/dev/null || true
ffmpeg -hide_banner -loglevel error -y -i "$TMP/say.wav" -c:a libopus -b:a 32k -ar 48000 -ac 1 "$OUT" 2>/dev/null \
  || { printf 'mouth: could not encode the voice note\n' >&2; exit 5; }
printf 'mouth[1]{voice,bytes,file}: "%s","%s","%s"\n' "$VOICE" "$(stat -c%s "$OUT")" "$OUT"
