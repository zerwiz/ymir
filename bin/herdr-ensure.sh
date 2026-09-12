#!/usr/bin/env bash
# herdr-ensure.sh — Þjazi: guarantee the terminal backend Ymir needs.
#
# Ymir is a herdr-first system: agent panes need a backend with Þjazi protocol
# 14+ (presentation spaces need herdr 0.8.0+). This helper detects, verifies the
# version, and installs when absent — in user space. tmux remains an acceptable
# backend, so a host with tmux is not treated as broken.
#
# Usage:
#   bin/herdr-ensure.sh status            # what is present, and does it meet the floor
#   bin/herdr-ensure.sh ensure [--install]
#   bin/herdr-ensure.sh --version
#
# Output: Galdr TOON. Exit 0 when a usable backend exists, 1 when none does.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIN_PROTOCOL=14          # agent panes
MIN_SPACES="0.8.0"       # presentation spaces
PINNED_INSTALLER="$ROOT/.agents/backend/fm-install-herdr.sh"

have() { command -v "$1" >/dev/null 2>&1; }

herdr_version() { herdr --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }

# version_ge A B -> A >= B
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

status() {
  local hv="" backend="none" note=""
  if have herdr; then
    hv="$(herdr_version)"
    backend="herdr"
  elif have tmux; then
    backend="tmux"
  fi
  case "$backend" in
    herdr)
      if [ -n "$hv" ] && version_ge "$hv" "$MIN_SPACES"; then
        note="panes ok (protocol ${MIN_PROTOCOL}+) · presentation spaces ok"
      else
        note="present but older than ${MIN_SPACES}; presentation spaces unavailable"
      fi
      printf 'thjazi[1]{backend,version,state,note}:\n  "herdr","%s","present","%s"\n' "${hv:-?}" "$note"
      ;;
    tmux)
      printf 'thjazi[1]{backend,version,state,note}:\n  "tmux","%s","present","verified reference backend; herdr preferred for presentation spaces"\n' "$(tmux -V 2>/dev/null | awk '{print $2}')"
      ;;
    *)
      printf 'thjazi[1]{backend,version,state,note}:\n  "none","-","absent","no herdr and no tmux — agent panes cannot be spawned"\n'
      return 1
      ;;
  esac
  return 0
}

# One backend, two names: upstream ships `herdr`, the Omarchy/Þjazi layer calls
# the same binary `hdr`. Alias them so either name reaches the same tool and
# every script (Ymir, Omarchy) shares one code path — never two.
link_hdr() {
  have hdr && return 0
  local bin
  bin="$(command -v herdr 2>/dev/null)" || return 0
  mkdir -p "$HOME/.local/bin" || return 1
  ln -sf "$bin" "$HOME/.local/bin/hdr" 2>/dev/null || return 1
}

ensure() {
  local install="${1:-}"
  if have herdr; then link_hdr; status; return $?; fi
  if [ "$install" != "--install" ]; then
    status
    printf 'help: bin/herdr-ensure.sh ensure --install  (or install tmux as a fallback)\n'
    return 1
  fi
  # Preferred: the pinned, SHA-verified installer (exact version + protocol check).
  if [ -x "$PINNED_INSTALLER" ]; then
    mkdir -p "$HOME/.local/bin"
    if "$PINNED_INSTALLER" "$HOME/.local/bin" >/dev/null 2>&1 && have herdr; then
      link_hdr
      status; return $?
    fi
  fi
  # Fallback: tmux, which Ymir accepts as its verified reference backend.
  if ! have tmux; then
    if have pacman; then printf 'help: sudo pacman -S --needed tmux\n' >&2
    elif have apt-get; then printf 'help: sudo apt-get install -y tmux\n' >&2; fi
  fi
  status
  return $?
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

case "${1-}" in
  status) status ;;
  ensure|"") ensure "${2:-}" ;;
  *) printf 'error: unknown action %s\nhelp: bin/herdr-ensure.sh [status|ensure [--install]]\n' "$1" >&2; exit 2 ;;
esac
