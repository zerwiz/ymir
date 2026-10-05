#!/usr/bin/env bash
# pi-ensure.sh — ensure the Pi packages Ymir depends on.
#
# SCOPE: this script owns the Pi PACKAGES and nothing else. The Pi binary is the
# operator's tool, installed and versioned by the operator, on whatever channel
# the operator chooses. Ymir does not install it, does not pick a channel for
# it, and does not edit the operator's npm config, shell rc, or PATH to steer it.
# That boundary was drawn here deliberately (2026-09-30): an earlier version of
# this script installed Pi through mise, which put a second, independently
# versioned copy on every seat and reported healthy while doing it.
#
# What Ymir genuinely needs from Pi, because Ymir's own function depends on it:
#   npm:pi-mcp-adapter  — MCP servers (from mcp.json: a2abridge, engram)
#   npm:pi-web-access   — web fetch/search tools
#   npm:pi-lmstudio     — LM Studio / local model provider
#
# If Pi itself is absent, this script says so and exits non-zero. It does not
# resolve that. `pi install npm:<pkg>` manages its own extension prefix
# (~/.pi/agent/npm), so the packages land in Pi's tree, not the operator's npm
# global — which is why ensuring them here needs no npm configuration at all.
#
# Usage:
#   pi-ensure.sh status            # the answering Pi (version + where it came
#                                  # from) and whether the packages are present
#   pi-ensure.sh ensure [--install] # ensure the packages
#   pi-ensure.sh install           # alias of `ensure --install`
#   pi-ensure.sh --version
set -u

VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
SETTINGS="${PI_SETTINGS:-$HOME/.pi/agent/settings.json}"
REQUIRED=(pi-mcp-adapter pi-web-access pi-lmstudio)

CMD="status"; INSTALL=0
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") awk 'NR>1 && /^#/{sub(/^# ?/,""); print; next} NR>1{exit}' "$0"; exit 0 ;; esac
case "$1" in status|ensure|install) CMD=$1; shift ;; *) printf 'error: unknown command %s\nhelp: pi-ensure.sh [status|ensure|install]\n' "$1" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do case "$1" in --install) INSTALL=1; shift ;; *) shift ;; esac; done
[ "$CMD" = install ] && INSTALL=1

have() { command -v "$1" >/dev/null 2>&1; }
pi_bin() { command -v pi 2>/dev/null || true; }
pkg_present() { grep -q "npm:$1" "$SETTINGS" 2>/dev/null; }

# Where the answering Pi actually lives, resolved through any symlink or shim.
# Reported, never judged: a second Pi on the box is the operator's to resolve,
# and seeing two paths side by side is the whole value of printing this.
pi_origin() {
  local b
  b="$(pi_bin)"
  [ -n "$b" ] || { printf 'none'; return 0; }
  readlink -f "$b" 2>/dev/null || printf '%s' "$b"
}

# Ymir's own dependency: the three packages, installed through Pi so they land in
# Pi's extension prefix. No npm, no sudo, no operator configuration touched.
install_pkgs() {
  local p
  have pi || return 1
  for p in "${REQUIRED[@]}"; do
    pkg_present "$p" && continue
    pi install "npm:$p" >/dev/null 2>&1 || true
  done
  return 0
}

report() {
  local ver origin p rows="" missing=0
  ver="$(pi --version 2>/dev/null | head -1)"
  origin="$(pi_origin)"
  printf 'pi[1]{version,origin}:\n  "%s","%s"\n' "${ver:-absent}" "${origin}"
  for p in "${REQUIRED[@]}"; do
    if pkg_present "$p"; then rows="${rows}  \"$p\",\"present\"\n"; else rows="${rows}  \"$p\",\"absent\"\n"; missing=$((missing+1)); fi
  done
  printf 'pi-packages[%s]{package,state}:\n' "${#REQUIRED[@]}"
  printf '%b' "$rows"
  return "$missing"
}

case "$CMD" in
  status)
    report || exit 1
    ;;
  ensure)
    if [ "$INSTALL" = 1 ] && have pi; then
      install_pkgs || true
    fi
    if ! have pi; then
      report || true
      printf 'error: pi is not on PATH — Pi is the operator'"'"'s to install; this script only ensures Ymir'"'"'s packages\n' >&2
      exit 1
    fi
    if report; then exit 0; else exit 1; fi
    ;;
  install)
    if ! have pi; then
      printf 'error: pi is not on PATH — Pi is the operator'"'"'s to install; this script only ensures Ymir'"'"'s packages\n' >&2
      exit 1
    fi
    install_pkgs
    report && exit 0 || exit 1
    ;;
esac
