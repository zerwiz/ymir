#!/usr/bin/env bash
# snotra-transcribe.sh — transcribe a meeting recording and produce minutes.
#
# Usage:
#   snotra-transcribe.sh <recording.wav> [topic]
#
# Steps:
#   1. Normalize the audio to 16kHz mono (whisper's native rate)
#   2. Transcribe with the seat's whisper engine (discovered, never assumed)
#   3. Produce structured minutes in Markdown
#   4. Store minutes under $YMIR_HOME/hodd/workspaces/meetings/
#   5. Append a Rune to the audit ledger
#
# Portable across the fleet: the engine is DISCOVERED on each seat —
#   heimdall  ~/whisper.cpp.src/build/bin/whisper-cli   (CUDA)
#   whynot    ~/whisper.cpp/build/bin/whisper-cli       (CUDA)
#   omarchy   /usr/bin/whisper-cli                      (extra/whisper-cpp)
#   fallback  voxtype transcribe                        (omarchy's bundled engine)
#
# Env:
#   YMIR_HOME          — the hoard root (default ~/Documents/ymirhome)
#   SNOTRA_WHISPER_BIN — explicit whisper binary override
#   SNOTRA_WHISPER_MODEL — explicit model override
#   WHISPER_GPU        — informational (whisper auto-detects CUDA)
#   RAIL_URL           — llama-swap URL for summaries
#                        (default http://127.0.0.1:8080/v1; a remote seat sets
#                         http://heimdall.tailefab81.ts.net:8080/v1)
#   RAIL_MODEL         — the model alias (default qwen3.6-35b-a3b@q2_k_xl)
#   RAIL_KEY           — llama-swap API key (from ~/.pi/agent/auth.json)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
HOARD="$YMIR_HOME/hodd"
MEETINGS="$HOARD/workspaces/meetings"
WHISPER_GPU="${WHISPER_GPU:-on}"
RAIL_URL="${RAIL_URL:-http://127.0.0.1:8080/v1}"
RAIL_MODEL="${RAIL_MODEL:-qwen3.6-35b-a3b@q2_k_xl}"
RAIL_KEY="${RAIL_KEY:-}"
TMP_PREFIX="/tmp/snotra-$$"

mkdir -p "$MEETINGS"

say() { printf '%s\n' "$*"; }

# --- engine + model discovery ----------------------------------------------

find_whisper() {
  # 1) explicit override
  if [ -n "${SNOTRA_WHISPER_BIN:-}" ] && [ -x "$SNOTRA_WHISPER_BIN" ]; then
    printf '%s' "$SNOTRA_WHISPER_BIN"; return 0
  fi
  # 2) PATH (whisper-cli is the current name; whisper-cpp is the Arch package)
  local c
  for c in whisper-cli whisper-cpp whisper; do
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  # 3) the fleet's known build trees (whisper-cli, then the deprecated `main`)
  local p
  for p in \
    "$HOME/whisper.cpp.src/build/bin/whisper-cli" \
    "$HOME/whisper.cpp/build/bin/whisper-cli" \
    "$HOME/whisper.cpp.src/build/bin/main" \
    "$HOME/whisper.cpp/build/bin/main" \
    "/usr/local/bin/whisper-cli" \
    "/usr/bin/whisper-cli"; do
    if [ -x "$p" ]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

find_model() {
  if [ -n "${SNOTRA_WHISPER_MODEL:-}" ] && [ -f "$SNOTRA_WHISPER_MODEL" ]; then
    printf '%s' "$SNOTRA_WHISPER_MODEL"; return 0
  fi
  local p
  for p in \
    "$HOME/whisper.cpp/models/ggml-small.en.bin" \
    "$HOME/whisper.cpp/models/ggml-base.en.bin" \
    "$HOME/.local/share/voxtype/models/ggml-small.en.bin" \
    "$HOME/.local/share/voxtype/models/ggml-base.en.bin" \
    "$HOME/.local/share/whisper.cpp/models/ggml-small.en.bin" \
    "/usr/share/whisper.cpp/models/ggml-small.en.bin" \
    "/usr/share/whisper/models/ggml-small.en.bin"; do
    if [ -f "$p" ]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

# Resolve the API key from auth.json if not set
if [ -z "$RAIL_KEY" ] && [ -f "$HOME/.pi/agent/auth.json" ]; then
  RAIL_KEY=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(d.get("llama-swap",{}).get("key",""))' "$HOME/.pi/agent/auth.json" 2>/dev/null || true)
fi

# run_whisper <bin> <model|''> <audio> <extra flags…>
# Writes "$TMP_PREFIX.txt"; returns non-zero when the engine failed.
# A build-tree binary needs its own directory on LD_LIBRARY_PATH (libwhisper.so).
# Run inside a subshell so a CUDA abort cannot print a signal message into the
# transcript path; the caller retries on the CPU.
run_whisper() {
  local bin="$1" model="$2" audio="$3"; shift 3
  local bindir
  bindir="$(dirname "$bin")"
  rm -f "$TMP_PREFIX.txt"
  (
    export LD_LIBRARY_PATH="$bindir:${LD_LIBRARY_PATH:-}"
    if [ -n "$model" ]; then
      "$bin" -m "$model" -f "$audio" -l en --output-txt --output-file "$TMP_PREFIX" "$@"
    else
      "$bin" -f "$audio" -l en --output-txt --output-file "$TMP_PREFIX" "$@"
    fi
  ) >/dev/null 2>&1
  [ -s "$TMP_PREFIX.txt" ]
}

# Free VRAM in MiB (empty when nvidia-smi is unavailable).
free_vram_mb() {
  nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '
}

do_transcribe() {
  local WAV="$1"
  local TOPIC="${2:-meeting}"
  local DATESTAMP
  DATESTAMP=$(date +%Y-%m-%d_%H%M%S)
  local MINUTES_FILE="$MEETINGS/meeting-${DATESTAMP}-minutes.md"

  if [ ! -f "$WAV" ]; then
    echo "error: recording not found: $WAV" >&2
    exit 1
  fi

  say "Transcribing: $WAV"
  say "Topic: $TOPIC"
  say "Seat: $(hostname -s 2>/dev/null || hostname)"

  # Step 1: normalize to 16kHz mono (whisper's native rate; keeps the engine
  #         identical on every seat regardless of what the capture wrote)
  local NORM="$TMP_PREFIX-16k.wav"
  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -i "$WAV" -ar 16000 -ac 1 -c:a pcm_s16le "$NORM" >/dev/null 2>&1 || cp "$WAV" "$NORM"
  else
    cp "$WAV" "$NORM"
  fi

  # Step 2: transcribe — engine discovered, never assumed
  local WHISPER MODEL TRANSCRIPT
  WHISPER="$(find_whisper || true)"
  MODEL="$(find_model || true)"
  TRANSCRIPT=""

  if [ -n "$WHISPER" ] && [ -n "$MODEL" ]; then
    say "  engine: $WHISPER"
    say "  model:  $MODEL"
    # Choose the backend by available VRAM: a resident rail model starves CUDA
    # (heimdall A5000 and whynot P2000 both run one), so a tight card goes
    # straight to the CPU; otherwise try GPU and fall back on failure. Never a
    # silent empty transcript.
    local VRAM
    VRAM="$(free_vram_mb)"
    if [ -n "$VRAM" ] && [ "$VRAM" -ge 2048 ]; then
      run_whisper "$WHISPER" "$MODEL" "$NORM" "" || \
        run_whisper "$WHISPER" "$MODEL" "$NORM" "-ng" || true
    else
      [ -n "$VRAM" ] && say "  VRAM tight (${VRAM}MiB free) — transcribing on the CPU"
      run_whisper "$WHISPER" "$MODEL" "$NORM" "-ng" || \
        run_whisper "$WHISPER" "$MODEL" "$NORM" "" || true
    fi
    [ -f "$TMP_PREFIX.txt" ] && TRANSCRIPT="$(cat "$TMP_PREFIX.txt")"
    if [ -z "$TRANSCRIPT" ] && [ "${SNOTRA_FREE_RAIL:-0}" = 1 ] && [ -x "$HOME/.local/bin/voice-gpu-lib.sh" ]; then
      say "  GPU starved — freeing the rail and retrying"
      # shellcheck disable=SC1090
      . "$HOME/.local/bin/voice-gpu-lib.sh"
      voice_ensure_vram 2048 >/dev/null 2>&1 || true
      run_whisper "$WHISPER" "$MODEL" "$NORM" "" || true
      [ -f "$TMP_PREFIX.txt" ] && TRANSCRIPT="$(cat "$TMP_PREFIX.txt")"
    fi
  elif [ -n "$WHISPER" ]; then
    say "  engine: $WHISPER (no model found — transcribing with defaults)"
    run_whisper "$WHISPER" "" "$NORM" "" || true
    [ -f "$TMP_PREFIX.txt" ] && TRANSCRIPT="$(cat "$TMP_PREFIX.txt")"
  elif command -v voxtype >/dev/null 2>&1; then
    say "  engine: voxtype transcribe (the seat's bundled whisper)"
    TRANSCRIPT="$(voxtype transcribe "$NORM" 2>/dev/null || true)"
  else
    say "  WARNING: no whisper engine found on this seat"
    say "  Install: whisper-cli (extra/whisper-cpp) or build whisper.cpp"
  fi

  TRANSCRIPT="${TRANSCRIPT:-}"

  # Step 3: produce structured minutes
  local DATE_TODAY HOUR
  DATE_TODAY=$(date +%Y-%m-%d)
  HOUR=$(date +%H:%M)

  cat > "$MINUTES_FILE" <<MINS
# Meeting Minutes — $DATE_TODAY

**Date:** $DATE_TODAY
**Time:** $HOUR
**Topic:** $TOPIC
**Source:** $WAV
**Seat:** $(hostname -s 2>/dev/null || hostname)

## Transcript

$TRANSCRIPT

## Decisions

_(pending AI summary)_

## Action Items

_(pending AI summary)_

---
*Generated by Snotra — the meeting ear*
MINS

  say "Minutes written: $MINUTES_FILE"

  # Step 4: summarize with the local rail (no cloud key)
  if [ -n "$RAIL_KEY" ] && [ -n "$TRANSCRIPT" ]; then
    say "  Summarizing with the rail: $RAIL_URL ($RAIL_MODEL)"
    local SUMMARY TEXT
    SUMMARY=$(curl -s --max-time 300 "$RAIL_URL/chat/completions" \
      -H "Authorization: Bearer $RAIL_KEY" \
      -H "Content-Type: application/json" \
      -d "$(python3 - "$RAIL_MODEL" "$TRANSCRIPT" <<'PY'
import json,sys
model, transcript = sys.argv[1], sys.argv[2]
print(json.dumps({
  "model": model,
  "messages": [
    {"role":"system","content":"You are a meeting minutes summarizer. Produce concise decisions and action items from the transcript."},
    {"role":"user","content":"Transcript:\n"+transcript[:20000]}
  ],
  "temperature": 0,
  "max_tokens": 1200
}))
PY
)" 2>/dev/null || true)

    if [ -n "$SUMMARY" ]; then
      TEXT=$(printf '%s' "$SUMMARY" | python3 -c '
import json,sys
try:
  d=json.loads(sys.stdin.read())
  print(d.get("choices",[{}])[0].get("message",{}).get("content",""))
except Exception:
  print("")
' 2>/dev/null || true)

      if [ -n "$TEXT" ]; then
        {
          echo ""
          echo "## Decisions"
          echo ""
          printf '%s\n' "$TEXT" | grep -iE '(decision|decided|agreed|confirmed|approved)' | head -10 || echo "(none captured)"
          echo ""
          echo "## Action Items"
          echo ""
          printf '%s\n' "$TEXT" | grep -iE '(action|task|assign|follow up|next)' | head -10 || echo "(none captured)"
          echo ""
          echo "---"
          echo "*Generated by Snotra — the meeting ear*"
        } >> "$MINUTES_FILE"
        say "  Summary appended to minutes"
      fi
    fi
  else
    say "  Skipping summary (no rail key or empty transcript)"
  fi

  # Step 5: append a Rune
  if [ -x "$SCRIPT_DIR/runes-append.sh" ]; then
    "$SCRIPT_DIR/runes-append.sh" snotra \
      "meeting minutes created — $MINUTES_FILE" \
      --message "snotra: meeting minutes created — $MINUTES_FILE" >/dev/null 2>&1 || true
  fi

  # cleanup
  rm -f "$NORM" "$TMP_PREFIX.txt"
  say "Done: $MINUTES_FILE"
}

case "${1:-}" in
  -h|--help|"")
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    do_transcribe "$@"
    ;;
esac
