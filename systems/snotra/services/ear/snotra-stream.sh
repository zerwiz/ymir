#!/usr/bin/env bash
# snotra-stream.sh — Snotra's voice into a meeting: say, and (later) the full loop.
#
#   snotra-stream.sh say "text" [--voice am_onyx] [--meeting <id>]
#   snotra-stream.sh talk [--listen <source>] [--name Skírnir] [--once]
#   snotra-stream.sh mute | unmute
#   snotra-stream.sh status
#   snotra-stream.sh stop          (stop any playback now)
#
# `talk` is the streaming loop (plan 34 applied to a room, plan 87's voice): it hears
# in ~2 s chunks, answers only when NAMED, composes one short answer on the rail, and
# speaks sentence by sentence — Kokoro rendering the next sentence while the current
# one plays. Its implementation is snotra-talk.py beside this door.
#
# The voice is Kokoro (local, fast, 24 kHz); the audio goes into the "Snotra Mic"
# virtual source, which the meeting client selects as its microphone.
#
# Env: SNOTRA_VOICE (default am_onyx), SNOTRA_MIC_NAME (default snotra_mic)
set -u
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-status}"; shift || true
ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; s="$d"; while [ "$d" != / ] && { [ ! -d "$d/RULES" ] || [ ! -d "$d/.agents" ]; }; do d="$(dirname "$d")"; done; { [ -d "$d/RULES" ] && [ -d "$d/.agents" ]; } || d="$s"; printf '%s' "$d")"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
STATE_DIR="${YMIR_HOME:-$HOME}/hodd/state/snotra"; mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/talk.log"
MIC="${SNOTRA_MIC_NAME:-snotra_mic}"
VOICE="${SNOTRA_VOICE:-am_onyx}"
PIDFILE="$STATE_DIR/voice.pid"
MUTE_FILE="$STATE_DIR/voice-muted"
ANN_FILE="$STATE_DIR/voice-announced"
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
command -v kokoro >/dev/null || die "kokoro not found"
command -v paplay >/dev/null || die "paplay not found"

say(){
  local text="" meeting=""
  text="${1-}"; shift 2>/dev/null || true
  [ -n "$text" ] || die "say needs text"
  [ -e "$MUTE_FILE" ] && { printf 'refused: muted — run %s unmute\n' "$0" >&2; exit 3; }
  while [ $# -gt 0 ]; do case "$1" in
    --voice) VOICE="${2-}"; shift 2 ;;
    --meeting) meeting="${2-}"; shift 2 ;;
    *) die "unknown option: $1" ;; esac; done
  [ -e "$ANN_FILE" ] || text="Skírnir, the Allfather's assistant, speaking. $text"
  bash "$ROOT/systems/snotra/services/ear/snotra-voice-device.sh" ensure >/dev/null || die "voice device failed"
  local wav; wav="$(mktemp --suffix=.wav)"
  local t0 t1 t2; t0="$(date +%s%3N)"
  kokoro speak -v "$VOICE" -o "$wav" "$text" >/dev/null 2>&1 || die "kokoro synthesis failed"
  t1="$(date +%s%3N)"
  paplay --device="$MIC" "$wav" || die "playback failed"
  t2="$(date +%s%3N)"
  rm -f "$wav"
  { [ -e "$ANN_FILE" ] || date -Iseconds > "$ANN_FILE"; } 2>/dev/null || true
  python3 - "$LOG" "$meeting" "$VOICE" "$t0" "$t1" "$t2" "$text" <<'PY'
import sys,json,datetime
log,meeting,voice,t0,t1,t2,text=sys.argv[1:]
row={"at":datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
     "meeting":meeting or None,"voice":voice,"synth_ms":int(t1)-int(t0),
     "play_ms":int(t2)-int(t1),"chars":len(text),"text":text[:500]}
open(log,"a").write(json.dumps(row)+"\n")
print(f"said\t{row['synth_ms']}ms synth\t{row['play_ms']}ms play\t{voice}")
PY
}
status(){
  printf 'voice[1]{ready,mic,voice}:\n'
  if command -v kokoro >/dev/null && pactl list short sources 2>/dev/null | awk '{print $2}' | grep -qx "$MIC"; then
    printf '  "yes","%s","%s"\n' "$MIC" "$VOICE"
  else printf '  "no","%s","%s"\n' "$MIC" "$VOICE"; fi
  [ -r "$LOG" ] && tail -3 "$LOG"
}
stop(){
  if [ -f "$PIDFILE" ]; then kill "$(cat "$PIDFILE")" 2>/dev/null || true; rm -f "$PIDFILE"; fi
  pkill -f "^paplay --device=$MIC" 2>/dev/null || true
  printf 'voice\tstopped\n'
}
talk(){ exec python3 "$ROOT/systems/snotra/services/ear/snotra-talk.py" "$@" ; }
mute(){ printf 'muted %s\n' "$(date -Iseconds)" > "$MUTE_FILE"; printf 'mute\t%s\tthe next word needs `unmute`\n' "$(date -Iseconds)"; }
unmute(){ rm -f "$MUTE_FILE" "$ANN_FILE"; printf 'unmute\t%s\tthe first word names the speaker again\n' "$(date -Iseconds)"; }
case "$ACTION" in
  say) say "$@" ;;
  talk) talk "$@" ;;
  mute) mute ;;
  unmute) unmute ;;
  status) status ;;
  stop) stop ;;
  *) printf 'usage: snotra-stream.sh say "text" [--voice V] [--meeting ID] | status | stop\n' >&2; exit 2 ;;
esac
