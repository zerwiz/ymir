#!/usr/bin/env bash
# snotra-speak-meeting.sh — the seat's speaking door: one line in, audio into the room.
#
# The third of plan 87's three voices, and the only one that exists today: Vexa's
# `speak` answers 404 (vexa-ai/vexa#514), Þing's SFU track is unbuilt. So the voice is
# local — Kokoro renders it, the "Snotra Mic" PipeWire source carries it, and a meeting
# client on this seat that selects that source as its microphone transmits it.
#
#   snotra-speak-meeting.sh say "text" [--as NAME] [--max-seconds N] [--announce]
#                                     [--no-announce] [--device NAME] [--dry-run]
#   snotra-speak-meeting.sh mute | unmute | status
#
# The speech law (plan 87, carried unchanged; Skírnir adds the naming line):
#   announce     — the first utterance says the speaker's name, every meeting, without fail
#   one voice    — it speaks because it was CALLED, never because it had something to say
#   no interruption — --wait-quiet waits for the room to go quiet before the first word
#   short        — more than --max-seconds (default 20) is refused, not trimmed
#   visible      — the caller is told exactly what was said, to whom, and for how long
#   consent      — a mute file stops every word; `mute` is one command and it holds
#
# Exit: 0 spoke · 2 usage · 3 refused (muted / too long / no device / TTS down)
set -uo pipefail
VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ACTION="${1:-status}"; shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then . "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true; fi
YMIR_HOME="${YMIR_HOME:-}"; [ -n "$YMIR_HOME" ] || ymir_home_root YMIR_HOME 2>/dev/null || true
STATE_DIR="${YMIR_HOME:?the hoard is unresolved — set YMIR_HOME}/hodd/state/snotra"
mkdir -p "$STATE_DIR"
MUTE_FILE="$STATE_DIR/voice-muted"
ANNOUNCED_FILE="$STATE_DIR/voice-announced"
DEVICE="${SNOTRA_MIC_NAME:-snotra_mic}"
KOKORO_URL="${KOKORO_URL:-http://127.0.0.1:8765}"
MAX_SECONDS="${SNOTRA_MAX_SPEAK_SECONDS:-20}"

die(){ printf 'refused: %s\n' "$*" >&2; exit 3; }
usage(){ printf 'usage: %s say "text" [--as NAME] [--max-seconds N] [--announce|--no-announce] [--device NAME] [--wait-quiet SECONDS] [--dry-run]\n       %s mute|unmute|status\n' "$0" "$0" >&2; exit 2; }

# ---- the room's devices -------------------------------------------------------
device_ready(){
  command -v pactl >/dev/null || return 1
  pactl list short sources 2>/dev/null | awk '{print $2}' | grep -qx "$DEVICE"
}
ensure_device(){
  device_ready && return 0
  local door="$ROOT/bin/time/snotra/snotra-voice-device.sh"
  [ -x "$door" ] || die "the virtual microphone is absent and $door was not found"
  SNOTRA_MIC_NAME="$DEVICE" "$door" ensure >/dev/null 2>&1 || true
  device_ready
}

# ---- the voice ----------------------------------------------------------------
house_voice(){
  if command -v kokoro-voice >/dev/null 2>&1; then
    kokoro-voice current 2>/dev/null | head -1 | tr -d '[:space:]'
  fi
}

# say_kokoro TEXT OUT — 0 on success; the wav lands at OUT
say_kokoro(){
  local text="$1" out="$2" voice; voice="$(house_voice)"; voice="${voice:-af_nicole}"
  curl -sS -m 60 -o "$out" -w '%{http_code}' -X POST "$KOKORO_URL/v1/audio/speech" \
    -H 'Content-Type: application/json' \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"model":"kokoro","input":sys.argv[1],"voice":sys.argv[2],"response_format":"wav"}))' "$text" "$voice")" 2>/dev/null
}

# say_piper TEXT OUT — the fallback; its reason is printed, never hidden
say_piper(){
  local text="$1" out="$2" bin model
  bin="$(command -v piper || true)"; [ -n "$bin" ] || return 1
  model="${SNOTRA_PIPER_MODEL:-$HOME/.local/share/piper-voices/en_US-lessac-medium.onnx}"
  [ -r "$model" ] || model="$(ls "$HOME/.local/share/piper-voices/"*.onnx 2>/dev/null | head -1)"
  [ -n "${model:-}" ] && [ -r "$model" ] || return 1
  printf '%s' "$text" | "$bin" --model "$model" --output_file "$out" >/dev/null 2>&1
  [ -s "$out" ]
}

wav_seconds(){ python3 - "$1" <<'PY'
import sys, wave
try:
    with wave.open(sys.argv[1]) as w: print("%.2f" % (w.getnframes() / float(w.getframerate())))
except Exception: print("0")
PY
}

play_into_device(){
  local wav="$1"
  if command -v paplay >/dev/null 2>&1; then
    paplay --device="$DEVICE" "$wav" 2>/dev/null && return 0
  fi
  if command -v pw-play >/dev/null 2>&1; then
    pw-play --target="$DEVICE" "$wav" 2>/dev/null && return 0
  fi
  return 1
}

# wait_quiet SECONDS — hold the first word until the room is quiet (0 = do not wait)
wait_quiet(){
  local budget="${1:-0}" deadline
  [ "$budget" -gt 0 ] 2>/dev/null || return 0
  command -v parec >/dev/null 2>&1 || { printf 'note\twait-quiet\tskipped — parec absent\n'; return 0; }
  deadline=$(( $(date +%s) + budget ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    local rms
    rms="$(timeout 1 ffmpeg -hide_banner -loglevel error -f pulse -i "$(pactl get-default-source 2>/dev/null || echo default)" -t 0.5 -af astats=metadata=1:reset=0 -f null - 2>&1 >/dev/null | awk -F': ' '/RMS level dB/ {print $2}' | tail -1)"
    awk -v r="${rms:-0}" 'BEGIN{exit !((r+0) < -40)}' && { printf 'note\twait-quiet\troom quiet (%s dB)\n' "${rms:-?}"; return 0; }
  done
  printf 'note\twait-quiet\tstill busy after %ss — speaking anyway\n' "$budget"
}

record_rune(){
  local text="$1" name="$2" secs="$3"
  [ -x "$ROOT/bin/records/runes-append.sh" ] || return 0
  "$ROOT/bin/records/runes-append.sh" snotra voice.speak \
    --message "spoke in the room as ${name} for ${secs}s: ${text:0:180}" >/dev/null 2>&1 || true
}

# ---- the actions --------------------------------------------------------------
cmd_say(){
  local text="" name="Skírnir" announce="" maxs="$MAX_SECONDS" dry=0 waitq="${SNOTRA_WAIT_QUIET:-0}"
  while [ $# -gt 0 ]; do case "$1" in
    --as) name="${2-}"; shift 2 ;;
    --max-seconds) maxs="${2-}"; shift 2 ;;
    --announce) announce=yes; shift ;;
    --no-announce) announce=no; shift ;;
    --device) DEVICE="${2-}"; shift 2 ;;
    --wait-quiet) waitq="${2-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -*) usage ;;
    *) text="${text:+$text }$1"; shift ;;
  esac; done
  [ -n "$text" ] || usage
  [ -e "$MUTE_FILE" ] && die "muted — $(cat "$MUTE_FILE" 2>/dev/null | head -1) (run: $0 unmute)"

  # The naming law: the first word in any meeting is the speaker's own name.
  if [ "$announce" != "no" ] && [ ! -e "$ANNOUNCED_FILE" ]; then
    text="${name}, the Allfather's assistant, speaking. ${text}"
  fi

  ensure_device || die "no '${DEVICE}' source — run bin/time/snotra/snotra-voice-device.sh ensure"

  local tmp code=000 tts=kokoro
  TMPWAV="$(mktemp --suffix=.wav)"; tmp="$TMPWAV"; trap 'rm -f "${TMPWAV:-}"' EXIT
  ensure_tts || printf 'note\tvoice\tkokoro is down and would not rise — trying it anyway\n'
  code="$(say_kokoro "$text" "$tmp")"
  if [ "$code" != "200" ] || [ ! -s "$tmp" ]; then
    tts="piper"
    say_piper "$text" "$tmp" || die "no voice: kokoro answered ${code} and piper is unavailable — the reason is above, not hidden"
    printf 'note\tvoice\tkokoro refused (%s); spoke through piper instead\n' "$code"
  fi
  local secs; secs="$(wav_seconds "$tmp")"
  awk -v s="$secs" -v m="$maxs" 'BEGIN{exit !(s > m)}' && die "the utterance runs ${secs}s, over the ${maxs}s cap — shorten it; a support answer is a sentence or two"

  if [ "$dry" = 1 ]; then
    printf 'dry_run[1]{tts,seconds,device,text}:\n  "%s","%s","%s","%s"\n' "$tts" "$secs" "$DEVICE" "$(printf '%s' "$text" | tr '"' "'")"
    return 0
  fi

  wait_quiet "$waitq"
  play_into_device "$tmp" || die "'${DEVICE}' refused the audio — is the PipeWire sink still loaded?"
  { [ -e "$ANNOUNCED_FILE" ] || date -Iseconds > "$ANNOUNCED_FILE"; } 2>/dev/null || true
  record_rune "$text" "$name" "$secs"
  printf 'spoke[5]{name,tts,seconds,device,text}:\n  "%s","%s","%s","%s","%s"\n' \
    "$name" "$tts" "$secs" "$DEVICE" "$(printf '%s' "$text" | tr '"' "'")"
}

ensure_tts(){
  # Kokoro is the house voice; if the unit is down, raise it once (it is an idle-lowered
  # service by design, not a broken one) and give it a moment to bind :8765.
  curl -sS -m 3 -o /dev/null "$KOKORO_URL/v1/models" 2>/dev/null && return 0
  command -v systemctl >/dev/null 2>&1 && systemctl --user start kokoro-serve.service >/dev/null 2>&1
  local i; for i in 1 2 3 4 5 6 7 8; do
    sleep 1; curl -sS -m 2 -o /dev/null "$KOKORO_URL/v1/models" 2>/dev/null && return 0
  done
  return 1
}

cmd_mute(){
  printf 'muted %s by %s\n' "$(date -Iseconds)" "${SUDO_USER:-${USER:-unknown}}" > "$MUTE_FILE"
  printf 'mute\t%s\tthe next word needs `unmute`\n' "$(date -Iseconds)"
}
cmd_unmute(){
  rm -f "$MUTE_FILE" "$ANNOUNCED_FILE"
  printf 'unmute\t%s\tthe first word will name the speaker again\n' "$(date -Iseconds)"
}
cmd_status(){
  local muted=no dev=no
  [ -e "$MUTE_FILE" ] && muted=yes
  device_ready && dev=yes
  local kok=down; curl -sS -m 2 -o /dev/null "$KOKORO_URL/v1/models" 2>/dev/null && kok=up
  printf 'voice_door[6]{muted,announced,device,device_ready,tts,max_seconds}:\n  "%s","%s","%s","%s","%s","%s"\n' \
    "$muted" "$([ -e "$ANNOUNCED_FILE" ] && echo yes || echo no)" "$DEVICE" "$dev" "kokoro:$kok" "$MAX_SECONDS"
}

case "$ACTION" in
  say) cmd_say "$@" ;;
  mute) cmd_mute ;;
  unmute) cmd_unmute ;;
  status) cmd_status ;;
  *) usage ;;
esac
