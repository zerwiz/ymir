#!/usr/bin/env bash
# model-sync.sh — take the voice models over the LOCAL NETWORK, never from the internet.
#
#   bin/voice/model-sync.sh status [--from <seat>]
#   bin/voice/model-sync.sh pull   [--from <seat>] [--only kokoro|whisper|vad]
#
# WHY: the fleet already holds every model the voice needs. On a metered link — a phone
# hotspot — a first run that re-downloads 800 MB of weights (Kokoro 313 MB + faster-whisper
# small.en 464 MB + the Smart Turn VAD) is the difference between a working evening and a
# spent data plan. The seat that has them is the seat that sends them, over ssh, on the LAN
# or the tailnet.
#
# The models, and where they live:
#   Kokoro-82M            ~/.cache/huggingface/hub/models--hexgrad--Kokoro-82M
#   faster-whisper small  ~/.cache/huggingface/hub/models--Systran--faster-whisper-small.en
#   Smart Turn v3.2       ~/.cache/huggingface/hub/models--pipecat-ai--smart-turn-v3
#
# The HEAD is never copied: it stays on the rail and is reached over the network
# (`YMIR_VOICE_HEAD_URL`). Only the small, per-seat stages are synced.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HUB="${HF_HOME:-$HOME/.cache/huggingface}/hub"
say() { printf '%-46s %s\n' "$1" "$2"; }

SETS_kokoro="models--hexgrad--Kokoro-82M"
SETS_whisper="models--Systran--faster-whisper-small.en"
SETS_vad="models--pipecat-ai--smart-turn-v3"

from_seat() {
  local seat="${YMIR_VOICE_MODEL_SEAT:-}"
  [ -n "$seat" ] && { printf '%s' "$seat"; return; }
  python3 - <<'PY' 2>/dev/null
import json, os
try:
    home = os.environ.get("YMIR_HOME") or ""
    if not home:
        import subprocess
        try:
            home = subprocess.run(["bash", "-lc",
                '. "${HOME}/ymir/bin/vault/hoard-lib.sh" >/dev/null 2>&1; ymir_home_root YMIR_HOME >/dev/null 2>&1; printf %s "$YMIR_HOME"'],
                capture_output=True, text=True, timeout=10).stdout.strip()
        except Exception:
            home = ""
    fleet = json.load(open(os.path.join(home, "hodd/data/fleet.json")))
    ear = fleet.get("ear") or []
    me = os.uname().nodename.split(".")[0]
    for h in ear:
        if h != me:
            print(h); break
except Exception:
    pass
PY
}

size_of() { [ -d "$1" ] && du -sh "$1" 2>/dev/null | cut -f1 || echo "-"; }

cmd="${1:-status}"; shift || true
while [ $# -gt 0 ]; do case "$1" in --from) shift; FROM="${1:-}" ;; --only) shift; ONLY="${1:-}" ;; esac; shift; done
FROM="${FROM:-$(from_seat)}"

case "$cmd" in
  status)
    say "model shelf" "$HUB"
    say "fleet seat that has them" "${FROM:-none found}"
    for pair in "kokoro:$SETS_kokoro" "whisper:$SETS_whisper" "vad:$SETS_vad"; do
      name="${pair%%:*}"; set_="${pair#*:}"
      local_have=$(size_of "$HUB/$set_")
      remote_have="-"
      [ -n "${FROM:-}" ] && remote_have=$(timeout 20 ssh -o BatchMode=yes -o ConnectTimeout=6 "$FROM" \
        "du -sh ~/.cache/huggingface/hub/$set_ 2>/dev/null | cut -f1" 2>/dev/null || echo "-")
      verdict="present"
      [ "$local_have" = "-" ] && verdict="MISSING locally — pull it from $FROM"
      say "$name" "local ${local_have} · $FROM ${remote_have:-?} · $verdict"
    done
    say "the head" "never copied — it stays on the rail (YMIR_VOICE_HEAD_URL)"
    ;;
  pull)
    [ -n "${FROM:-}" ] || { say "no seat to pull from" "set YMIR_VOICE_MODEL_SEAT"; exit 1; }
    mkdir -p "$HUB"
    for pair in "kokoro:$SETS_kokoro" "whisper:$SETS_whisper" "vad:$SETS_vad"; do
      name="${pair%%:*}"; set_="${pair#*:}"
      [ -n "${ONLY:-}" ] && [ "$ONLY" != "$name" ] && continue
      if [ -d "$HUB/$set_" ] && [ "$(size_of "$HUB/$set_")" != "-" ]; then
        say "$name" "already here ($(size_of "$HUB/$set_")) — not pulled again"
        continue
      fi
      say "$name" "pulling from $FROM over the network…"
      rsync -a --ignore-existing --info=progress2 \
        -e "ssh -o BatchMode=yes -o ConnectTimeout=8" \
        "$FROM:$HUB/$set_/" "$HUB/$set_/" 2>/dev/null \
        || rsync -a -e "ssh -o BatchMode=yes" "$FROM:~/.cache/huggingface/hub/$set_/" "$HUB/$set_/"
      say "$name" "$(size_of "$HUB/$set_") now"
    done
    ;;
  *)
    printf 'usage: bin/voice/model-sync.sh [status|pull] [--from SEAT] [--only kokoro|whisper|vad]\n' >&2
    exit 2 ;;
esac
