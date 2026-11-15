#!/usr/bin/env bash
# systems/snotra/services/ear/snotra-capture.sh — THE capture door (plan 129).
#
#   snotra-capture.sh start [seconds] | stop | status | devices
#
# THE DOOR THAT WAS DEAD (fixed 2026-11-09, plan 228 · F1). This file is the door, not a shim —
# but the move from bin/time/snotra/ copied a shim preamble in on top of it, and the preamble
# computed its target as `$_d/../../..` (from `systems/snotra/services/ear` that is `<repo>/systems`,
# not the repo root). So EVERY invocation — `start`, `stop`, `status` — printed
#   *snotra: the door moved to systems/snotra/services/ear/snotra-capture.sh and is not there*
# and exited 127. The watch was alive, the ear was not: `snotra-detect.sh` armed, called this
# door, and got a 127 nobody read. The microphone was never opened, and every capture since the
# move was a refusal reported as a door move. The preamble is gone; the door is the door.
set -euo pipefail
# The repo root, found by walking up to the tree that carries RULES/ and .agents/ — never a
# fixed number of `../`. In a flat fleet install (~/.fleet) there is no tree, and the hotline
# is then simply absent rather than a wrong path (RULES/25: a clean skip is a pass).
_d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$_d"
while [ "$ROOT" != / ] && { [ ! -d "$ROOT/RULES" ] || [ ! -d "$ROOT/.agents" ]; }; do ROOT="$(dirname "$ROOT")"; done
[ -d "$ROOT/RULES" ] || ROOT=""
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _lib in ${ROOT:+"$ROOT/bin/vault/hoard-lib.sh"} "$_d/hoard-lib.sh"; do
    [ -r "$_lib" ] && . "$_lib" 2>/dev/null && break
  done
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi
[ -n "${YMIR_HOME:-}" ] || { printf 'snotra-capture: the home is unresolved — bin/vault/hoard-lib.sh answered nothing\n' >&2; exit 2; }

YMIR_HOME="${YMIR_HOME}"
HOARD="$YMIR_HOME/hodd/life/meetings"
STATE_DIR="${YMIR_STATE_DIR:-$YMIR_HOME/state}"
LISTENING_FILE="$STATE_DIR/.snotra-listening"
PID_FILE="$STATE_DIR/.snotra-pid"
OUTFILE_STATE="$STATE_DIR/.snotra-outfile"
MODE_FILE="$STATE_DIR/.snotra-mode"

mkdir -p "$HOARD" "$STATE_DIR"

say() { printf '%s\n' "$*"; }

# ── the hotline (plan 100): a capture nobody hears about is a capture nobody uses ──
# Measured 2026-11-09: nothing under systems/snotra/ ever called bin/notify/send.sh, so a
# meeting was recorded, transcribed and filed with no word to the Allfather — his words:
# "i dont get any notifications of this at all now". This is the missing sentence.
say_hotline() {  # <severity> <one line> <stable key>
  local door="${ROOT:+$ROOT/bin/notify/send.sh}"
  [ -n "$door" ] && [ -x "$door" ] || return 0
  "$door" --source snotra --severity "$1" --message "$2" --key "$3" >/dev/null 2>&1 || true
}


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
  # `SNOTRA_MONITOR=off` is the explicit MICS-ONLY door (added 2026-10-07 with
  # the live tail, snotra-live.sh). It has to exist because "unset" cannot mean
  # "no system audio": unset resolves to the default sink, so before this there
  # was no way to ask for the microphone alone. The default is UNCHANGED — the
  # watch still captures the conversation pair.
  if [ "$sink" = "off" ] || [ "$sink" = "none" ]; then
    sink=""
  elif [ -z "$sink" ]; then
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

  # THE ALLFATHER'S LAW (2026-10-31, sharpened 2026-11-09): the MICROPHONE is never
  # opened to hear a call. *"we should lissen internally"* — the internal stream is
  # the sink monitor, and a monitor tap competes with nothing: the client that owns
  # the call keeps it. Opening the physical device is what took the mic from Discord
  # mid-call. So the refusal is about the DEVICE, not about the name of the mode:
  #   · no microphone resolved (SNOTRA_MIC= or no default source) → the internal
  #     stream only → allowed, always, and no device is opened;
  #   · a microphone resolved → a LOCAL room, people physically here → allowed only
  #     when it is asked for by name (SNOTRA_LOCAL_ROOM=1);
  #   · otherwise → refused, with the door that does it properly (the bot).
  if [ -n "$MIC" ] && [ "${SNOTRA_LOCAL_ROOM:-0}" != "1" ]; then
    printf 'snotra-capture[2]{state,reason,door}:\n  "refused","a microphone would be opened and no LOCAL room was asked for — a call is heard by the BOT","snotra-bot.sh join <meet-url>"\n  "allowed","set SNOTRA_MIC= to listen to the internal stream only (the sink monitor), or SNOTRA_LOCAL_ROOM=1 for a room you are in","-"\n' >&2
    return 2
  fi
  if [ -z "$MONITOR" ] && [ -z "$MIC" ]; then
    printf 'error: no audio device resolved; run %s devices\n' "$(basename "$0")" >&2
    exit 1
  fi
  printf '%s\n' "$([ -n "$MIC" ] && printf 'room — the sink monitor and the microphone' || printf 'internal — the sink monitor only, no microphone opened')" > "${MODE_FILE:-/dev/null}" 2>/dev/null || true

  local DATESTAMP OUTFILE
  DATESTAMP=$(date +%Y-%m-%d_%H%M%S)
  OUTFILE="${SNOTRA_OUTFILE:-$HOARD/meeting-${DATESTAMP}.wav}"
  mkdir -p "$(dirname "$OUTFILE")" 2>/dev/null || true

  say_hotline INFO "listening to a call — capture starting ($(basename "$OUTFILE"))" "snotra-capture-start-$DATESTAMP"
  say "Snotra capture starting…"
  say "  Sink monitor: ${MONITOR:-(none)}"
  say "  Mic source:   ${MIC:-(none)}"
  say "  Output:       $OUTFILE"
  if [ "${SNOTRA_CHANNELS:-stereo}" = "stereo" ]; then
    say "  Channels:     stereo — mic = channel 0 (you), system = channel 1 (others)"
  else
    say "  Channels:     mono (mixed) — set SNOTRA_CHANNELS=stereo to keep the two sides apart"
  fi

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
  #
  # THE CHANNEL ASSIGNMENT IS LOAD-BEARING. whisper.cpp's `-di` calls the
  # speaker by whichever channel's energy dominates a segment, so the operator's
  # mic must be channel 0 and the room (the sink monitor) channel 1. Measured on
  # 2026-09-28: with the monitor on channel 0 the remote side came back
  # `(speaker 0)` — the
  # two sides swapped. Set SNOTRA_CHANNELS=mono for the old mixed-down file (a
  # 2-channel file is safe either way: without `-di` the decoder downmixes it).
  if [ -n "$MONITOR" ] && [ -n "$MIC" ]; then
    if [ "${SNOTRA_CHANNELS:-stereo}" = "stereo" ]; then
      # input 0 is the monitor, input 1 the mic — so the FILTER re-orders them:
      # [1:a] (mic) -> channel 0, [0:a] (monitor) -> channel 1.
      ffmpeg -y -hide_banner -loglevel error \
        -f pulse -i "$MONITOR" \
        -f pulse -i "$MIC" \
        -filter_complex "[1:a]aformat=channel_layouts=mono,pan=mono|c0=c0[me];[0:a]aformat=channel_layouts=mono,pan=mono|c0=c0[them];[me][them]amerge=inputs=2[a]" \
        -map "[a]" -ar 48000 -ac 2 -c:a pcm_s16le \
        "${DUR[@]}" "$OUTFILE" &
    else
      ffmpeg -y -hide_banner -loglevel error \
        -f pulse -i "$MONITOR" \
        -f pulse -i "$MIC" \
        -filter_complex "[0:a][1:a]amix=inputs=2:duration=longest:dropout_transition=0" \
        -ar 48000 -ac 2 -c:a pcm_s16le \
        "${DUR[@]}" "$OUTFILE" &
    fi
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
  # the chosen recording path, so the finalize pipeline never has to guess it
  printf '%s\n' "$OUTFILE" > "$OUTFILE_STATE"

  say "Snotra capture ACTIVE (pid $FFMPEG_PID)"
  say "  Listening indicator: $LISTENING_FILE = recording"
  say "  Stop with: snotra-capture.sh stop"

  wait "$FFMPEG_PID" 2>/dev/null || true

  rm -f "$PID_FILE" "$LISTENING_FILE"
  # .snotra-outfile is deliberately KEPT: the pipeline reads it after the stop
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
      # The call is over: say where the sound went, so the transcript is not a secret.
      say_hotline HIGH "call captured — the audio is ready to transcribe" "snotra-capture-stop-$(date -u +%Y%m%dT%H%M%SZ)"
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
      say "  Listening to:        $(cat "$MODE_FILE" 2>/dev/null || echo 'unknown mode')"
      say "  Chosen monitor:      $(resolve_devices | sed -n 1p)"
      say "  Chosen mic:          $(resolve_devices | sed -n 2p)"
      return 0
    fi
  fi
  say "Snotra capture: idle"
  say "  Listening indicator: absent"
  say "  Last mode:           $(cat "$MODE_FILE" 2>/dev/null || echo 'never captured here')"
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
