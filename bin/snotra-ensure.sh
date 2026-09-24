#!/usr/bin/env bash
# snotra-ensure.sh — ensure the meeting ear's transcription engine is present.
#
# Snotra captures on the meeting seat and transcribes with whisper.cpp. The
# engine is discovered, never assumed: this script reports what the seat has and
# installs what is missing (whisper-cli + one model).
#
# Per-OS install road:
#   Arch/omarchy  pacman -S whisper-cpp            (extra repo; CPU backend)
#   Debian/Ubuntu apt-get install whisper.cpp      (or build from source)
#   otherwise     build whisper.cpp from source, or use an existing build
#
# The model is fetched from the whisper.cpp Hugging Face release (checksummed by
# HTTPS; ~466 MB for small.en). A seat that already has voxtype keeps its models
# — they are found in ~/.local/share/voxtype/models and never re-downloaded.
#
# Usage:
#   snotra-ensure.sh status
#   snotra-ensure.sh ensure [--install]
#   snotra-ensure.sh install
#   snotra-ensure.sh --version
#
# Env:
#   SNOTRA_WHISPER_BIN   — explicit engine override
#   SNOTRA_WHISPER_MODEL — explicit model override
#   SNOTRA_MODEL         — model name to fetch (default ggml-small.en)
#
# Exit: 0 engine + model present, 1 absent, 2 usage.
set -u

VERSION="1.0.0"
SNOTRA_MODEL="${SNOTRA_MODEL:-ggml-small.en}"
MODEL_BASE="${SNOTRA_MODEL_URL:-https://huggingface.co/ggerganov/whisper.cpp/resolve/main}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
CMD="${1-}"; shift || true
DO_INSTALL=0
case "$CMD" in ensure|status|install) ;; *) printf 'error: unknown command %s\nhelp: bin/snotra-ensure.sh [status|ensure|install]\n' "$CMD" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do case "$1" in --install) DO_INSTALL=1; shift ;; *) shift ;; esac; done
[ "$CMD" = install ] && DO_INSTALL=1

have() { command -v "$1" >/dev/null 2>&1; }

# --- discovery (mirrors bin/snotra-transcribe.sh) ---------------------------

find_whisper() {
  if [ -n "${SNOTRA_WHISPER_BIN:-}" ] && [ -x "$SNOTRA_WHISPER_BIN" ]; then printf '%s' "$SNOTRA_WHISPER_BIN"; return 0; fi
  local c
  for c in whisper-cli whisper-cpp whisper; do
    if have "$c"; then command -v "$c"; return 0; fi
  done
  local p
  for p in \
    "$HOME/whisper.cpp.src/build/bin/whisper-cli" \
    "$HOME/whisper.cpp/build/bin/whisper-cli" \
    "$HOME/whisper.cpp.src/build/bin/main" \
    "$HOME/whisper.cpp/build/bin/main" \
    "/usr/local/bin/whisper-cli" "/usr/bin/whisper-cli"; do
    if [ -x "$p" ]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

find_model() {
  if [ -n "${SNOTRA_WHISPER_MODEL:-}" ] && [ -f "$SNOTRA_WHISPER_MODEL" ]; then printf '%s' "$SNOTRA_WHISPER_MODEL"; return 0; fi
  local p
  for p in \
    "$HOME/whisper.cpp/models/${SNOTRA_MODEL}.bin" \
    "$HOME/whisper.cpp/models/ggml-small.en.bin" \
    "$HOME/whisper.cpp/models/ggml-base.en.bin" \
    "$HOME/.local/share/voxtype/models/${SNOTRA_MODEL}.bin" \
    "$HOME/.local/share/voxtype/models/ggml-small.en.bin" \
    "$HOME/.local/share/voxtype/models/ggml-base.en.bin" \
    "$HOME/.local/share/whisper.cpp/models/${SNOTRA_MODEL}.bin" \
    "/usr/share/whisper.cpp/models/${SNOTRA_MODEL}.bin" \
    "/usr/share/whisper/models/${SNOTRA_MODEL}.bin"; do
    if [ -f "$p" ]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

# A voxtype-only seat transcribes through voxtype itself — still "the ear".
find_voxtype() { have voxtype && command -v voxtype; }

status() {
  local w m vx
  w="$(find_whisper || true)"
  m="$(find_model || true)"
  vx="$(find_voxtype || true)"
  printf 'snotra[1]{engine,model,voxtype,seat}:\n'
  if [ -n "$w" ] && [ -n "$m" ]; then
    printf '  "%s","%s","%s","%s"\n' "$w" "$m" "${vx:-—}" "$(hostname -s 2>/dev/null || hostname)"
    return 0
  fi
  if [ -n "$vx" ] && [ -n "$m" ]; then
    printf '  "voxtype","%s","%s","%s"\n' "$m" "$vx" "$(hostname -s 2>/dev/null || hostname)"
    return 0
  fi
  printf '  "%s","%s","%s","%s"\n' "${w:-—}" "${m:-—}" "${vx:-—}" "$(hostname -s 2>/dev/null || hostname)"
  return 1
}

# --- install ----------------------------------------------------------------

install_engine() {
  local os_id=""
  [ -r /etc/os-release ] && os_id="$(. /etc/os-release 2>/dev/null; printf '%s' "${ID:-}")"
  case "$os_id" in
    arch|omarchy|manjaro|endeavouros)
      if have pacman; then
        printf 'snotra: installing whisper-cpp via pacman …\n' >&2
        if sudo -n pacman -S --noconfirm whisper-cpp >/dev/null 2>&1; then
          printf 'snotra: whisper-cpp installed\n' >&2; return 0
        fi
        printf 'snotra: pacman needs a password — run: sudo pacman -S whisper-cpp\n' >&2
        return 1
      fi ;;
    debian|ubuntu|pop|linuxmint)
      if have apt-get; then
        printf 'snotra: installing whisper.cpp via apt-get …\n' >&2
        if sudo -n apt-get install -y whisper.cpp >/dev/null 2>&1; then
          printf 'snotra: whisper.cpp installed\n' >&2; return 0
        fi
        printf 'snotra: apt-get needs a password — run: sudo apt-get install -y whisper.cpp\n' >&2
        return 1
      fi ;;
  esac
  printf 'snotra: no package for this OS — build whisper.cpp:\n' >&2
  printf '  git clone https://github.com/ggerganov/whisper.cpp ~/whisper.cpp.src\n' >&2
  printf '  cmake -S ~/whisper.cpp.src -B ~/whisper.cpp.src/build -DGGML_CUDA=ON && cmake --build ~/whisper.cpp.src/build -j\n' >&2
  return 1
}

install_model() {
  local dir="$HOME/whisper.cpp/models"
  mkdir -p "$dir"
  local url="$MODEL_BASE/${SNOTRA_MODEL}.bin"
  printf 'snotra: fetching %s …\n' "$url" >&2
  if have curl; then
    if curl -fL --retry 3 -o "$dir/${SNOTRA_MODEL}.bin.part" "$url" >/dev/null 2>&1; then
      mv "$dir/${SNOTRA_MODEL}.bin.part" "$dir/${SNOTRA_MODEL}.bin"
      printf 'snotra: model seated at %s/%s.bin\n' "$dir" "$SNOTRA_MODEL" >&2
      return 0
    fi
  fi
  rm -f "$dir/${SNOTRA_MODEL}.bin.part"
  printf 'snotra: model fetch failed (offline?) — download %s to %s/\n' "$url" "$dir" >&2
  return 1
}

install_all() {
  if [ -z "$(find_whisper || true)" ] && [ -z "$(find_voxtype || true)" ]; then
    install_engine || true
  fi
  if [ -z "$(find_model || true)" ]; then
    install_model || true
  fi
}

case "$CMD" in
  status) status; exit $? ;;
  install) install_all; status; exit $? ;;
  ensure)
    if status >/dev/null 2>&1; then status; exit 0; fi
    if [ "$DO_INSTALL" = 1 ]; then
      install_all
      status; exit $?
    fi
    status
    printf 'snotra: engine or model missing — run `bin/snotra-ensure.sh install`\n' >&2
    exit 1 ;;
esac
