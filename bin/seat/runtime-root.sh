#!/usr/bin/env bash
# runtime-root.sh — the ONE door to the runtime a root agent loads, and the ward over every root config.
#
#   bin/seat/runtime-root.sh                  runtime[1]{dir,source,reason} — the runtime this machine serves from
#   bin/seat/runtime-root.sh --dir            the directory alone
#   bin/seat/runtime-root.sh scan [--only <harness>]
#                                             every harness root config Ymir writes; a path into a working tree
#                                             (any Ymir checkout that is not the runtime) is a row, and exit 1
#   bin/seat/runtime-root.sh repoint [--only <harness>] [--dry-run]
#                                             re-point such paths at the runtime, one backup per file kept;
#                                             a path with no twin in the runtime is HELD and named, never guessed
#
# Sourced (`. bin/seat/runtime-root.sh`), it defines `ymir_runtime_resolve [<checkout>]`, which sets
#   YMIR_RUNTIME_ROOT    the directory every root agent must load
#   YMIR_RUNTIME_SOURCE  pinned | checkout
#   YMIR_RUNTIME_REASON  one line saying why — a fallback to the checkout always says so
#
# WHY (plan 248 P2, RULES/51 — 2026-11-11). pi's ROOT settings named ~/ymir/.pi/extensions, the WORKING TREE,
# though $YMIR_HOME/config/runtime.env pins ~/ymir-runtime. The cause was a reader, not a writer: three tools
# read runtime.env with `sed`, which keeps `YMIR_RUNTIME_DIR="$HOME/ymir-runtime"` as the literal text
# `$HOME/ymir-runtime` — a directory that never exists — so every one of them fell back to the checkout it
# ran from, and a `git checkout` there changed the code every root agent loaded (the PR #654 duplicate-tools
# class). This door SOURCES the file in a subshell, as runtime-deploy.sh always has, and is the only reader.
#
# Resolution, in order: runtime.env's YMIR_RUNTIME_DIR · an exported YMIR_RUNTIME_DIR · else the checkout,
# with the reason. A pin that is not a Ymir checkout (no bin/seat, no RULES) is refused, and said so.
# Exit: 0 ok · 1 scan found a working-tree path (or repoint held one) · 2 usage.
_rr_self="${BASH_SOURCE[0]}"
_rr_dir="$(cd "$(dirname "$_rr_self")" && pwd)"

ymir_runtime_resolve() {  # [<checkout>] — the tree to fall back to (default: the tree holding this file)
  local checkout="${1:-}" home="" conf="" pin=""
  [ -n "$checkout" ] || checkout="$(cd "$_rr_dir/../.." && pwd)"
  home="${YMIR_HOME:-}"
  if [ -z "$home" ] && [ -r "$checkout/bin/vault/hoard-lib.sh" ]; then
    # shellcheck disable=SC1091
    . "$checkout/bin/vault/hoard-lib.sh" 2>/dev/null || true
    declare -f ymir_home_root >/dev/null 2>&1 && ymir_home_root home 2>/dev/null || true
  fi
  [ -n "$home" ] && conf="$home/config/runtime.env"
  if [ -n "$conf" ] && [ -r "$conf" ]; then
    # SOURCED, in a subshell: `$HOME` and every other expansion the operator wrote is honoured, and nothing
    # else the file sets leaks into the caller.
    pin="$( unset YMIR_RUNTIME_DIR; . "$conf" >/dev/null 2>&1; printf '%s' "${YMIR_RUNTIME_DIR:-}" )"
  fi
  [ -n "$pin" ] || pin="${YMIR_RUNTIME_DIR:-}"
  if [ -n "$pin" ]; then
    case "$pin" in "~"/*) pin="$HOME/${pin#\~/}" ;; esac
    if [ -d "$pin/bin/seat" ] && [ -d "$pin/RULES" ]; then
      YMIR_RUNTIME_ROOT="$(cd "$pin" && pwd -P)"
      YMIR_RUNTIME_SOURCE="pinned"
      YMIR_RUNTIME_REASON="pinned by ${conf:-YMIR_RUNTIME_DIR}"
      return 0
    fi
    YMIR_RUNTIME_ROOT="$(cd "$checkout" && pwd -P)"
    YMIR_RUNTIME_SOURCE="checkout"
    YMIR_RUNTIME_REASON="the pinned runtime $pin is not a Ymir checkout — falling back to the checkout (run bin/engine/runtime-deploy.sh)"
    return 0
  fi
  YMIR_RUNTIME_ROOT="$(cd "$checkout" && pwd -P)"
  YMIR_RUNTIME_SOURCE="checkout"
  YMIR_RUNTIME_REASON="no runtime pinned (${conf:-no YMIR_HOME}/config/runtime.env names none) — the checkout serves"
  return 0
}

# Sourced: define the function and stop.
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  return 0 2>/dev/null || true
fi

set -uo pipefail
usage() { sed -n '2,26p' "$_rr_self" | sed 's/^# \{0,1\}//'; }

action="show"; only=""; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dir) action="dir" ;;
    scan|repoint) action="$1" ;;
    --only) shift; only="${1:-}"; [ -n "$only" ] || { printf 'error: --only needs a harness\n' >&2; exit 2; } ;;
    --dry-run) dry=1 ;;
    *) printf 'error: unknown argument %s\nhelp: runtime-root.sh [--dir|scan|repoint] [--only <harness>] [--dry-run]\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

ymir_runtime_resolve
case "$action" in
  dir)  printf '%s\n' "$YMIR_RUNTIME_ROOT" ;;
  show) printf 'runtime[1]{dir,source,reason}:\n  "%s","%s","%s"\n' "$YMIR_RUNTIME_ROOT" "$YMIR_RUNTIME_SOURCE" "$YMIR_RUNTIME_REASON" ;;
  scan|repoint)
    command -v python3 >/dev/null 2>&1 || { printf 'error: python3 is required to read the root configs\n' >&2; exit 1; }
    args=("$action" --runtime "$YMIR_RUNTIME_ROOT" --source "$YMIR_RUNTIME_SOURCE")
    [ -n "$only" ] && args+=(--only "$only")
    [ "$dry" = 1 ] && args+=(--dry-run)
    exec python3 "$_rr_dir/runtime-roots.py" "${args[@]}"
    ;;
esac
