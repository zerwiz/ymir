#!/usr/bin/env bash
# syn-watch-arm.sh - arm one Brokk supervision watcher cycle.
#
# Sýn ("the one who sees") watches the runtime state and exits with an
# actionable `signal:`/`stale:`/`check:`/`heartbeat:` line when something needs
# the primary. The Pi extension (gna-pi-watch.ts) owns continuity and re-arms.
# Ported/trimmed from the upstream agent-distro reference for plan 29
# (memory/plans/core/29-brokk-distro-runtime.md).
#
# Usage: syn-watch-arm.sh --restart
#        syn-watch-arm.sh --handling-delivered <generation> --watcher-pid <pid>
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
# The wake queue is written by the Eindri handoff (bin/eindri-acclaim.sh) into the
# OPERATOR'S HOME state ($YMIR_STATE_DIR), resolved through bin/hoard-lib.sh. The
# watcher must read the SAME queue: it once defaulted to $BROKK_HOME/state — the
# CODE TREE — so the handoff filled one queue and the watcher watched another, and
# no wake ever surfaced (2026-09-23). Same order of authority as the lib.
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
  # The helm is vacant: no owner, or an owner verifiably gone (dead, zombie,
  # recycled, or a truncated/empty lock). Enter through the lib's acquire,
  # which refuses only a genuinely live other session — so a vacant helm is
  # taken here, never punted to a manual session start.
  if ! gleipnir_lock_acquire; then
    printf 'watcher: read-only - the session helm is held by another live session\n' >&2
    exit 0
  fi
  lock_owner=$(gleipnir_lock_owner _lo 2>/dev/null; printf '%s' "${_lo:-}")
fi

GENERATION="${BROKK_WATCH_PREDECESSOR_ARM_PID:-arm}-$$"
printf 'watcher: started pid=%s recovery-generation=%s\n' "$$" "$GENERATION"
: >"$STATE/.supervision-armed"

touch_heartbeat() { date -u +%s >"$STATE/.watch.heartbeat"; }

actionable() {
  # A non-empty wake queue or an actionable status append ends the cycle.
  if [ -s "$STATE/.wake-queue" ]; then
    # ONE signal per DISTINCT queue content (the 2026-09-22 flood brake): an
    # unconsumed queue must never re-inject on every poll. A new wake (changed
    # content) raises exactly one new signal; an unchanged queue stays silent
    # until the agent drains it (saga-wake-drain.sh) or the content changes.
    local _h _prev
    _h="$(md5sum < "$STATE/.wake-queue" | awk '{print $1}')"
    _prev="$(cat "$STATE/.wake-last-hash" 2>/dev/null || true)"
    if [ "$_prev" != "$_h" ]; then
      printf '%s' "$_h" > "$STATE/.wake-last-hash"
      printf 'signal: wake queue\n'
    fi
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
  # The lock is a live-session contract, not an arm-time snapshot. If the
  # harness that held this home's lock has exited — or a replacement never took
  # it — this watcher is an orphan and must retire rather than beat forever for
  # a dead session (which would also strand `state/.supervision-armed` with a
  # fresh-enough heartbeat and silence the turn-end guard). Retiring is not
  # actionable: it prints no `signal:`/`stale:`/`check:` line, so it never wakes
  # a session.
  lock_owner=$(gleipnir_lock_owner _lo 2>/dev/null; printf '%s' "${_lo:-}")
  if [ -z "$lock_owner" ] || ! gleipnir_pid_alive "$lock_owner"; then
    printf 'watcher: retired - session lock is no longer held\n' >&2
    exit 0
  fi

  # THE MID-SESSION SWEEP. The Eindri handoff failsafe (bin/eindri-handoff.sh)
  # turns a filed report/question into a wake. It used to run only at SESSION
  # START, so a report filed while the session ran sat invisible until the next
  # session — a worker finished and Brokk was never told. Run it every cycle
  # instead: the queue is filled within seconds and the check below sees it.
  if [ -x "$SCRIPT_DIR/eindri-handoff.sh" ]; then
    BROKK_STATE_OVERRIDE="$STATE" "$SCRIPT_DIR/eindri-handoff.sh" sweep >/dev/null 2>&1 || true
  fi
  if actionable; then
    exit 0
  fi
  sleep "$POLL_SECONDS"
  touch_heartbeat
done
