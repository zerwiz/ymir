#!/usr/bin/env bash
# syn-watch-arm.sh - arm one Brokk supervision watcher cycle.
#
# Sýn ("the one who sees") watches the runtime state and exits with an
# actionable `signal:`/`stale:`/`check:`/`heartbeat:` line when something needs
# the primary. The Pi extension (gna-pi-watch.ts) owns continuity and re-arms.
# Ported/trimmed from the upstream agent-distro reference for plan 29
# (docs/plans/29-brokk-distro-runtime.md).
#
# Usage: syn-watch-arm.sh --restart
#        syn-watch-arm.sh --handling-delivered <generation> --watcher-pid <pid>
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"
# shellcheck source=bin/gleipnir-lock-lib.sh
. "$SCRIPT_DIR/gleipnir-lock-lib.sh"

POLL_SECONDS="${BROKK_WATCH_POLL_SECONDS:-5}"
HEARTBEAT_STALE_SECONDS="${BROKK_WATCH_HEARTBEAT_STALE_SECONDS:-60}"

mkdir -p "$STATE"

if [ "${1-}" = "--handling-delivered" ]; then
  generation=${2-}
  watcher_pid=${4-}
  printf 'watcher: handling delivered generation=%s watcher-pid=%s\n' "$generation" "$watcher_pid"
  exit 0
fi

lock_owner=$(gleipnir_lock_owner _lo 2>/dev/null; printf '%s' "${_lo:-}")
if [ -z "$lock_owner" ] || ! gleipnir_pid_alive "$lock_owner"; then
  printf 'watcher: read-only - no live session holds the lock\n' >&2
  exit 0
fi

GENERATION="${BROKK_WATCH_PREDECESSOR_ARM_PID:-arm}-$$"
printf 'watcher: started pid=%s recovery-generation=%s\n' "$$" "$GENERATION"
: >"$STATE/.supervision-armed"

touch_heartbeat() { date -u +%s >"$STATE/.watch.heartbeat"; }

actionable() {
  # A non-empty wake queue or an actionable status append ends the cycle.
  if [ -s "$STATE/.wake-queue" ]; then
    printf 'signal: wake queue\n'
    return 0
  fi
  local sig
  sig=$(find "$STATE" -maxdepth 1 -name '*.signal' -print -quit 2>/dev/null || true)
  if [ -n "$sig" ]; then
    rm -f "$sig"
    printf 'signal: %s\n' "$(basename "$sig" .signal)"
    return 0
  fi
  local check
  check=$(find "$STATE" -maxdepth 1 -name '*.check' -print -quit 2>/dev/null || true)
  if [ -n "$check" ]; then
    rm -f "$check"
    printf 'check: %s\n' "$(basename "$check" .check)"
    return 0
  fi
  if [ -f "$STATE/.watcher-stop" ]; then
    rm -f "$STATE/.watcher-stop"
    printf 'stale: watcher stopped by operator\n'
    return 0
  fi
  return 1
}

touch_heartbeat
while :; do
  if actionable; then
    exit 0
  fi
  sleep "$POLL_SECONDS"
  touch_heartbeat
done
