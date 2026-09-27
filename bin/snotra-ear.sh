#!/usr/bin/env bash
# snotra-ear.sh — the meeting ear's ENGINE, served to the fleet.
#
# The heart fronts the DOOR (:8321, tools/snotra/server.mjs); the HEARING rides
# a strong box (plan 51 Part 9a: zerwizserver's GPU cannot run whisper). This
# script is the ear on a strong box — it discovers the seat's whisper engine and
# model, picks the device by free VRAM, and serves whisper.cpp's own HTTP face
# so any seat's door can reach it over the tailnet.
#
# The engine is upstream whisper.cpp's `whisper-server` (no bespoke code): it
# serves POST <path>/inference (multipart `file`) and GET <path>/health at
# `--request-path` (default ""). The door walks /health across the fleet's
# declared ear order (plan 51 Part 9c) and posts the audio to the winner.
#
# Usage:
#   snotra-ear.sh serve     # run the engine in the foreground (the unit's ExecStart)
#   snotra-ear.sh status    # the discovery row (engine · model · device · lane)
#   snotra-ear.sh probe     # GET /health on the local lane — the door's own probe
#
# Env:
#   SNOTRA_EAR_HOST       bind address (default 0.0.0.0; the tailnet is the lane)
#   SNOTRA_EAR_PORT       bind port (default 8322)
#   SNOTRA_WHISPER_BIN    explicit engine override
#   SNOTRA_WHISPER_MODEL  explicit model override
#   SNOTRA_EAR_MODEL      model name to seek (default ggml-small.en.bin)
#   SNOTRA_EAR_GPU        on|off (default on; falls to the CPU when VRAM is tight)
#
# Exit: serve runs until signalled; status/probe exit 0 when the ear can hear,
# 1 when this seat cannot carry the ear (no engine, no model, or no lane).
set -u

VERSION="1.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; esac

CMD="${1-serve}"
SNOTRA_EAR_HOST="${SNOTRA_EAR_HOST:-0.0.0.0}"
SNOTRA_EAR_PORT="${SNOTRA_EAR_PORT:-8322}"
SNOTRA_EAR_MODEL="${SNOTRA_EAR_MODEL:-ggml-small.en.bin}"
SNOTRA_EAR_GPU="${SNOTRA_EAR_GPU:-on}"
LANE="http://127.0.0.1:${SNOTRA_EAR_PORT}"

have() { command -v "$1" >/dev/null 2>&1; }

# --- discovery (mirrors bin/snotra-ensure.sh — the one engine on the seat) ---
find_whisper() {
  # Prefer the SERVER binary: the ear IS the served face, not the CLI.
  if [ -n "${SNOTRA_WHISPER_BIN:-}" ] && [ -x "$SNOTRA_WHISPER_BIN" ]; then printf '%s' "$SNOTRA_WHISPER_BIN"; return 0; fi
  local c
  for c in whisper-server; do
    if have "$c"; then command -v "$c"; return 0; fi
  done
  local p
  for p in \
    "$HOME/whisper.cpp.src/build/bin/whisper-server" \
    "$HOME/whisper.cpp/build/bin/whisper-server" \
    "/usr/local/bin/whisper-server" "/usr/bin/whisper-server"; do
    if [ -x "$p" ]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

find_model() {
  if [ -n "${SNOTRA_WHISPER_MODEL:-}" ] && [ -f "$SNOTRA_WHISPER_MODEL" ]; then printf '%s' "$SNOTRA_WHISPER_MODEL"; return 0; fi
  local p
  for p in \
    "$HOME/whisper.cpp/models/${SNOTRA_EAR_MODEL}" \
    "$HOME/whisper.cpp/models/ggml-small.en.bin" \
    "$HOME/whisper.cpp/models/ggml-base.en.bin" \
    "$HOME/.local/share/voxtype/models/${SNOTRA_EAR_MODEL}" \
    "$HOME/.local/share/voxtype/models/ggml-small.en.bin" \
    "$HOME/.local/share/voxtype/models/ggml-base.en.bin" \
    "$HOME/.local/share/whisper.cpp/models/${SNOTRA_EAR_MODEL}" \
    "/usr/share/whisper.cpp/models/${SNOTRA_EAR_MODEL}" \
    "/usr/share/whisper/models/ggml-small.en.bin"; do
    if [ -f "$p" ]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

# Free VRAM in MiB; empty when nvidia-smi is absent OR cannot reach a driver
# (a driverless seat prints its complaint on stdout — never let that text reach
# an integer comparison).
free_vram_mb() {
  local v
  v="$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -dc '0-9')"
  case "$v" in ''|*[!0-9]*) return 0 ;; esac
  printf '%s' "$v"
}

# The device is chosen by available VRAM, never assumed: a resident rail model
# starves CUDA on a tight card, and a broken CUDA init is a dead ear. 1200 MiB
# is the small.en working set with margin.
device_flags() {
  local vram
  [ "$SNOTRA_EAR_GPU" = off ] && { printf '%s\n' "-ng"; return 0; }
  vram="$(free_vram_mb)"
  case "$vram" in
    ''|*[!0-9]*) printf '%s\n' "-ng"; return 0 ;;
  esac
  if [ "$vram" -ge 1200 ]; then printf '%s\n' ""; else printf '%s\n' "-ng"; fi
}

status() {
  local w m flags dev
  w="$(find_whisper || true)"; m="$(find_model || true)"
  flags="$(device_flags)"
  dev="cuda"; [ "$flags" = "-ng" ] && dev="cpu"
  printf 'snotra-ear[1]{engine,model,device,bind,seat}:\n'
  printf '  "%s","%s","%s","%s:%s","%s"\n' \
    "${w:-—}" "${m:-—}" "$dev" "$SNOTRA_EAR_HOST" "$SNOTRA_EAR_PORT" "$(hostname -s 2>/dev/null || hostname)"
  [ -n "$w" ] && [ -n "$m" ]
}

serve() {
  local w m flags
  w="$(find_whisper || true)"; m="$(find_model || true)"
  if [ -z "$w" ] || [ -z "$m" ]; then
    printf 'snotra-ear: cannot hear on this seat — engine=%s model=%s\n' "${w:-—}" "${m:-—}" >&2
    printf 'snotra-ear: remedy: bin/snotra-ensure.sh install (a strong box carries the ear)\n' >&2
    exit 1
  fi
  flags="$(device_flags)"
  status >&2
  # The build tree carries its own libggml/libwhisper; a bare copy is a torso.
  export LD_LIBRARY_PATH="$(dirname "$w"):${LD_LIBRARY_PATH:-}"
  # shellcheck disable=SC2086
  exec "$w" \
    -m "$m" \
    --host "$SNOTRA_EAR_HOST" --port "$SNOTRA_EAR_PORT" \
    --convert --tmp-dir "${TMPDIR:-/tmp}" \
    -l en -nt $flags
}

probe() {
  local body
  command -v curl >/dev/null 2>&1 || { printf 'snotra-ear: curl absent — cannot probe\n' >&2; return 1; }
  body="$(curl -s --max-time 5 "$LANE/health" 2>/dev/null || true)"
  [ -n "$body" ] || { printf 'snotra-ear: no answer on %s/health\n' "$LANE" >&2; return 1; }
  printf '%s\n' "$body"
}

case "$CMD" in
  serve)  serve ;;
  status) status; exit $? ;;
  probe)  probe; exit $? ;;
  -h|--help|help|"")
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) printf 'error: unknown command %s\nhelp: snotra-ear.sh [serve|status|probe]\n' "$CMD" >&2; exit 2 ;;
esac
