#!/usr/bin/env bash
# snotra-capture.sh — capture mic + system audio on the meeting seat.
#
# Usage:
#   snotra-capture.sh start [seconds]   — begin capture (mic + monitor)
#   snotra-capture.sh stop              — stop the running capture
#   snotra-capture.sh status            — show capture state
#   snotra-capture.sh devices           — list sinks/sources and the chosen pair
#
# Captures the system-audio monitor and the microphone, mixes them, and writes
# a dated WAV under $YMIR_HOME/hodd/workspaces/meetings/. PipeWire exposes the
# monitor of any sink, so no virtual loopback device is needed.
#
# Capture is via the PulseAudio protocol (`-f pulse`), which PipeWire serves
# through pipewire-pulse on every Omarchy seat — the native `pipewire` ffmpeg
# demuxer is not present in the fleet's ffmpeg builds.
#
# The Listening indicator: this script writes state/.snotra-listening so the
# bar can read it (the bar already carries ScreenRecording and Dictation
# indicators — add a third for Listening).
#
# Env:
#   YMIR_HOME          — the hoard root (default ~/Documents/ymirhome)
#   SNOTRA_MONITOR     — sink monitor name (default: the running/default sink)
#   SNOTRA_MIC         — source name (default: the running/default input)

set -u
# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "${ROOT:-}/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/hoard-lib.sh"; do
    [ -n "$_yc" ] && [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi

YMIR_HOME="${YMIR_HOME}"
HOARD="$YMIR_HOME/hodd/workspaces/meetings"
STATE_DIR="$YMIR_HOME/state"
LISTENING_FILE="$STATE_DIR/.snotra-listening"
PID_FILE="$STATE_DIR/.snotra-pid"

mkdir -p "$HOARD" "$STATE_DIR"

say() { printf '%s\n' "$*"; }

# pactl is the portable surface (PipeWire serves the PulseAudio protocol on
# every seat); fall back to wpctl when pactl is absent.
have_pactl() { command -v pactl >/dev/null 2>&1; }

default_sink() {
  if have_pactl; then
    pactl get-default-sink 2>/dev/null && return
  fi
  wpctl status 2>/dev/null | awk '/Sinks:/{f=1} f&&/\*/{print $2; exit}'
}

default_source() {
  if have_pactl; then
    pactl get-default-source 2>/dev/null && return
  fi
  wpctl status 2>/dev/null | awk '/Sources:/{f=1} f&&/\*/{print $2; exit}'
}

resolve_devices() {
  local sink source
  sink="${SNOTRA_MONITOR:-}"
  if [ -z "$sink" ]; then
    sink="$(default_sink)"
    # the monitor of the default sink is what carries system audio
    [ -n "$sink" ] && case "$sink" in *.monitor) ;; *) sink="$sink.monitor" ;; esac
  fi
  source="${SNOTRA_MIC:-}"
  if [ -z "$source" ]; then
    source="$(default_source)"
  fi
  printf '%s\n%s\n' "$sink" "$source"
}

list_devices() {
  say "Sinks (system audio — capture the .monitor):"
  if have_pactl; then pactl list short sinks 2>/dev/null | sed 's/^/  /'; fi
  say "Sources (microphone):"
  if have_pactl; then pactl list short sources 2>/dev/null | sed 's/^/  /'; fi
  say ""
  local pair
  pair="$(resolve_devices)"
  say "Chosen monitor: $(printf '%s' "$pair" | sed -n 1p)"
  say "Chosen mic:     $(printf '%s' "$pair" | sed -n 2p)"
}

do_start() {
  local SECONDS_ARG="${1:-}"
  local pair MONITOR MIC
  # a dead capture leaves stale state behind; clear it before a new run
  if [ -f "$PID_FILE" ] && ! kill -0 "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null; then
    rm -f "$PID_FILE" "$LISTENING_FILE"
  fi
  pair="$(resolve_devices)"
  MONITOR="$(printf '%s' "$pair" | sed -n 1p)"
  MIC="$(printf '%s' "$pair" | sed -n 2p)"

  local DATESTAMP
  DATESTAMP=$(date +%Y-%m-%d_%H%M%S)
  local OUTFILE="$HOARD/meeting-${DATESTAMP}.wav"

  say "Snotra capture starting…"
  say "  Sink monitor: ${MONITOR:-(none)}"
  say "  Mic source:   ${MIC:-(none)}"
  say "  Output:       $OUTFILE"

  local -a DUR=()
  if [ -n "$SECONDS_ARG" ]; then
    DUR=(-t "$SECONDS_ARG")
    say "  Duration:     ${SECONDS_ARG}s"
  else
    # Safety cap: a capture left running must stop itself (default 4h).
    DUR=(-t "${SNOTRA_MAX_SECONDS:-14400}")
    say "  Duration:     ${SNOTRA_MAX_SECONDS:-14400}s max (safety cap)"
  fi

  # `-t` is an OUTPUT option — placed before the output file. As an input
  # option it limits only the first input, and amix(duration=longest) then
  # waits on the unbounded second input, so the capture never stops.
  # Mix the monitor (everyone else) with the mic (the operator). A missing
  # device degrades to the other alone rather than failing the capture.
  if [ -n "$MONITOR" ] && [ -n "$MIC" ]; then
    ffmpeg -y -hide_banner -loglevel error \
      -f pulse -i "$MONITOR" \
      -f pulse -i "$MIC" \
      -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest:dropout_transition=0" \
      -ar 48000 -ac 2 -c:a pcm_s16le \
      "${DUR[@]}" "$OUTFILE" &
  elif [ -n "$MONITOR" ]; then
    say "  (no microphone resolved — capturing system audio only)"
    ffmpeg -y -hide_banner -loglevel error \
      -f pulse -i "$MONITOR" -ar 48000 -ac 2 -c:a pcm_s16le \
      "${DUR[@]}" "$OUTFILE" &
  elif [ -n "$MIC" ]; then
    say "  (no monitor resolved — capturing microphone only)"
    ffmpeg -y -hide_banner -loglevel error \
      -f pulse -i "$MIC" -ar 48000 -ac 2 -c:a pcm_s16le \
      "${DUR[@]}" "$OUTFILE" &
  else
    echo "error: no audio device resolved; run 'snotra-capture.sh devices'" >&2
    exit 1
  fi

  local FFMPEG_PID=$!
  echo "$FFMPEG_PID" > "$PID_FILE"
  echo "recording" > "$LISTENING_FILE"

  say "Snotra capture ACTIVE (pid $FFMPEG_PID)"
  say "  Listening indicator: $LISTENING_FILE = recording"
  say "  Stop with: snotra-capture.sh stop"

  wait "$FFMPEG_PID" 2>/dev/null || true

  rm -f "$PID_FILE" "$LISTENING_FILE"
  say "Snotra capture stopped"
  say "  Output: $OUTFILE"
  [ -f "$OUTFILE" ] && say "  Size:   $(du -h "$OUTFILE" | cut -f1)"
}

do_stop() {
  if [ -f "$PID_FILE" ]; then
    local PID
    PID="$(cat "$PID_FILE")"
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID" 2>/dev/null
      say "Snotra capture stopped (pid $PID)"
    fi
  fi
  rm -f "$PID_FILE" "$LISTENING_FILE"
}

do_status() {
  if [ -f "$PID_FILE" ]; then
    local PID
    PID="$(cat "$PID_FILE")"
    if kill -0 "$PID" 2>/dev/null; then
      say "Snotra capture ACTIVE (pid $PID)"
      say "  Listening indicator: $LISTENING_FILE = $(cat "$LISTENING_FILE" 2>/dev/null || echo unknown)"
      return 0
    fi
  fi
  say "Snotra capture: idle"
  say "  Listening indicator: absent"
  return 1
}

case "${1:-}" in
  start)   do_start "${2:-}" ;;
  stop)    do_stop ;;
  status)  do_status ;;
  devices) list_devices ;;
  -h|--help|"")
    sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    echo "error: unknown command (start|stop|status|devices)" >&2
    exit 2
    ;;
esac
