#!/usr/bin/env bash
# eindri-heartbeat.sh — condition half of the Eindri silence bridge.
#
# D8 (2026-09-24): a dead worker must not look like a thinking one. einherjar-
# spawn records a launch timestamp and appends a heartbeat baseline to
# state/<id>.status; this condition answers "has this worker stopped talking?"
# A worker with NO status append inside the window is SUSPECT: exit 0 (true)
# fires the wake, which carries the worker's id, elapsed time, and last line.
#
#   bin/eindri-heartbeat.sh check <agent> [--window N]   # print the verdict
#   exit 0 = SILENT (suspect, wake Brokk) · 1 = fine/terminal/none
#
# Verdicts: silent | fresh | terminal | absent.
#   silent    launched, no append within the window, not terminal -> WAKE
#   fresh     launched and the status changed within the window     -> thinking
#   terminal  done/failed last line, or a report was already filed  -> done, no wake
#   absent    no launch record (never spawned, or the meta is gone)  -> no wake
#
# The window is configurable: EINDRI_SILENT_WINDOW (seconds, default 1800) or
# --window N. The when-adapter fires on the TRANSITION to silent, so a worker
# that keeps appending never fires, and one that stalls fires once.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
fi
hoard_state_dir YMIR_STATE_DIR
STATE="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
WINDOW="${EINDRI_SILENT_WINDOW:-1800}"

case "${1-}" in
  ""|-h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
MODE="${1:-check}"; shift || true

AGENT=
while [ $# -gt 0 ]; do
  case "$1" in
    --window) WINDOW="${2-}"; shift 2 ;;
    --window=*) WINDOW=${1#--window=}; shift ;;
    -*) printf 'error: unknown flag %s\nhelp: bin/eindri-heartbeat.sh check <agent> [--window N]\n' "$1" >&2; exit 2 ;;
    *) AGENT=$1; shift ;;
  esac
done
case "$WINDOW" in ''|*[!0-9]*) printf 'error: --window must be a number of seconds (got %s)\n' "$WINDOW" >&2; exit 2 ;; esac
[ -n "$AGENT" ] || { printf 'error: agent id required\nhelp: bin/eindri-heartbeat.sh check <agent> [--window N]\n' >&2; exit 2; }

META="$STATE/$AGENT.meta"
STATUS="$STATE/$AGENT.status"
NOW=$(date +%s)

stat_mtime() {  # <file> -> epoch
  if [ -f "$1" ]; then
    stat -c '%Y' "$1" 2>/dev/null && return 0
    stat -f '%m' "$1" 2>/dev/null && return 0
  fi
  return 1
}

verdict() { # <state> <elapsed> <line>
  printf 'eindri-heartbeat[1]{agent,verdict,elapsed_s,last_line}:\n  "%s","%s","%s","%s"\n' \
    "$AGENT" "$1" "${2:-0}" "${3:-}"
}

launched=$(grep '^launched=' "$META" 2>/dev/null | tail -1 | cut -d= -f2-)
case "$launched" in ''|*[!0-9]*) printf 'eindri-heartbeat[1]{agent,verdict}:\n  "%s","absent — no launch record in %s"\n' "$AGENT" "$META"; exit 1 ;; esac

# terminal by signal or by record
last=$(tail -n1 "$STATUS" 2>/dev/null || true)
case "$last" in
  done:*|failed:*)
    verdict terminal "$((NOW - launched))" "$last"; exit 1 ;;
esac
[ -f "$STATE/eindri-done/$AGENT.md" ] && { verdict terminal "$((NOW - launched))" "delivered marker at state/eindri-done/$AGENT.md"; exit 1; }
[ -f "$STATE/eindri-reports/$AGENT.md" ] && { verdict terminal "$((NOW - launched))" "report filed at state/eindri-reports/$AGENT.md"; exit 1; }

if lastmtime=$(stat_mtime "$STATUS"); then
  age=$((NOW - lastmtime)); [ "$age" -lt 0 ] && age=0
  if [ "$age" -le "$WINDOW" ]; then
    verdict fresh "$((NOW - launched))" "$last"
    exit 1
  fi
else
  # no status file at all: the baseline append failed or was never made —
  # silence from before the launch counts as suspicious the same way.
  age=$((NOW - launched))
  if [ "$age" -le "$WINDOW" ]; then
    verdict fresh "$age" "no status file yet"
    exit 1
  fi
fi

verdict silent "$((NOW - launched))" "$last"
exit 0