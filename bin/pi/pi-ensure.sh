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
# What Ymir genuinely needs from Pi is named in ONE place — the pi harness descriptor,
# `.agents/harnesses/pi.yaml` (`packages:` and `root_extensions:`, plan 248 P3, 2026-11-11).
# This script used to keep its own list (pi-mcp-adapter · pi-web-access · pi-lmstudio) while
# the seat's settings carried telegram and ask-user beside it; two lists drift, so it now reads
# the descriptor and refuses to guess when the descriptor cannot be read. Today's set:
#   npm:pi-mcp-adapter                       MCP servers (the gateway doors, the ymir door)
#   npm:pi-web-access                        web fetch/search tools
#   npm:@llblab/pi-telegram                  the Telegram seat
#   npm:@juicesharp/rpiv-ask-user-question   ask-user — the ask_user_question tool
# pi-lmstudio left the list with LM Studio's retirement (2026-10-24); a seat that has it keeps
# it — this script installs, it never removes.
#
# THE ROOT SET. `status` also proves pi's ROOT carries Ymir's own extensions from the pinned
# runtime (bin/seat/runtime-root.sh): every name in `root_extensions` (ro · todo · open-editor)
# stands in $YMIR_RUNTIME_DIR/.pi/extensions, and the root settings `extensions[]` names that
# tree — so a session opened in ~ or in an unrelated project has them.
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

VERSION="1.2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"
SETTINGS="${PI_SETTINGS:-$HOME/.pi/agent/settings.json}"
DESCRIPTOR="${PI_DESCRIPTOR:-$ROOT/.agents/harnesses/pi.yaml}"

# <key> -> the `  - item` lines under a top-level `key:` of the descriptor, one per line.
descriptor_list() {
  [ -r "$DESCRIPTOR" ] || return 0
  awk -v k="$1:" '
    $0 == k { on=1; next }
    on && /^  - / { sub(/^  - /, ""); sub(/[[:space:]]+#.*$/, ""); gsub(/^"|"$/, ""); print; next }
    on && /^[^ #]/ { on=0 }
  ' "$DESCRIPTOR"
}
REQUIRED=(); ROOT_SET=()
while IFS= read -r _x; do [ -n "$_x" ] && REQUIRED+=("$_x"); done < <(descriptor_list packages)
while IFS= read -r _x; do [ -n "$_x" ] && ROOT_SET+=("$_x"); done < <(descriptor_list root_extensions)
unset _x

# The runtime the root loads (plan 248 P2): the pinned one, else this checkout — and the reason.
YMIR_RUNTIME_ROOT="$ROOT"; YMIR_RUNTIME_SOURCE="checkout"; YMIR_RUNTIME_REASON="no runtime door in this tree"
if [ -r "$ROOT/bin/seat/runtime-root.sh" ]; then
  # shellcheck disable=SC1091
  . "$ROOT/bin/seat/runtime-root.sh"
  ymir_runtime_resolve "$ROOT"
fi

CMD="status"; INSTALL=0
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") awk 'NR>1 && /^#/{sub(/^# ?/,""); print; next} NR>1{exit}' "$0"; exit 0 ;; esac
case "$1" in status|ensure|install) CMD=$1; shift ;; *) printf 'error: unknown command %s\nhelp: pi-ensure.sh [status|ensure|install]\n' "$1" >&2; exit 2 ;; esac
while [ $# -gt 0 ]; do case "$1" in --install) INSTALL=1; shift ;; *) shift ;; esac; done
[ "$CMD" = install ] && INSTALL=1

have() { command -v "$1" >/dev/null 2>&1; }
pi_bin() { command -v pi 2>/dev/null || true; }
pkg_present() { grep -qF "\"$1\"" "$SETTINGS" 2>/dev/null; }   # <spec> as the descriptor names it (npm:…)

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
    pi install "$p" >/dev/null 2>&1 || true
  done
  return 0
}

# The pi ROOT set: each name stands in the runtime's tree, and the root settings name that tree.
root_report() {
  local tree="$YMIR_RUNTIME_ROOT/.pi/extensions" n rows="" miss=0 named="absent"
  for n in ${ROOT_SET[@]+"${ROOT_SET[@]}"}; do
    if [ -f "$tree/$n.ts" ] || [ -f "$tree/$n/index.ts" ] || [ -f "$tree/$n.js" ] || [ -f "$tree/$n/index.js" ]; then
      rows="${rows}  \"$n\",\"present\",\"$tree\"\n"
    else
      rows="${rows}  \"$n\",\"absent\",\"not in $tree\"\n"; miss=$((miss+1))
    fi
  done
  grep -qF "\"$tree\"" "$SETTINGS" 2>/dev/null && named="named" || miss=$((miss+1))
  printf 'pi-root[%s]{extension,state,tree}:\n' "${#ROOT_SET[@]}"
  printf '%b' "$rows"
  printf 'pi-root-settings[1]{tree,state,runtime}:\n  "%s","%s","%s"\n' "$tree" "$named" "$YMIR_RUNTIME_SOURCE"
  [ "$YMIR_RUNTIME_SOURCE" = checkout ] && printf 'note: %s\n' "$YMIR_RUNTIME_REASON"
  [ "$named" = named ] || printf 'help: bin/seat/harness-extensions-install.sh (binds the root settings to %s)\n' "$tree"
  return "$miss"
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
  root_report || missing=$((missing+1))
  return "$missing"
}

if [ "${#REQUIRED[@]}" -eq 0 ]; then
  printf 'error: no packages read from %s — the pi descriptor is the ONE place they are named; refusing to guess\n' "$DESCRIPTOR" >&2
  exit 1
fi

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
