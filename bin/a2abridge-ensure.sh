#!/usr/bin/env bash
# a2abridge-ensure.sh — ensure the A2A mesh engine (a2abridge) is present,
# its directory daemon is up, and its MCP wiring is in the harnesses.
#
# **Ratatoskr** runs on the open A2A 1.0 protocol via the MIT-licensed
# **a2abridge** engine (github.com/vbcherepanov/a2abridge) — one binary that
# is directory, bridge, service, cert, and doctor. The engine keeps its
# product name; the mesh Ymir calls Ratatoskr is the same wire.
#
# The engine's official installer writes IDE configs; Ymir owns the harness
# wiring itself (bin/a2a-mcp.sh → pi + opencode), so this ensure installs the
# engine with A2A_NO_IDE=1 and never lets the engine edit IDE configs.
#
# Usage:
#   a2abridge-ensure.sh status
#   a2abridge-ensure.sh ensure [--install]
#   a2abridge-ensure.sh install
#   a2abridge-ensure.sh --version
#
# Exit: 0 ready (or made ready), 1 not ready, 2 usage.
set -u

VERSION="1.0.0"
A2AB="${A2ABRIDGE_BIN:-$HOME/.a2abridge/bin/a2abridge}"
PREFIX="${A2AB%/bin/a2abridge}"
VERSION_TAG="${A2ABRIDGE_VERSION:-v3.0.0}"
DIR_URL="${A2A_DIRECTORY_URL:-http://127.0.0.1:7777}"
UNIT="$HOME/.config/systemd/user/a2abridge-directory.service"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
CMD="${1-}"; shift || true
DO_INSTALL=0
case "$CMD" in ensure) ;; status|install) ;; *) printf 'error: unknown command %s\nhelp: bin/a2abridge-ensure.sh [status|ensure|install]\n' "$CMD" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do case "$1" in --install) DO_INSTALL=1; shift ;; *) shift ;; esac; done
[ "$CMD" = install ] && DO_INSTALL=1

have() { command -v "$1" >/dev/null 2>&1; }

engine_present() { [ -x "$A2AB" ]; }
service_up() {
  have systemctl && systemctl --user is-active --quiet a2abridge-directory 2>/dev/null
}
directory_up() { curl -s --max-time 3 -o /dev/null "$DIR_URL"; }

install_engine() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  if ! curl -fsSL "https://raw.githubusercontent.com/vbcherepanov/a2abridge/main/install.sh" -o "$tmp/install.sh" 2>/dev/null; then
    return 1
  fi
  # The engine's own installer fails resolving the latest release on some
  # hosts (curl | grep pipe); pin the tag so the download always resolves.
  A2A_NO_IDE=1 bash "$tmp/install.sh" --version "$VERSION_TAG" >/dev/null 2>&1
}

patch_unit_logs() {
  # The engine's unit writes StandardOutput/Error to /var/log, which a
  # systemd --user service cannot touch — the daemon dies at STDOUT setup.
  # Point both at the journal unless they are already user-safe.
  [ -f "$UNIT" ] || return 0
  if rg -q '^StandardOutput=file:/var/log' "$UNIT" 2>/dev/null || rg -q '^StandardError=file:/var/log' "$UNIT" 2>/dev/null; then
    sed -i 's|^StandardOutput=file:.*|StandardOutput=journal|; s|^StandardError=file:.*|StandardError=journal|' "$UNIT"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user restart a2abridge-directory >/dev/null 2>&1 || true
  fi
}

status() {
  local eng srvc dir
  if engine_present; then eng="$("$A2AB" version 2>/dev/null | head -1)"; else eng="absent"; fi
  if service_up; then srvc="up"; else srvc="down"; fi
  if directory_up; then dir="up"; else dir="down"; fi
  printf 'a2abridge[1]{engine,directory,service}:\n  "%s","%s","%s"\n' "$eng" "$dir" "$srvc"
}

ensure() {
  local changed=0
  if ! engine_present; then
    if [ "$DO_INSTALL" = 1 ]; then
      install_engine || { printf 'a2abridge: install failed (offline?)\nhelp: re-run when the network returns\n' >&2; return 1; }
      changed=1
    else
      printf 'a2abridge: engine absent — run bin/a2abridge-ensure.sh ensure --install\n' >&2
      return 1
    fi
  fi
  patch_unit_logs
  if ! service_up; then
    systemctl --user start a2abridge-directory >/dev/null 2>&1 || true
    sleep 1
  fi
  if ! directory_up; then
    printf 'a2abridge: directory not answering on A2A_DIRECTORY\nhelp: systemctl --user status a2abridge-directory\n' >&2
    return 1
  fi
  status
  return 0
}

case "$CMD" in
  status) status ;;
  install) DO_INSTALL=1; ensure ;;
  ensure) ensure ;;
esac