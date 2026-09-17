#!/usr/bin/env bash
# nornir-job-hall-snapshot.sh — Óðrerir: refresh the Live Hall's board.
#
# The Hall is a glass: it reads apps/odrerir/public/livehall.json, written by
# this job from the real system state (runes · projects · cron · wake queue ·
# standing smiths · armed when-sources · landed errands). Scheduled at 08:00,
# after the 06:00 observer and the 07:00 briefing, so the morning's board
# carries the day's fresh runes. Stateless: read inputs → write the snapshot →
# carve a Rune → exit.
#
# Overrides: BROKK_ROOT_OVERRIDE (hall-snapshot.sh), YMIR_HOME (the hoard).
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# The snapshot is runtime, never repo: it is gitignored where it lands.
if ! "$ROOT/bin/hall-snapshot.sh" >/dev/null 2>&1; then
  printf 'error: hall-snapshot.sh failed — the board is stale\n'
  printf 'help: run bin/hall-snapshot.sh by hand to see the reason\n'
  exit 1
fi

# Carve the Rune — the ledger lives with the hoard.
# shellcheck source=bin/runes-append.sh
. "$ROOT/bin/runes-append.sh"
runes_append "odrerir" "hall.snapshot" --message "Live Hall board refreshed from real state" >/dev/null \
  || printf 'hall-snapshot: rune append failed (non-fatal)\n'
printf 'hall-snapshot: Live Hall board refreshed\n'