#!/usr/bin/env bash
# tts-lease.sh — say "the card is in use" so the idle-stop never lowers the voice under a conversation.
#
#   tts-lease.sh touch [--ttl-min 15]
#   tts-lease.sh status
#
# Every door that synthesises calls `touch`: the assistant's mouth, the meeting mouth (CDP), the
# streaming talk loop, and the seat while it holds a room. One stamp for the ordinary idle rule, one
# lease for Skírnir's conversations — see ~/.local/bin/kokoro-idle-stop.sh.
set -u
RUNTIME="${RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/run/user/$(id -u)}}"
STAMP="$RUNTIME/kokoro-last-use"
LEASE="${SKIRNIR_TTS_LEASE:-$HOME/.local/share/skirnir/tts.lease}"
ACTION="${1:-touch}"
case "$ACTION" in
  touch)
    mkdir -p "$(dirname "$LEASE")" 2>/dev/null || true
    date +%s > "$STAMP" 2>/dev/null || true
    date +%s > "$LEASE" 2>/dev/null || true
    exit 0 ;;
  status)
    now=$(date +%s)
    for f in "$STAMP" "$LEASE"; do
      if [ -f "$f" ]; then
        printf '  "%s","%ss ago"\n' "$(basename "$f")" "$(( now - $(stat -c %Y "$f") ))"
      else
        printf '  "%s","absent"\n' "$(basename "$f")"
      fi
    done ;;
  *) printf 'usage: tts-lease.sh touch|status\n' >&2; exit 2 ;;
esac
