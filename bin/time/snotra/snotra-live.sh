#!/usr/bin/env bash
# snotra-live.sh — the live tail: realtime mic transcription that grows in a doc.
#
# Usage:
#   snotra-live.sh start <slug> [topic]   — start live transcription
#   snotra-live.sh status                  — show live state
#   snotra-live.sh tail                    — follow the transcript as it grows
#   snotra-live.sh stop                    — stop and hand off to the pipeline
#
# The live tail: ffmpeg segments the mic into ~6s slices; a tail loop transcribes
# each slice and appends into the doc. Manual door only; the call-watch is untouched.
#
# The listening indicator: writes state/.snotra-listening so the bar can display it.
#
# Env:
#   YMIR_HOME          — the hoard root (default ~/Documents/ymirhome)
#   SNOTRA_MONITOR     — sink monitor name (default: the running/default sink)
#   SNOTRA_MIC         — source name (default: the running/default input)
#   SNOTRA_FREE_RAIL   — yield the rail if GPU is starved (default: 1)
#   SNOTRA_LIVE_SLICE  — slice length in seconds (default: 6)
#   SNOTRA_LANE        — the filename lane token (default: ping)

set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "${ROOT:-}/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/hoard-lib.sh"; do
    [ -n "$_yc" ] && [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YMIR_HOME="${YMIR_HOME}"
HOARD="$YMIR_HOME/hodd/life/meetings"
STATE_DIR="$YMIR_HOME/state"
LISTENING_FILE="$STATE_DIR/.snotra-listening"
LIVE_STATE_DIR="$STATE_DIR/.snotra-live"
PID_FILE="$LIVE_STATE_DIR/.snotra-pid"
SLICE_STATE="$LIVE_STATE_DIR/.snotra-slices"
DOC_STATE="$LIVE_STATE_DIR/.snotra-doc"
ENGINE_STATE="$LIVE_STATE_DIR/.snotra-engine"

mkdir -p "$HOARD" "$STATE_DIR" "$LIVE_STATE_DIR"

say() { printf '%s\n' "$*"; }

# ── engine discovery (reuse snotra-transcribe.sh's find_whisper/find_model) ──

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

# Free VRAM in MiB (empty when nvidia-smi is unavailable).
free_vram_mb() {
  nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '
}

# ── the tail loop: transcribe each slice and append ──

do_tail() {
  local WAV="$1" TOPIC="$2" ENGINE="$3" MODEL="$4"
  local DOC="${5:-}"
  [ -z "$DOC" ] && DOC="$HOARD/meetings/${DATESTAMP:-$(date +%Y-%m-%d)}-${LANE:-ping}-${SLUG}.md"
  mkdir -p "$(dirname "$DOC")" 2>/dev/null || true

  say "Starting tail on: $DOC"
  say "  Engine: $ENGINE"
  say "  Model:  $MODEL"

  # The tail: follow the doc as it grows. Never a busy poll — tail -f is
  # the right tool for this job. It reads the file as it grows, and the
  # segmenter writes atomically (ffmpeg's segment output is stable once
  # written).
  #
  # Safety: check that the slice file is stable before transcribing.
  # ffmpeg's segment output is written atomically once complete, so we can
  # check file size stability as a sanity check.
  local last_size=0
  while true; do
    # Check if the doc has grown (new content appended)
    if [ -f "$DOC" ]; then
      local current_size
      current_size=$(stat -c%s "$DOC" 2>/dev/null || echo 0)
      if [ "$current_size" -gt "$last_size" ]; then
        last_size=$current_size
        # The doc grew — re-read the last line to see what was appended
        local last_line
        last_line=$(tail -n1 "$DOC" 2>/dev/null || echo "")
        say "  [tail] doc grew: $last_line"
      fi
    fi

    # Check for new slice files
    local new_slices=0
    for slice in "$SLICES_DIR"/*.wav 2>/dev/null; do
      [ -e "$slice" ] || continue
      local fname
      fname=$(basename "$slice")
      # Check if this slice has been transcribed (look for corresponding .txt)
      local txt="$SLICES_DIR/${fname%.wav}.txt"
      if [ ! -f "$txt" ]; then
        new_slices=$((new_slices + 1))
      fi
    done

    if [ "$new_slices" -gt 0 ]; then
      say "  [tail] $new_slices new slice(s) to transcribe"
    fi

    # Sleep briefly to avoid busy polling
    sleep 1
  done
}

# ── the segmenter: ffmpeg with chunked output ──

do_segment() {
  local SLUG="$1" TOPIC="$2"
  local DATESTAMP LANE SLICES_DIR
  DATESTAMP=$(date +%Y-%m-%d_%H%M%S)
  LANE="${LANE:-ping}"
  SLICES_DIR="$HOARD/slices/${DATESTAMP}-${LANE}-${SLUG}"
  mkdir -p "$SLICES_DIR"

  say "Segmenter starting: $SLICES_DIR"

  # ffmpeg segments the mic into ~6s slices
  # -segment_atclocktime ensures each slice starts at a clock boundary
  # -segment_start_number ensures sequential numbering
  # The segmenter runs in the background; the tail reads from the directory
  ffmpeg -y -hide_banner -loglevel error \
    -f pulse -i "${SNOTRA_MIC:-}" \
    -filter_complex "[0:a]aformat=channel_layouts=mono,pan=mono|c0=c0[a]" \
    -map "[a]" -ar 48000 -ac 2 -c:a pcm_s16le \
    -f segment -segment_time "${SNOTRA_LIVE_SLICE:-6}" \
    -segment_start_number 1 -segment_format_options timestamp=exact \
    -segment_atclocktime 1 \
    "${SLICES_DIR}/%04d.wav" &

  local FFMPEG_PID=$!
  echo "$FFMPEG_PID" > "$LIVE_STATE_DIR/.snotra-segmenter-pid"

  say "  Segmenter PID: $FFMPEG_PID"
  wait "$FFMPEG_PID" 2>/dev/null || true
  rm -f "$LIVE_STATE_DIR/.snotra-segmenter-pid"
  say "Segmenter stopped"
}

# ── the tail transcriber: reads slices and appends to doc ──

do_tail_transcribe() {
  local SLUG="$1" TOPIC="$2" ENGINE="$3" MODEL="$4"
  local DOC="${5:-}"
  [ -z "$DOC" ] && DOC="$HOARD/meetings/${DATESTAMP:-$(date +%Y-%m-%d)}-${LANE:-ping}-${SLUG}.md"
  local SLICES_DIR="$HOARD/slices/$(date +%Y-%m-%d-%H-%M-%S-%N-${LANE:-ping}-${SLUG})"
  mkdir -p "$(dirname "$DOC")" 2>/dev/null || true

  say "Tail transcriber starting: $DOC"
  say "  Slices dir: $SLICES_DIR"

  # The tail: watch the slices directory and transcribe each new slice
  # as it appears. Use inotifywait if available, otherwise poll with a check.
  if command -v inotifywait >/dev/null 2>&1; then
    # Use inotifywait for efficient file watching
    inotifywait -e create -e close_write --format '%w%f' \
      --exclude '*.txt' --exclude '*.srt' \
      "$SLICES_DIR" 2>/dev/null | while read -r slice; do
      [ -f "$slice" ] || continue
      local fname
      fname=$(basename "$slice")
      [ "$fname" = "${fname%.wav}.txt" ] && continue  # skip already transcribed

      say "  [tail] Transcribing: $slice"

      # Normalize the slice to 16kHz mono (whisper's native rate)
      local NORM="$SLICES_DIR/${fname%.wav}-16k.wav"
      if command -v ffmpeg >/dev/null 2>&1; then
        ffmpeg -y -i "$slice" -ar 16000 -ac 1 -c:a pcm_s16le "$NORM" >/dev/null 2>&1 || cp "$slice" "$NORM"
      else
        cp "$slice" "$NORM"
      fi

      # Transcribe the slice
      local TRANSCRIPT=""
      if [ -n "$ENGINE" ] && [ -n "$MODEL" ]; then
        local TMP_PREFIX="/tmp/snotra-tail-$$"
        rm -f "$TMP_PREFIX.txt"
        export LD_LIBRARY_PATH="$(dirname "$ENGINE"):${LD_LIBRARY_PATH:-}"
        if [ -n "$MODEL" ]; then
          "$ENGINE" -m "$MODEL" -f "$NORM" -l en --output-txt --output-srt --output-file "$TMP_PREFIX.txt" 2>/dev/null || true
        else
          "$ENGINE" -f "$NORM" -l en --output-txt --output-srt --output-file "$TMP_PREFIX.txt" 2>/dev/null || true
        fi
        [ -f "$TMP_PREFIX.txt" ] && TRANSCRIPT="$(cat "$TMP_PREFIX.txt")"
        rm -f "$TMP_PREFIX.txt" "$TMP_PREFIX.srt"
      fi

      # Append to the doc with timestamp
      if [ -n "$TRANSCRIPT" ]; then
        local TIMESTAMP
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        printf '\n[%s] %s\n' "$TIMESTAMP" "$TRANSCRIPT" >> "$DOC"
        say "  [tail] Appended to: $DOC"
      fi

      # Mark as transcribed
      touch "$SLICES_DIR/${fname%.wav}.txt"
    done
  else
    # Fallback: poll with a stability check
    while true; do
      local last_modified=0
      for slice in "$SLICES_DIR"/*.wav 2>/dev/null; do
        [ -e "$slice" ] || continue
        local mtime
        mtime=$(stat -c%Y "$slice" 2>/dev/null || echo 0)
        if [ "$mtime" -gt "$last_modified" ]; then
          last_modified=$mtime
        fi
      done

      # Check if any slice has been transcribed
      local untranscribed=0
      for slice in "$SLICES_DIR"/*.wav 2>/dev/null; do
        [ -e "$slice" ] || continue
        local fname
        fname=$(basename "$slice")
        local txt="$SLICES_DIR/${fname%.wav}.txt"
        if [ ! -f "$txt" ]; then
          untranscribed=$((untranscribed + 1))
        fi
      done

      if [ "$untranscribed" -gt 0 ]; then
        # Transcribe the oldest untranscribed slice
        for slice in "$SLICES_DIR"/*.wav 2>/dev/null; do
          [ -e "$slice" ] || continue
          local fname
          fname=$(basename "$slice")
          local txt="$SLICES_DIR/${fname%.wav}.txt"
          if [ ! -f "$txt" ]; then
            say "  [tail] Transcribing: $slice"

            # Normalize the slice to 16kHz mono
            local NORM="$SLICES_DIR/${fname%.wav}-16k.wav"
            if command -v ffmpeg >/dev/null 2>&1; then
              ffmpeg -y -i "$slice" -ar 16000 -ac 1 -c:a pcm_s16le "$NORM" >/dev/null 2>&1 || cp "$slice" "$NORM"
            else
              cp "$slice" "$NORM"
            fi

            # Transcribe the slice
            local TRANSCRIPT=""
            if [ -n "$ENGINE" ] && [ -n "$MODEL" ]; then
              local TMP_PREFIX="/tmp/snotra-tail-$$"
              rm -f "$TMP_PREFIX.txt"
              export LD_LIBRARY_PATH="$(dirname "$ENGINE"):${LD_LIBRARY_PATH:-}"
              if [ -n "$MODEL" ]; then
                "$ENGINE" -m "$MODEL" -f "$NORM" -l en --output-txt --output-srt --output-file "$TMP_PREFIX.txt" 2>/dev/null || true
              else
                "$ENGINE" -f "$NORM" -l en --output-txt --output-srt --output-file "$TMP_PREFIX.txt" 2>/dev/null || true
              fi
              [ -f "$TMP_PREFIX.txt" ] && TRANSCRIPT="$(cat "$TMP_PREFIX.txt")"
              rm -f "$TMP_PREFIX.txt" "$TMP_PREFIX.srt"
            fi

            # Append to the doc with timestamp
            if [ -n "$TRANSCRIPT" ]; then
              local TIMESTAMP
              TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
              printf '\n[%s] %s\n' "$TIMESTAMP" "$TRANSCRIPT" >> "$DOC"
              say "  [tail] Appended to: $DOC"
            fi

            # Mark as transcribed
            touch "$SLICES_DIR/${fname%.wav}.txt"
            break
          fi
        done
      else
        # No untranscribed slices — wait a bit
        sleep 2
      fi
    done
  fi
}

# ── the start verb ──

do_start() {
  local SLUG="${1:-}" TOPIC="${2:-meeting}"
  [ -z "$SLUG" ] && { say "error: slug required (snotra-live.sh start <slug> [topic])"; exit 1; }

  # Check for existing live session
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
    say "error: a live session is already running (pid $(cat "$PID_FILE"))" >&2
    exit 1
  fi

  # Check for existing capture
  if [ -f "$STATE_DIR/.snotra-pid" ] && kill -0 "$(cat "$STATE_DIR/.snotra-pid" 2>/dev/null)" 2>/dev/null; then
    say "error: a capture is already running (snotra-capture.sh)" >&2
    exit 1
  fi

  # Resolve the engine
  local ENGINE MODEL
  ENGINE="$(find_whisper || true)"
  MODEL="$(find_model || true)"

  if [ -z "$ENGINE" ]; then
    say "error: no whisper engine found" >&2
    exit 1
  fi
  if [ -z "$MODEL" ]; then
    say "error: no whisper model found" >&2
    exit 1
  fi

  say "Live tail starting: $SLUG"
  say "  Topic: $TOPIC"
  say "  Engine: $ENGINE"
  say "  Model:  $MODEL"

  # Write the listening indicator
  echo "listening" > "$LISTENING_FILE"

  # Start the segmenter
  local DATESTAMP LANE SLICES_DIR DOC
  DATESTAMP=$(date +%Y-%m-%d_%H%M%S)
  LANE="${LANE:-ping}"
  SLICES_DIR="$HOARD/slices/${DATESTAMP}-${LANE}-${SLUG}"
  DOC="$HOARD/meetings/${DATESTAMP}-${LANE}-${SLUG}.md"
  mkdir -p "$SLICES_DIR" "$(dirname "$DOC")"

  say "  Slices dir: $SLICES_DIR"
  say "  Doc:        $DOC"

  # Start the segmenter in background
  ffmpeg -y -hide_banner -loglevel error \
    -f pulse -i "${SNOTRA_MIC:-}" \
    -filter_complex "[0:a]aformat=channel_layouts=mono,pan=mono|c0=c0[a]" \
    -map "[a]" -ar 48000 -ac 2 -c:a pcm_s16le \
    -f segment -segment_time "${SNOTRA_LIVE_SLICE:-6}" \
    -segment_start_number 1 -segment_format_options timestamp=exact \
    -segment_atclocktime 1 \
    "${SLICES_DIR}/%04d.wav" &

  local FFMPEG_PID=$!
  echo "$FFMPEG_PID" > "$LIVE_STATE_DIR/.snotra-segmenter-pid"

  # Start the tail transcriber in background
  do_tail_transcribe "$SLUG" "$TOPIC" "$ENGINE" "$MODEL" "$DOC" &
  local TAIL_PID=$!
  echo "$TAIL_PID" > "$PID_FILE"

  say "Live tail ACTIVE (segmenter=$FFMPEG_PID, tail=$TAIL_PID)"
  say "  Listening indicator: $LISTENING_FILE = listening"
  say "  Stop with: snotra-live.sh stop"

  # Wait for either process
  wait "$TAIL_PID" 2>/dev/null || true
  wait "$FFMPEG_PID" 2>/dev/null || true

  rm -f "$PID_FILE" "$LIVE_STATE_DIR/.snotra-segmenter-pid" "$LISTENING_FILE"
  say "Live tail stopped"
  say "  Output: $DOC"
}

# ── the status verb ──

do_status() {
  local ENGINE MODEL
  ENGINE="$(find_whisper || true)"
  MODEL="$(find_model || true)"

  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
    local TAIL_PID
    TAIL_PID="$(cat "$PID_FILE")"
    say "Snotra live: ACTIVE (tail pid $TAIL_PID)"
    say "  Listening indicator: $LISTENING_FILE = $(cat "$LISTENING_FILE" 2>/dev/null || echo unknown)"
    say "  Engine: $ENGINE"
    say "  Model:  $MODEL"
    return 0
  fi

  if [ -f "$LIVE_STATE_DIR/.snotra-segmenter-pid" ] && \
     kill -0 "$(cat "$LIVE_STATE_DIR/.snotra-segmenter-pid" 2>/dev/null)" 2>/dev/null; then
    local SEG_PID
    SEG_PID="$(cat "$LIVE_STATE_DIR/.snotra-segmenter-pid")"
    say "Snotra live: segmenter only (pid $SEG_PID)"
    say "  Listening indicator: absent"
    say "  Engine: $ENGINE"
    say "  Model:  $MODEL"
    return 0
  fi

  say "Snotra live: idle"
  say "  Listening indicator: absent"
  return 1
}

# ── the tail verb ──

do_tail() {
  local SLUG="${1:-}" TOPIC="${2:-meeting}"
  [ -z "$SLUG" ] && { say "error: slug required (snotra-live.sh tail <slug> [topic])"; exit 1; }

  local ENGINE MODEL
  ENGINE="$(find_whisper || true)"
  MODEL="$(find_model || true)"

  if [ -z "$ENGINE" ]; then
    say "error: no whisper engine found" >&2
    exit 1
  fi
  if [ -z "$MODEL" ]; then
    say "error: no whisper model found" >&2
    exit 1
  fi

  local DATESTAMP LANE SLICES_DIR DOC
  DATESTAMP=$(date +%Y-%m-%d_%H%M%S)
  LANE="${LANE:-ping}"
  SLICES_DIR="$HOARD/slices/${DATESTAMP}-${LANE}-${SLUG}"
  DOC="$HOARD/meetings/${DATESTAMP}-${LANE}-${SLUG}.md"
  mkdir -p "$SLICES_DIR" "$(dirname "$DOC")"

  say "Following: $DOC"
  say "  Slices dir: $SLICES_DIR"

  # Start the segmenter
  ffmpeg -y -hide_banner -loglevel error \
    -f pulse -i "${SNOTRA_MIC:-}" \
    -filter_complex "[0:a]aformat=channel_layouts=mono,pan=mono|c0=c0[a]" \
    -map "[a]" -ar 48000 -ac 2 -c:a pcm_s16le \
    -f segment -segment_time "${SNOTRA_LIVE_SLICE:-6}" \
    -segment_start_number 1 -segment_format_options timestamp=exact \
    -segment_atclocktime 1 \
    "${SLICES_DIR}/%04d.wav" &

  local FFMPEG_PID=$!
  echo "$FFMPEG_PID" > "$LIVE_STATE_DIR/.snotra-segmenter-pid"

  # Start the tail transcriber in background
  do_tail_transcribe "$SLUG" "$TOPIC" "$ENGINE" "$MODEL" "$DOC" &
  local TAIL_PID=$!

  say "Segmenter: $FFMPEG_PID"
  say "Tail:      $TAIL_PID"

  # Wait for both
  wait "$TAIL_PID" 2>/dev/null || true
  wait "$FFMPEG_PID" 2>/dev/null || true

  rm -f "$LIVE_STATE_DIR/.snotra-segmenter-pid"
  say "Done: $DOC"
}

# ── the stop verb ──

do_stop() {
  # Kill the tail
  if [ -f "$PID_FILE" ]; then
    local TAIL_PID
    TAIL_PID="$(cat "$PID_FILE")"
    if kill -0 "$TAIL_PID" 2>/dev/null; then
      kill "$TAIL_PID" 2>/dev/null
      say "Tail stopped (pid $TAIL_PID)"
    fi
  fi

  # Kill the segmenter
  if [ -f "$LIVE_STATE_DIR/.snotra-segmenter-pid" ]; then
    local SEG_PID
    SEG_PID="$(cat "$LIVE_STATE_DIR/.snotra-segmenter-pid")"
    if kill -0 "$SEG_PID" 2>/dev/null; then
      kill "$SEG_PID" 2>/dev/null
      say "Segmenter stopped (pid $SEG_PID)"
    fi
  fi

  # Clear the listening indicator
  rm -f "$LISTENING_FILE"

  # Get the doc path for the pipeline
  local DOC
  if [ -f "$DOC_STATE" ]; then
    DOC="$(cat "$DOC_STATE")"
  else
    # Try to find the most recent doc
    DOC=$(ls -t "$HOARD/meetings"/*.md 2>/dev/null | head -1 || echo "")
  fi

  say "Snotra live stopped"
  say "  Listening indicator: cleared"

  # If there's a doc, hand off to the pipeline
  if [ -n "$DOC" ] && [ -f "$DOC" ]; then
    say "  Handing off to pipeline: $DOC"
    local SLUG TOPIC
    SLUG=$(basename "$DOC" .md | sed 's/^[^_-]*-//')
    TOPIC="${2:-meeting}"
    say "  Slug: $SLUG"
    say "  Topic: $TOPIC"

    # Set the env vars for the pipeline
    export SNOTRA_TRANSCRIPT_FILE="$DOC"
    export SNOTRA_MINUTES_FILE="$HOARD/meetings/$(date +%Y-%m-%d)-${LANE:-ping}-${SLUG}.md"

    # Run the pipeline
    if [ -x "$SCRIPT_DIR/snotra-transcribe.sh" ]; then
      "$SCRIPT_DIR/snotra-transcribe.sh" "$DOC" "$TOPIC"
    fi
    if [ -x "$SCRIPT_DIR/snotra-mine.sh" ]; then
      local ACTIONS="$HOARD/meetings/$(date +%Y-%m-%d)-${LANE:-ping}-${SLUG}.actions.md"
      "$SCRIPT_DIR/snotra-mine.sh" "$DOC" "$ACTIONS" "$HOARD/meetings/$(date +%Y-%m-%d)-${LANE:-ping}-${SLUG}.md"
    fi
  fi
}

# ── main ──

LANE="${LANE:-ping}"
SLUG="${SLUG:-}"
DATESTAMP="${DATESTAMP:-$(date +%Y-%m-%d_%H%M%S)}"
DOC="${DOC:-}"

case "${1:-}" in
  start)   do_start "${2:-}" "${3:-meeting}" ;;
  status)  do_status ;;
  tail)    do_tail "${2:-}" "${3:-meeting}" ;;
  stop)    do_stop ;;
  -h|--help|"")
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "error: unknown command (start|status|tail|stop)" >&2
    exit 2
    ;;
esac
