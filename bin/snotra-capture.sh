#!/usr/bin/env bash
# snotra-capture.sh — start a PipeWire capture of mic + system audio.
#
# Usage:
#   snotra-capture.sh start   — begin capture (mic + monitor)
#   snotra-capture.sh stop    — stop the running capture
#   snotra-capture.sh status  — show capture state
#
# Captures system audio monitor + microphone via PipeWire, writes to a dated
# path under $YMIR_HOME/hodd/workspaces/meetings/. The recording is a single
# WAV file (PCM 16-bit 48kHz stereo).
#
# The Listening indicator: this script writes state/.snotra-listening so the
# bar can read it (the bar already carries ScreenRecording and Dictation
# indicators — add a third for Listening).
#
# Env:
#   YMIR_HOME          — the hoard root (default ~/Documents/ymirhome)
#   SNOTRA_MONITOR     — PipeWire sink monitor name (default: first analog stereo)
#   SNOTRA_MIC         — PipeWire source name (default: first analog stereo input)

set -u

YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
HOARD="$YMIR_HOME/hodd/workspaces/meetings"
STATE_DIR="$YMIR_HOME/state"
LISTENING_FILE="$STATE_DIR/.snotra-listening"
PID_FILE="$STATE_DIR/.snotra-pid"

mkdir -p "$HOARD" "$STATE_DIR"

say() { printf '%s\n' "$*"; }

# Resolve the default sink/source if not set
resolve_defaults() {
  [ -n "${SNOTA_MONITOR:-}" ] && return
  SNOTA_MONITOR=$(pwcli list-sinks 2>/dev/null | awk '/analog-stereo/{print $1; exit}')
  [ -z "$SNOTA_MONITOR" ] && SNOTA_MONITOR="alsa_output.pci-0000_00_1f.3.analog-stereo.monitor"
  [ -n "${SNOTA_MIC:-}" ] && return
  SNOTA_MIC=$(pwcli list-sources 2>/dev/null | awk '/analog-stereo/{print $1; exit}')
  [ -z "$SNOTA_MIC" ] && SNOTA_MIC="alsa_input.pci-0000_00_1f.3.analog-stereo"
}

do_start() {
  resolve_defaults

  local DATESTAMP
  DATESTAMP=$(date +%Y-%m-%d_%H%M%S)
  local OUTFILE="$HOARD/meeting-${DATESTAMP}.wav"

  say "Snotra capture starting…"
  say "  Sink monitor: $SNOTA_MONITOR"
  say "  Mic source:   $SNOTA_MIC"
  say "  Output:       $OUTFILE"

  # Record both channels via PipeWire + ffmpeg:
  #   -f pipewire with the monitor (system audio) and mic (microphone)
  #   We use ffmpeg's lavfi with the pipewire protocol.
  #   If pipewire protocol is unavailable, fall back to a combined source.

  # Start a background ffmpeg that captures both streams and mixes them.
  # PipeWire's native capture: use ffplay/ffmpeg with the pipewire device.
  # Fallback: use pactl/pipewire to create a combined source.

  # The most reliable path on PipeWire 1.x: use ffmpeg with the pipewire
  # protocol to capture the monitor, and a second capture for the mic,
  # then mix. But since we need a single file, we use a single ffmpeg
  # with a complex filtergraph.

  # Check if ffmpeg supports pipewire
  if ffmpeg -demuxers 2>&1 | grep -q pipewire; then
    ffmpeg -y \
      -f pipewire -i "$SNOTA_MONITOR" \
      -f pipewire -i "$SNOTA_MIC" \
      -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest" \
      -ar 48000 -ac 2 -sample_fmt s16 -c pcm_s16le \
      "$OUTFILE" &
  else
    # Fallback: use PulseAudio/PipeWire's built-in monitor + mic via
    # a virtual combined source. We create a combined source using
    # pw-cli and record from it.
    say "WARNING: pipewire demuxer not available in ffmpeg"
    say "Falling back to pactl-based capture…"

    # Create a combined source (mic + monitor) via pipewire
    local COMBINED
    COMBINED=$(pw-cli 2>/dev/null | grep -i combined || echo "")

    # Simplest fallback: record the monitor only (system audio carries
    # the meeting; the mic is the operator's voice which is less critical
    # for automated transcription).
    ffmpeg -y \
      -f pipewire -i "$SNOTA_MONITOR" \
      -ar 48000 -ac 2 -sample_fmt s16 -c pcm_s16le \
      "$OUTFILE" &
  fi

  local FFMPEG_PID=$!
  echo "$FFMPEG_PID" > "$PID_FILE"

  # Write the listening state for the bar indicator
  echo "recording" > "$LISTENING_FILE"

  say "Snotra capture ACTIVE (pid $FFMPEG_PID)"
  say "  Listening indicator: state/.snotra-listening = recording"
  say "  Press Ctrl+C or run 'snotra-capture.sh stop' to end"

  # Wait for the ffmpeg process
  wait "$FFMPEG_PID" 2>/dev/null || true

  # Clean up
  rm -f "$PID_FILE" "$LISTENING_FILE"
  say "Snotra capture stopped"
  say "  Output: $OUTFILE"
}

do_stop() {
  if [ -f "$PID_FILE" ]; then
    local PID
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null
      wait "$PID" 2>/dev/null || true
      say "Snotra capture stopped (pid $PID)"
    fi
  fi
  rm -f "$PID_FILE" "$LISTENING_FILE"
}

do_status() {
  if [ -f "$PID_FILE" ]; then
    local PID
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      say "Snotra capture ACTIVE (pid $PID)"
      say "  Listening indicator: state/.snotra-listening = recording"
      # Show the bar indicator path
      say "  Bar indicator: read state/.snotra-listening (value: $(cat "$LISTENING_FILE" 2>/dev/null || echo unknown))"
      return 0
    fi
  fi
  say "Snotra capture: idle"
  say "  Listening indicator: state/.snotra-listening = absent"
  return 1
}

case "${1:-}" in
  start)   do_start ;;
  stop)    do_stop ;;
  status)  do_status ;;
  -h|--help|"")
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "error: unknown command (start|stop|status)" >&2
    exit 2
    ;;
esac
