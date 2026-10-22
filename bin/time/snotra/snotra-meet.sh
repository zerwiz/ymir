#!/usr/bin/env bash
# snotra-meet.sh — the meeting voice: one door, and the browser is the audio device.
#
# Why it is shaped this way (measured 2026-10-22, plan 87 appendix): this seat's
# PulseAudio reported success while carrying silence — null-sink monitors read zeros,
# `pw-record --target` was ignored, and a joined participant was never heard in the
# room's own recording. So the audio never touches the OS mixer: the page's
# `getUserMedia` is replaced with a stream we fill over the DevTools protocol, and
# every remote track is teed back to us the same way. `snotra-cdp.py` is that bridge.
#
#   snotra-meet.sh launch [--url URL] [--profile DIR] [--port N] [--headed]
#   snotra-meet.sh install --port N          # install the bridge in the open page
#   snotra-meet.sh join    --name Skírnir [--url URL] [--port N]
#   snotra-meet.sh selftest --port N         # THE ORACLE: said vs heard must match
#   snotra-meet.sh run      --port N [--name Skírnir]    # hear the room, answer in it
#   snotra-meet.sh say      --port N "text"   # one line into the meeting
#   snotra-meet.sh state    --port N
#   snotra-meet.sh stop
#
# Exit: 0 ok · 1 selftest failed · 2 usage · 3 not in a call · 4 bridge missing
set -uo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-state}"; shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
BRIDGE="$ROOT/bin/time/snotra/snotra-cdp.py"
TALK="$ROOT/bin/time/snotra/snotra-talk.py"
STATE_DIR="${YMIR_HOME:-$HOME}/hodd/state/snotra"; mkdir -p "$STATE_DIR"
PORT=9222
NAME="Skírnir"
die(){ printf 'error: %s\n' "$*" >&2; exit 2; }

# The voice is idle-lowered by design; every speaking door raises it first.
ensure_voice(){
  systemctl --user is-active kokoro-serve.service >/dev/null 2>&1 && return 0
  systemctl --user start kokoro-serve.service >/dev/null 2>&1 || return 1
  local i; for i in $(seq 1 20); do
    sleep 1
    (exec 3<>/dev/tcp/127.0.0.1/8765) 2>/dev/null && { exec 3>&-; return 0; }
  done
  return 1
}

ARG_PORT=""
REST=()
while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="${2-}"; shift 2 ;;
    --name) NAME="${2-}"; shift 2 ;;
    --url|--profile) REST+=("$1" "${2-}"); shift 2 ;;
    --headed) REST+=("$1"); shift ;;
    *) REST+=("$1"); shift ;;
  esac
done

case "$ACTION" in
  launch)
    python3 "$BRIDGE" launch --port "$PORT" "${REST[@]+"${REST[@]}"}" ;;
  install)
    python3 "$BRIDGE" install --port "$PORT" ;;
  join)
    python3 "$BRIDGE" install --port "$PORT" >/dev/null || true
    python3 "$BRIDGE" join --port "$PORT" --name "$NAME" "${REST[@]+"${REST[@]}"}" ;;
  selftest)
    ensure_voice || die "the voice engine did not come up (kokoro-serve)"
    python3 "$BRIDGE" install --port "$PORT" >/dev/null || true
    python3 "$BRIDGE" selftest --port "$PORT" "${REST[@]+"${REST[@]}"}" ;;
  say)
    [ $# -ge 1 ] || [ ${#REST[@]} -gt 0 ] || die "say needs text"
    TEXT="${REST[*]:-}"
    [ -n "$TEXT" ] || die "say needs text"
    ensure_voice || die "the voice engine did not come up (kokoro-serve)"
    WAV="$(mktemp --suffix=.wav)"
    curl -sS -m 120 -o "$WAV" -X POST http://127.0.0.1:8765/v1/audio/speech \
      -H 'Content-Type: application/json' \
      -d "$(python3 -c 'import json,sys;print(json.dumps({"model":"kokoro","input":sys.argv[1],"voice":"af_nicole","response_format":"wav"}))' "$TEXT")" \
      || die "the voice refused the text"
    python3 "$BRIDGE" say --port "$PORT" --wav "$WAV"
    rm -f "$WAV" ;;
  run)
    ensure_voice || die "the voice engine did not come up (kokoro-serve)"
    exec python3 "$TALK" --page "$PORT" --name "$NAME" "${REST[@]+"${REST[@]}"}" ;;
  state)
    python3 "$BRIDGE" state --port "$PORT" ;;
  stop)
    pc=$(ss -tlnp 2>/dev/null | awk -v p=":$PORT" '$4 ~ p {print $NF}' | grep -oE 'pid=[0-9]+' | cut -d= -f2 | sort -u)
    [ -n "$pc" ] && for p in $pc; do kill "$p" 2>/dev/null && printf 'closed\t%s\n' "$p"; done
    printf 'stopped\tport=%s\n' "$PORT" ;;
  *) die "unknown action: $ACTION" ;;
esac
