#!/usr/bin/env bash
# voice.sh — talk to Skírnir with a voice, and hear him answer while he is still answering.
#
#   bin/assistant/voice.sh                          # record 6 s, transcribe, answer, speak
#   bin/assistant/voice.sh --seconds 10
#   bin/assistant/voice.sh --text "what is OptiCat?"       # skip the microphone
#   bin/assistant/voice.sh --file /tmp/ask.wav             # transcribe a file
#   bin/assistant/voice.sh --model qwen3.6-35b-a3b@q4_k_xl-mtp
#   bin/assistant/voice.sh --no-speak
#
# The chain: microphone → whisper.cpp → Skírnir (owner tier, digest only) → the gate → Piper,
# sentence by sentence, so speech starts before the answer is complete.
#
# Everything he says still passes the four walls. The voice does not relax the law: no URL, no link,
# no canary, no NDA fact to someone who is not a party.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SECONDS_TO_REC=6; TEXT=""; WAV=""; MODEL=""; SPEAK=1; KOKORO_URL="${KOKORO_URL:-http://127.0.0.1:8765/v1/audio/speech}"
# ONE setting for the voice: whatever `kokoro-voice` reports (F11 and SUPER+CTRL+U use the same).
if [ -z "${KOKORO_VOICE:-}" ] && [ -x "$HOME/.local/bin/kokoro-voice" ]; then
  KOKORO_VOICE="$("$HOME/.local/bin/kokoro-voice" 2>/dev/null | sed -n 's/.*voice: \([a-z_0-9]*\).*/\1/p' | head -1)"
fi
KOKORO_VOICE="${KOKORO_VOICE:-af_nicole}"
PIPER_VOICE_MODEL="${PIPER_VOICE:-$HOME/.local/share/piper-voices/en_US-lessac-medium.onnx}"
while [ $# -gt 0 ]; do
  case "$1" in
    --seconds) SECONDS_TO_REC="${2:-6}"; shift 2 ;;
    --text) TEXT="${2:-}"; shift 2 ;;
    --file) WAV="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --no-speak) SPEAK=0; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --version|-v) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done

WHISPER="${WHISPER_CLI:-$HOME/whisper.cpp.src/build/bin/whisper-cli}"
WHISPER_MODEL="${WHISPER_MODEL:-$HOME/whisper.cpp/models/ggml-small.en.bin}"
PIPER="${PIPER_BIN:-$HOME/.local/bin/piper}"

# Listen with the GPU: the same clip measured 1.5 s on CUDA and 10 s on CPU here, so a silent
# CPU fallback is the difference between a conversation and a wait. It is announced, not hidden.
transcribe() {
  local wav="$1" t0 t1
  t0=$(date +%s%N)
  if "$WHISPER" -m "$WHISPER_MODEL" -f "$wav" -nt -otxt -of /tmp/skirnir-ask >/dev/null 2>/tmp/skirnir-whisper.err; then
    :
  else
    printf 'voice: the GPU pass failed (%s) — falling back to CPU, this will be slow\n' \
      "$(tail -n 1 /tmp/skirnir-whisper.err 2>/dev/null | cut -c1-80)" >&2
    "$WHISPER" -m "$WHISPER_MODEL" -f "$wav" -ng 0 -nt -otxt -of /tmp/skirnir-ask >/dev/null 2>&1 || true
  fi
  t1=$(date +%s%N)
  printf 'voice: transcribed in %s ms\n' "$(( (t1 - t0) / 1000000 ))" >&2
  tr -d '\n' < /tmp/skirnir-ask.txt 2>/dev/null
}

# ── 1 · hear ─────────────────────────────────────────────────────────────────
if [ -n "$TEXT" ]; then
  :
elif [ -n "$WAV" ]; then
  TEXT="$(transcribe "$WAV")"
else
  TMPWAV="$(mktemp --suffix=.wav)"
  printf 'listening for %ss…\n' "$SECONDS_TO_REC" >&2
  arecord -q -f cd -t wav -d "$SECONDS_TO_REC" "$TMPWAV" 2>/dev/null || {
    printf 'error: recording failed (is the microphone free?)\n' >&2; exit 1; }
  TEXT="$(transcribe "$TMPWAV")"
  rm -f "$TMPWAV"
fi
[ -n "${TEXT:-}" ] || { printf 'voice: nothing heard\n' >&2; exit 1; }
printf 'you: %s\n' "$TEXT"

# ── 2 · think (the walls apply) ──────────────────────────────────────────────
ARGS=(--tier owner --channel voice --sender voice --text "$TEXT")
[ -n "$MODEL" ] && ARGS+=(--model "$MODEL")
OUT="$(python3 "$SCRIPT_DIR/skirnir.py" "${ARGS[@]}" 2>/dev/null)"
REPLY="$(printf '%s' "$OUT" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('answer',''))
except Exception: print('')" 2>/dev/null)"
[ -n "$REPLY" ] || { printf 'voice: no answer\n' >&2; exit 1; }
printf 'skírnir: %s\n' "$REPLY"

# ── 3 · speak it as it comes: one sentence at a time ─────────────────────────
# Kokoro first (82M, natural, resident on the GPU through kokoro-serve:8765), Piper as the fallback
# so a dead server does not silence him.
speak_sentence() {
  local text="$1"
  if curl -s -m 30 -o /tmp/skirnir-say.wav -X POST "$KOKORO_URL" \
      -H 'content-type: application/json' \
      -d "$(python3 -c "import json,sys;print(json.dumps({'model':'kokoro','input':sys.argv[1],'voice':sys.argv[2]}))" "$text" "$KOKORO_VOICE")" 2>/dev/null \
      && [ -s /tmp/skirnir-say.wav ]; then
    command -v paplay >/dev/null 2>&1 && paplay /tmp/skirnir-say.wav 2>/dev/null \
      || aplay -q /tmp/skirnir-say.wav 2>/dev/null || true
  elif [ -x "$HOME/.local/bin/kokoro-speak" ]; then
    "$HOME/.local/bin/kokoro-speak" "$text" >/dev/null 2>&1 || true
  elif [ -x "$PIPER" ] && [ -n "${PIPER_VOICE_MODEL:-}" ]; then
    printf '%s\n' "$text" | "$PIPER" --model "$PIPER_VOICE_MODEL" --output_file /tmp/skirnir-say.wav 2>/dev/null
    command -v paplay >/dev/null 2>&1 && paplay /tmp/skirnir-say.wav 2>/dev/null \
      || aplay -q /tmp/skirnir-say.wav 2>/dev/null || true
  fi
}

if [ "$SPEAK" = 1 ]; then
  printf '%s' "$REPLY" | python3 -c "
import re,sys
for part in re.split(r'(?<=[.!?])\s+', sys.stdin.read()):
    part = part.strip()
    if part:
        print(part)
" | while IFS= read -r sentence; do
    speak_sentence "$sentence"
  done
  rm -f /tmp/skirnir-say.wav
fi

printf '%s\n' "$OUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f\"voice[1]{{tier,intent,refused,digest}}: \\\"{d.get('tier')}\\\",\\\"{d.get('intent','')}\\\",\\\"{d.get('refused')}\\\",\\\"{d.get('digest','')}\\\"\")" 2>/dev/null
