#!/usr/bin/env bash
# brokk-send.sh — send a one-line steer to a running Brokk/Eindri-home.
# Resolves the target's home from data/eindri-homes.md and appends a wake line to
# its state/.wake-queue (the drain prints it as `WAKE <line>`). Local routes only;
# a remote route must be nudged on its own host. Galdr-style TOON.
#
# Usage: brokk-send.sh <id> <message>
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

case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;; -h|--help|"") sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
ID="${1-}"; shift || true
MSG="${*:-}"
[ -n "$ID" ] && [ -n "$MSG" ] || { printf 'error: usage: brokk-send.sh <id> <message>\n' >&2; exit 2; }

if [ "$ID" = "this" ] || [ "$ID" = "brokk" ]; then HOME_DIR="$ROOT"; HOST=""; else
  HOME_DIR=""; HOST=""
  if [ -f "$REG" ]; then
    line="$(grep -E "^- ${ID} " "$REG" | head -1)"
    HOST="$(printf '%s' "$line" | sed -nE 's/.*\(host: ([^;)]+).*/\1/p' | tr -d ' ')"
    HOME_DIR="$(printf '%s' "$line" | sed -nE 's/.*\(.*home: ([^;)]+).*/\1/p' | tr -d ' ')"
  fi
fi

if [ -n "$HOST" ]; then
  printf 'send[1]{id,state,detail}:\n  "%s","remote","run bin/brokk-send.sh %s on host %s"\n' "$ID" "$ID" "$HOST"
  exit 1
fi
[ -n "$HOME_DIR" ] && [ -d "$HOME_DIR" ] || { printf 'send[1]{id,state,detail}:\n  "%s","unknown","no home for id (see %s)"\n' "$ID" "${REG#"$ROOT"/}"; exit 1; }

mkdir -p "$HOME_DIR/state"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'from=brokk to=%s at=%s msg=%s\n' "$ID" "$ts" "$MSG" >>"$HOME_DIR/state/.wake-queue"
printf 'send[1]{id,state,detail}:\n  "%s","queued","%s/state/.wake-queue"\n' "$ID" "${HOME_DIR#"$ROOT"/}"
