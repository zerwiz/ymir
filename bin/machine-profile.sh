#!/usr/bin/env bash
# machine-profile.sh — a body reads its OWN card (wave C, the persona loader).
#
# Every machine carries its setup in the hoard: `hodd/data/knows/<seat>.md`
# (OS · silicon · roles · services · limits · ward) + its row in
# `hodd/data/machines.md`. A body calls this BEFORE it acts on a seat, so it
# never improvises a machine it does not know.
#
# Usage:
#   machine-profile.sh                  # THIS machine's card (by hostname)
#   machine-profile.sh --seat <name>   # any seat's card by name
#   machine-profile.sh --seats         # the roster of known cards
# Env: BROKK_HOME (default the private home), BROKK_ROOT_OVERRIDE
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
HOME_ROOT="${BROKK_HOME:-$HOME/Documents/ymirhome}"
KNOWS="$HOME_ROOT/hodd/data/knows"
MACHINES="$HOME_ROOT/hodd/data/machines.md"

seat_of_host() {
  case "$(hostname 2>/dev/null | tr 'A-Z' 'a-z')" in
    omarchy) echo omarchy ;; heimdall*) echo heimdall ;; *whynot*|whynot) echo whynot ;;
    zerwizserver|*server*) echo zerwizserver ;; *) echo "" ;;
  esac
}

case "${1-}" in
  --seats) ls "$KNOWS" 2>/dev/null | sed 's/.md$//' || echo "no knows shelf at $KNOWS" ;;
  --seat)
    [ -n "${2-}" ] || { echo "error: --seat <name>" >&2; exit 2; }
    f="$KNOWS/${2}.md"
    [ -f "$f" ] || { echo "error: no card for '$2' ($f)" >&2; exit 1; }
    cat "$f" ;;
  *) s="$(seat_of_host)"
     if [ -n "$s" ] && [ -f "$KNOWS/$s.md" ]; then cat "$KNOWS/$s.md"; else
       echo "machine-profile[1]{seat,card}:"
       echo "  \"${s:-unknown}\",\"$KNOWS/${s:-}.md\""
     fi ;;
esac