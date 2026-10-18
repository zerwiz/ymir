#!/usr/bin/env bash
# voice-ensure.sh — ensure the voice engines: whisper.cpp (speech → text) and
# piper (text → speech).
#
# Voice is a MACHINE property: the engines and their models live on the host /
# in the hoard, never in the code tree. This step ADOPTS an engine already here
# (never reinstalls it) and installs what is missing: whisper.cpp for the ear,
# piper for the voice, each on its own per-OS road, each with a model. Loud
# refusals (no python/pip, no network, no model) — never a silent skip.
#
# The speech→text engine is owned by bin/time/snotra/snotra-ensure.sh (one whisper road), so
# this script DELEGATES that half rather than growing a second installer.
#
# Usage:
#   voice-ensure.sh status            # whisper + piper, and their models
#   voice-ensure.sh ensure [--install]
#   voice-ensure.sh install
#   voice-ensure.sh --version
#
# Env:
#   YMIR_PIPER_BIN     — explicit piper binary override
#   YMIR_PIPER_VOICE   — explicit .onnx voice override
#   YMIR_VOICES_DIR    — where piper voices live (default $YMIR_HOME/voices)
#   PIPER_VOICE_NAME   — voice to fetch (default en_US-lessac-medium)
#   SNOTRA_*           — forwarded to snotra-ensure.sh for the whisper half
#
# Exit: 0 both present, 1 one missing, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This script lives in the VOICE shelf (bin/voice/, Rule 12/23), so it walks up two
# levels for the repo root and reaches its neighbours by shelf:
#   the whisper road   bin/time/snotra/snotra-ensure.sh
#   the home resolver  bin/vault/hoard-lib.sh
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SNOTRA_ENSURE="$ROOT/bin/time/snotra/snotra-ensure.sh"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
ymir_home_root YMIR_HOME
VOICES_DIR="${YMIR_VOICES_DIR:-$YMIR_HOME/voices}"
PIPER_VOICE_NAME="${PIPER_VOICE_NAME:-en_US-lessac-medium}"
PIPER_VOICE_BASE="${PIPER_VOICE_BASE:-https://huggingface.co/rhasspy/piper-voices/resolve/main}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
CMD="${1-}"; shift || true
DO_INSTALL=0
case "$CMD" in ensure|status|install) ;; *) printf 'error: unknown command %s\nhelp: bin/voice/voice-ensure.sh [status|ensure|install]\n' "$CMD" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do case "$1" in --install) DO_INSTALL=1; shift ;; *) shift ;; esac; done
[ "$CMD" = install ] && DO_INSTALL=1

have() { command -v "$1" >/dev/null 2>&1; }

# --- discover (adopt what stands) -------------------------------------------

find_piper() {
  if [ -n "${YMIR_PIPER_BIN:-}" ] && [ -x "$YMIR_PIPER_BIN" ]; then printf '%s' "$YMIR_PIPER_BIN"; return 0; fi
  local c
  if have piper; then command -v piper; return 0; fi
  local p
  for p in \
    "$YMIR_HOME/.venvs/piper/bin/piper" \
    "$HOME/.piper-venv/bin/piper" \
    "$HOME/.local/bin/piper" \
    "$HOME/.local/share/pipx/venvs/piper-tts/bin/piper"; do
    [ -x "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

find_voice() {
  if [ -n "${YMIR_PIPER_VOICE:-}" ] && [ -f "$YMIR_PIPER_VOICE" ]; then printf '%s' "$YMIR_PIPER_VOICE"; return 0; fi
  local p
  for p in "$VOICES_DIR/${PIPER_VOICE_NAME}.onnx" "$VOICES_DIR"/*.onnx \
           "$HOME/.local/share/piper-voices/${PIPER_VOICE_NAME}.onnx" "$HOME/.local/share/piper-voices"/*.onnx \
           "$HOME/.local/share/piper/voices/${PIPER_VOICE_NAME}.onnx" "$HOME/.local/share/piper/voices"/*.onnx \
           "/usr/share/piper-voices/${PIPER_VOICE_NAME}.onnx"; do
    [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

whisper_status() { [ -x "$SNOTRA_ENSURE" ] && "$SNOTRA_ENSURE" status 2>/dev/null; }

status() {
  local p v wstt ws="missing" ps="missing"
  whisper_status >/dev/null 2>&1 && ws="present"
  p="$(find_piper || true)"; v="$(find_voice || true)"
  [ -n "$p" ] && ps="present"
  printf 'voice[1]{stt,tts,piper,voice}:\n'
  printf '  "whisper.cpp (%s)","piper (%s)","%s","%s"\n' \
    "$ws" "$ps" "${p:-—}" "${v:-—}"
  [ "$ws" = "present" ] && [ "$ps" = "present" ]
}

# --- install ----------------------------------------------------------------

install_piper() {
  local venv="$YMIR_HOME/.venvs/piper"
  if have pipx; then
    printf 'voice: installing piper-tts via pipx …\n' >&2
    pipx install piper-tts >/dev/null 2>&1 && have piper && { printf 'voice: piper installed (pipx)\n' >&2; return 0; }
  fi
  have python3 || { printf 'voice: python3 is required to install piper\n' >&2; return 1; }
  printf 'voice: creating a venv at %s and installing piper-tts …\n' "$venv" >&2
  python3 -m venv "$venv" >/dev/null 2>&1 || { printf 'voice: could not create %s (python3 venv?)\n' "$venv" >&2; return 1; }
  "$venv/bin/pip" install --quiet --upgrade pip >/dev/null 2>&1 || true
  if "$venv/bin/pip" install --quiet piper-tts >/dev/null 2>&1 && [ -x "$venv/bin/piper" ]; then
    printf 'voice: piper installed at %s/bin/piper\n' "$venv" >&2
    return 0
  fi
  printf 'voice: piper install failed — run: %s/bin/pip install piper-tts\n' "$venv" >&2
  return 1
}

install_voice() {
  mkdir -p "$VOICES_DIR"
  local name="$PIPER_VOICE_NAME"
  local lang="${name%%_*}" rest="${name#*_}" region speaker quality
  region="${rest%%-*}"; rest="${rest#*-}"; speaker="${rest%%-*}"; quality="${rest##*-}"
  local sub="$lang/${lang}_${region}/${speaker}/${quality}"
  local onnx="$PIPER_VOICE_BASE/$sub/${name}.onnx"
  local json="$PIPER_VOICE_BASE/$sub/${name}.onnx.json"
  have curl || { printf 'voice: curl is required to fetch a piper voice\n' >&2; return 1; }
  printf 'voice: fetching %s …\n' "$name" >&2
  if curl -fL --retry 3 -C - -o "$VOICES_DIR/${name}.onnx.part" "$onnx" >/dev/null 2>&1; then
    mv "$VOICES_DIR/${name}.onnx.part" "$VOICES_DIR/${name}.onnx"
  else
    rm -f "$VOICES_DIR/${name}.onnx.part"
    printf 'voice: voice fetch failed — check the name or the network\n' >&2
    return 1
  fi
  curl -fL --retry 3 -o "$VOICES_DIR/${name}.onnx.json" "$json" >/dev/null 2>&1 || true
  printf 'voice: voice seated at %s/%s.onnx\n' "$VOICES_DIR" "$name" >&2
  return 0
}

install_all() {
  # whisper (STT) — one road: bin/time/snotra/snotra-ensure.sh owns it.
  if [ -x "$SNOTRA_ENSURE" ] && ! whisper_status >/dev/null 2>&1; then
    "$SNOTRA_ENSURE" install >/dev/null 2>&1 || true
  fi
  # piper (TTS) — adopt, else install, then its voice.
  if [ -z "$(find_piper || true)" ]; then install_piper || true; fi
  if [ -z "$(find_voice || true)" ]; then install_voice || true; fi
}

case "$CMD" in
  status) status; exit $? ;;
  install) install_all; status; exit $? ;;
  ensure)
    if status >/dev/null 2>&1; then status; exit 0; fi
    [ "$DO_INSTALL" = 1 ] || { printf 'voice[1]{state}:\n  "missing — re-run with --install"\n'; exit 1; }
    install_all; status; exit $?
    ;;
esac
