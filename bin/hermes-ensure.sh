#!/usr/bin/env bash
# hermes-ensure.sh — ensure the Hermes agent runtime is present.
#
# **Hermes** is Nous Research's open-source agent runtime
# (https://hermes-agent.nousresearch.com, MIT) — its own brain, config, memory,
# skills, scheduling, and subagents. Ymir adopts it as a **worker runtime** (an
# external engine, like opencode / pi / treehouse); the name is the product's,
# never a Norse rename.
#
# Usage:
#   hermes-ensure.sh status
#   hermes-ensure.sh ensure [--install] [--quiet]
#   hermes-ensure.sh install
#   hermes-ensure.sh --version
#
# Exit: 0 present (or installed), 1 absent and not installed, 2 usage.
set -u

VERSION="1.0.0"
HOME_DIR="${HERMES_HOME:-$HOME/.hermes}"
INSTALL_URL="${HERMES_INSTALL_URL:-https://hermes-agent.nousresearch.com/install.sh}"

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
CMD="${1-}"; shift || true
DO_INSTALL=0
case "$CMD" in ensure) ;; status|install) ;; *) printf 'error: unknown command %s\nhelp: bin/hermes-ensure.sh [status|ensure|install]\n' "$CMD" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do case "$1" in --install) DO_INSTALL=1; shift ;; --quiet) shift ;; *) shift ;; esac; done
[ "$CMD" = install ] && DO_INSTALL=1

hermes_bin() {
  if command -v hermes >/dev/null 2>&1; then command -v hermes; return; fi
  for p in "$HOME_DIR/bin/hermes" "$HOME/.local/bin/hermes"; do
    [ -x "$p" ] && { printf '%s' "$p"; return; }
  done
  return 1
}

hermes_version() {
  local b; b="$(hermes_bin)" || return 1
  "$b" --version 2>/dev/null | head -n1
}

status() {
  local b v method dir
  if b="$(hermes_bin)"; then
    v="$(hermes_version)"
    dir="$HOME_DIR/hermes-agent"; [ -d "$dir" ] || dir="$HOME_DIR"
    method="binary"
    [ -d "$HOME_DIR/hermes-agent/.git" ] && method="git"
    printf 'hermes[1]{installed,version,path,method}:\n'
    printf '  "true","%s","%s","%s"\n' "$v" "$b" "$method"
    return 0
  fi
  printf 'hermes[1]{installed,version,path,method}:\n'
  printf '  "false","—","—","—"\n'
  return 1
}

install_hermes() {
  command -v curl >/dev/null 2>&1 || { printf 'error: curl not found — cannot install Hermes\nhelp: %s\n' "$INSTALL_URL" >&2; return 1; }
  printf 'hermes: installing from %s …\n' "$INSTALL_URL" >&2
  if curl -fsSL "$INSTALL_URL" | bash >/dev/null 2>&1; then
    printf 'hermes: install finished\n' >&2
  else
    printf 'hermes: install failed (offline?) — install manually: curl -fsSL %s | bash\n' "$INSTALL_URL" >&2
    return 1
  fi
}

case "$CMD" in
  status) status; exit $? ;;
  install) install_hermes; status; exit $? ;;
  ensure)
    if status >/dev/null 2>&1; then
      [ -n "${1-}" ] || status
      status
      exit 0
    fi
    if [ "$DO_INSTALL" = 1 ]; then
      install_hermes || true
      status
      hermes_bin >/dev/null 2>&1
      exit $?
    fi
    printf 'hermes[1]{installed,version,path,method}:\n  "false","—","—","—"\n'
    printf 'hermes: not installed — run `bin/hermes-ensure.sh install` or curl -fsSL %s | bash\n' "$INSTALL_URL" >&2
    exit 1 ;;
esac
