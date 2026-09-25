#!/usr/bin/env bash
# llama-ensure.sh — stand a CUDA llama.cpp engine for local models, or adopt the
# one already here.
#
# The engine is a MACHINE property, not a repo property: it lives on the host (a
# system binary, or a build under $YMIR_HOME), never in the code tree. This step
# ADOPTS a CUDA `llama-server` when one stands — never rebuilding what is here —
# and only builds/fetches when none is found. It PROVES the build is not CPU-only:
# `--list-devices` must print `CUDA0`. A CPU build "works" and is ~10× slow, which
# makes every later measurement a lie.
#
# Usage:
#   llama-ensure.sh status              # find the engine and prove CUDA
#   llama-ensure.sh ensure [--install]  # adopt, else build (needs consent)
#   llama-ensure.sh path                # print the llama-server to use
#   llama-ensure.sh --version
#
# Env:
#   LLAMA_SERVER        — explicit llama-server binary override
#   YMIR_LLAMA_DIR      — where a from-source build lives (default $YMIR_HOME/llama.cpp)
#   YMIR_LLAMA_CUDA     — "off" to accept a CPU build deliberately (loud by default)
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
ymir_home_root YMIR_HOME
hoard_state_dir YMIR_STATE_DIR
LLAMA_DIR="${YMIR_LLAMA_DIR:-$YMIR_HOME/llama.cpp}"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ACTION="${1:-status}"; shift || true
INSTALL=0
while [ $# -gt 0 ]; do case "$1" in --install|--consent) INSTALL=1; shift ;; *) shift ;; esac; done

have() { command -v "$1" >/dev/null 2>&1; }

find_server() {
  # 1) explicit override, 2) PATH, 3) a from-source build under the home.
  if [ -n "${LLAMA_SERVER:-}" ] && [ -x "$LLAMA_SERVER" ]; then printf '%s' "$LLAMA_SERVER"; return 0; fi
  if have llama-server; then command -v llama-server; return 0; fi
  for c in "$LLAMA_DIR/build/bin/llama-server" "$LLAMA_DIR/build/llama-server"; do
    [ -x "$c" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

# cuda_device <bin> — print the CUDA device line, or nothing.
cuda_device() {
  local bin="$1" out
  out="$(timeout 25 "$bin" --list-devices 2>&1 | grep -m1 -E '^[[:space:]]*CUDA[0-9]+:' || true)"
  printf '%s' "$out"
}

# verify_cuda <bin> — 0 when the build can use CUDA, 2 when it is CPU-only.
verify_cuda() {
  local bin="$1" dev
  dev="$(cuda_device "$bin")"
  [ -n "$dev" ] && return 0
  # A linked libggml-cuda is a second proof when --list-devices is unsupported.
  if have ldd && ldd "$bin" 2>/dev/null | grep -q 'libggml-cuda'; then
    return 0
  fi
  return 2
}

report() {
  local bin dev ver
  if ! bin="$(find_server)"; then
    printf 'llama-ensure[1]{engine,state}:\n  "llama-server","absent"\n'
    return 1
  fi
  ver="$("$bin" --version 2>&1 | grep -m1 -iE 'version:' || true)"
  if dev="$(cuda_device "$bin")"; then
    printf 'llama-ensure[1]{engine,path,cuda,version}:\n  "llama-server","%s","%s","%s"\n' \
      "$bin" "${dev#*: }" "${ver:-unknown}"
    return 0
  fi
  printf 'llama-ensure[1]{engine,path,cuda,version}:\n  "llama-server","%s","CPU-ONLY","%s"\n' \
    "$bin" "${ver:-unknown}"
  return 2
}

case "$ACTION" in
  path)
    find_server || { printf 'error: no llama-server found\nhelp: bin/llama-ensure.sh ensure\n' >&2; exit 1; }
    printf '\n'
    exit 0
    ;;
  status)
    report
    exit $?
    ;;
  ensure) ;;
  *) printf 'error: unknown command %s\nhelp: bin/llama-ensure.sh [status|ensure|path]\n' "$ACTION" >&2; exit 2 ;;
esac

# ── ensure: adopt what stands, else build ───────────────────────────────────
if bin="$(find_server)"; then
  if verify_cuda "$bin"; then
    printf 'llama-ensure[1]{action,state,path}:\n  "adopt","CUDA engine stands (not rebuilt)","%s"\n' "$bin"
    report >/dev/null 2>&1 || true
    exit 0
  fi
  if [ "${YMIR_LLAMA_CUDA:-on}" = "off" ]; then
    printf 'llama-ensure[1]{action,state,path}:\n  "adopt","CPU build accepted (YMIR_LLAMA_CUDA=off)","%s"\n' "$bin"
    exit 0
  fi
  printf 'error: the llama-server at %s is CPU-ONLY (no CUDA0 device)\n' "$bin" >&2
  printf 'help: a CPU build is ~10x slow and makes every measured number a lie.\n' >&2
  printf '      install a CUDA build, or set YMIR_LLAMA_CUDA=off to accept it deliberately.\n' >&2
  exit 2
fi

# None stands. Build only with consent; never a silent multi-GB act.
if [ "$INSTALL" != 1 ]; then
  printf 'llama-ensure[1]{action,state}:\n  "would-build","no llama-server found (consent needed)"\n'
  printf 'help: re-run with --install to build llama.cpp (CUDA) under %s\n' "$LLAMA_DIR" >&2
  exit 3
fi

missing=""
have git || missing="$missing git"
have cmake || missing="$missing cmake"
have nvcc || [ -d /opt/cuda ] || [ -d /usr/local/cuda ] || missing="$missing nvcc-or-cuda-toolkit"
if [ -n "$missing" ]; then
  printf 'error: cannot build llama.cpp — missing:%s\n' "$missing" >&2
  printf 'help: install the toolchain, or put a CUDA llama-server on PATH and re-run (it is adopted, not rebuilt).\n' >&2
  exit 4
fi

printf 'llama-ensure[1]{action,state,dir}:\n  "build","cloning + building llama.cpp with GGML_CUDA=ON","%s"\n' "$LLAMA_DIR"
mkdir -p "$(dirname "$LLAMA_DIR")"
if [ -d "$LLAMA_DIR/.git" ]; then
  git -C "$LLAMA_DIR" pull --ff-only >/dev/null 2>&1 || true
else
  git clone --depth 1 https://github.com/ggml-org/llama.cpp "$LLAMA_DIR" || {
    printf 'error: could not clone llama.cpp (network?)\n' >&2; exit 5; }
fi
cmake -S "$LLAMA_DIR" -B "$LLAMA_DIR/build" -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release >/dev/null || {
  printf 'error: cmake configure failed\n' >&2; exit 5; }
cmake --build "$LLAMA_DIR/build" --config Release -j"$(nproc 2>/dev/null || printf 4)" >/dev/null || {
  printf 'error: cmake build failed\n' >&2; exit 5; }

if bin="$(find_server)" && verify_cuda "$bin"; then
  printf 'llama-ensure[1]{action,state,path}:\n  "built","CUDA0 confirmed","%s"\n' "$bin"
  exit 0
fi
printf 'error: the build finished but CUDA0 was not found — the toolchain did not link CUDA\n' >&2
printf 'help: check the CUDA toolkit path and rebuild with -DGGML_CUDA=ON\n' >&2
exit 5
