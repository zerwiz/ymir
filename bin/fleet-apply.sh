#!/usr/bin/env bash
# fleet-apply.sh — apply fleet-wide preferences to every registered Eindri-home.
#
# Reads `data/fleet.md` (`key: value` lines; key `ro` = on|off) and writes each
# into the home's gitignored `state/` (for `ro`: `state/ro`), so a single fleet
# setting reaches every home without dirtying any tracked tree. Remote routes are
# reported, not written. Galdr-style TOON.
#
# Usage:
#   fleet-apply.sh [--check]
#   fleet-apply.sh --version
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$(dirname "$_yr")/bin/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
REG="${BROKK_EINDRI_HOMES:-$YMIR_DATA_DIR/eindri-homes.md}"
PREFS="${BROKK_FLEET_PREFS:-$YMIR_DATA_DIR/fleet.md}"
CHECK=0

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
[ "${1-}" = "--check" ] && CHECK=1

pref() { sed -nE "s/^[[:space:]]*$1:[[:space:]]*([^[:space:]#]+).*/\1/p" "$PREFS" 2>/dev/null | head -1; }

if [ ! -f "$PREFS" ]; then
  printf 'fleet[1]{prefs,state,detail}:\n  "absent","noop","%s (no fleet preferences set)"\n' "${PREFS#"$ROOT"/}"
  exit 0
fi

ro="$(pref ro)"
[ -n "$ro" ] || ro=""

declare -a ROWS
apply_home() { # <id> <path>
  local id="$1" p="$2"
  [ -d "$p" ] || { ROWS+=("  \"$id\",\"$p\",\"skipped\",\"not found\""); return; }
  if [ "$CHECK" = 1 ]; then ROWS+=("  \"$id\",\"$p\",\"would-apply\",\"ro=$ro\""); return; fi
  if [ -n "$ro" ]; then
    mkdir -p "$p/state"
    printf '%s\n' "$ro" >"$p/state/ro" && ROWS+=("  \"$id\",\"$p\",\"applied\",\"ro=$ro\"") || ROWS+=("  \"$id\",\"$p\",\"failed\",\"ro\"")
  else
    ROWS+=("  \"$id\",\"$p\",\"noop\",\"no ro pref\"")
  fi
}

# This home is always a target.
apply_home "this" "$ROOT"

if [ -f "$REG" ]; then
  while IFS= read -r line; do
    case "$line" in '- '*) ;; *) continue ;; esac
    id="$(printf '%s' "$line" | sed -nE 's/^- ([^ ]+).*/\1/p')"
    host="$(printf '%s' "$line" | sed -nE 's/.*\(host: ([^;)]+).*/\1/p' | tr -d ' ')"
    home="$(printf '%s' "$line" | sed -nE 's/.*\(.*home: ([^;)]+).*/\1/p' | tr -d ' ')"
    [ -n "$id" ] || continue
    if [ -n "$host" ]; then
      ROWS+=("  \"$id\",\"remote $host\",\"skipped\",\"run bin/fleet-apply.sh on $host\""); continue
    fi
    [ -n "$home" ] || home="$id"
    apply_home "$id" "$home"
  done <"$REG"
else
  ROWS+=("  \"-\",\"registry\",\"absent\",\"$REG (no Eindri-homes registered)\"")
fi

printf 'fleet[%d]{id,target,state,detail}:\n' "${#ROWS[@]}"
printf '%s\n' "${ROWS[@]}"
