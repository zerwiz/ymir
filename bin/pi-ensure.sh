#!/usr/bin/env bash
# pi-ensure.sh — ensure the Pi coding agent and the Ymir-required Pi packages.
#
# Pi has no native MCP, no native web access, and no built-in local-model bridge:
# those arrive as Pi packages. This guarantees the three Ymir depends on:
#   npm:pi-mcp-adapter  — MCP servers (from mcp.json: a2abridge, engram)
#   npm:pi-web-access   — web fetch/search tools
#   npm:pi-lmstudio     — LM Studio / local model provider
#
# Usage:
#   pi-ensure.sh status            # pi + which packages are present
#   pi-ensure.sh ensure [--install]
#   pi-ensure.sh install
#   pi-ensure.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SETTINGS="${PI_SETTINGS:-$HOME/.pi/agent/settings.json}"
REQUIRED=(pi-mcp-adapter pi-web-access pi-lmstudio)

CMD="status"; INSTALL=0
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
case "$1" in status|ensure|install) CMD=$1; shift ;; *) printf 'error: unknown command %s\nhelp: pi-ensure.sh [status|ensure|install]\n' "$1" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do case "$1" in --install) INSTALL=1; shift ;; *) shift ;; esac; done
[ "$CMD" = install ] && INSTALL=1

have() { command -v "$1" >/dev/null 2>&1; }
pi_bin() { command -v pi 2>/dev/null || true; }
pkg_present() { grep -q "npm:$1" "$SETTINGS" 2>/dev/null; }

install_pi() {
  have pi && return 0
  if have mise; then
    mise install pi@latest >/dev/null 2>&1 || mise use -g pi@latest >/dev/null 2>&1 || true
  fi
  have pi
}

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
  local bin ver p rows="" missing=0
  bin="$(pi_bin)"; ver="$(pi --version 2>/dev/null | head -1)"
  printf 'pi[1]{bin,version}:\n  "%s","%s"\n' "${bin:-none}" "${ver:-none}"
  for p in "${REQUIRED[@]}"; do
    if pkg_present "$p"; then rows="${rows}  \"${p}\",\"present\"\n"; else rows="${rows}  \"${p}\",\"absent\"\n"; missing=$((missing+1)); fi
  done
  printf 'pi-packages[%d]{package,state}:\n' "${#REQUIRED[@]}"
  printf '%b' "$rows"
  return "$missing"
}

case "$CMD" in
  status)
    report || exit 1
    ;;
  ensure)
    if ! have pi && [ "$INSTALL" = 1 ]; then install_pi || true; fi
    if have pi && [ "$INSTALL" = 1 ]; then install_pkgs || true; fi
    if report; then exit 0; else exit 1; fi
    ;;
  install)
    install_pi || { printf 'error: pi could not be installed (need mise or npm)\n' >&2; exit 1; }
    install_pkgs
    report && exit 0 || exit 1
    ;;
esac
