#!/usr/bin/env bash
# saga-wake-drain.sh - present durable Brokk wakes, or acknowledge them.
#
# Sága sees the queue. `drain` (default) prints each durable wake; `ack` drops
# the queues once the wakes have been handled. Ported/trimmed from the upstream
# wake-drain contract for plan 29.
#
# Usage: saga-wake-drain.sh [drain|ack]
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
# The queue lives in the OPERATOR's state, never the code tree (Rule 04). Resolve
# it exactly as every shell tool does, so a standalone drain sees the same queue
# the watcher fills. It once defaulted to $BROKK_HOME/state (the TREE) and
# reported "0 pending" while the hoard queue held unhandled wakes (2026-09-23).
if [ -z "${BROKK_STATE_OVERRIDE:-}" ]; then
  if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
    for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
      [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
    done
    unset _c
  fi
  hoard_state_dir _HS 2>/dev/null && BROKK_STATE_OVERRIDE="$_HS"
  unset _HS
fi
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"

mkdir -p "$STATE"
QUEUE="$STATE/.wake-queue"
# The FM runner's own durable queue (its published check-wakes) lives under the
# .agents home, not the main state. The watcher hollers on BOTH doors; a drain
# that reads only one lets strikes hide in the other. Combine them here.
FMQ="$SCRIPT_DIR/../.agents/state/.wake-queue"

case "${1:-drain}" in
  -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  ack|--ack)
    # Drop the queues once their wakes have been handled. Clear the watcher's
    # flood-brake hash too, so a later wake signals cleanly.
    : >"$QUEUE" 2>/dev/null || true
    [ -f "$FMQ" ] && : >"$FMQ" 2>/dev/null
    rm -f "$STATE/.wake-last-hash" 2>/dev/null || true
    printf 'wake queue: acknowledged (0 pending)\n'
    exit 0
    ;;
  drain|--drain|"") ;;
  *) printf 'error: unknown action %s\nhelp: saga-wake-drain.sh [drain|ack]\n' "$1" >&2; exit 2 ;;
esac

if [ -s "$FMQ" ]; then
  printf 'FM wake queue: %s pending (fm-queued wakes below)\n' "$(wc -l <"$FMQ" | tr -d '[:space:]')"
  while IFS= read -r line; do
    [ -n "$line" ] && printf 'WAKE %s\n' "$line"
  done <"$FMQ"
  printf 'FM_ACK_REQUIRED: acknowledge handled fm wakes to drop them from the fm queue\n'
fi

if [ ! -s "$QUEUE" ]; then
  printf 'wake queue: 0 pending\n'
else
  count=$(wc -l <"$QUEUE" | tr -d '[:space:]')
  printf 'wake queue: %s pending\n' "${count:-0}"
  while IFS= read -r line; do
    [ -n "$line" ] && printf 'WAKE %s\n' "$line"
  done <"$QUEUE"
  printf 'WAKE_ACK_REQUIRED: acknowledge handled wakes to drop them from the queue\n'
fi

# Open-decision markers (approval gates) left unhandled.
decisions=$(find "$STATE" -maxdepth 1 -name '*.decision' 2>/dev/null | wc -l | tr -d '[:space:]')
printf 'open decisions: %s\n' "${decisions:-0}"
