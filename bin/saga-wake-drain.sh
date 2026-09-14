#!/usr/bin/env bash
# saga-wake-drain.sh - present durable Brokk wakes.
#
# Sága sees the queue. This drains the durable wake queue written by the watcher
# and prints each record; records stay durable until acknowledged. Ported/trimmed
# from the upstream wake-drain contract for plan 29.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"

mkdir -p "$STATE"
QUEUE="$STATE/.wake-queue"
# The FM runner's own durable queue (its published check-wakes) lives under the
# .agents home, not the main state. The watcher hollers on BOTH doors; a drain
# that reads only one lets strikes hide in the other. Combine them here.
FMQ="$SCRIPT_DIR/../.agents/state/.wake-queue"
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
