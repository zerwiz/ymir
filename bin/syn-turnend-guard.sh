#!/usr/bin/env bash
# syn-turnend-guard.sh - refuse to let a Brokk turn end blind.
#
# Sýn guards the turn boundary: if supervision was armed and the watcher has
# since gone missing or unhealthy, this prints the recovery instruction and
# exits 2 so the harness extension can re-prompt instead of ending the turn.
# Inert until the first successful arm (state/.supervision-armed). Ported from
# the upstream agent-distro reference, retargeted for plan 29.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"
# The watcher writes BOTH its arm marker and its heartbeat into the OPERATOR's
# state, never the code tree (Rule 04). Resolve the same place here, or a live
# watcher is read as dead: the guard looked in $BROKK_HOME/state (the TREE), found
# a stale code-tree heartbeat, and fired "turn would end blind" every turn while
# the hoard heartbeat was seconds fresh (2026-09-23).
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
STALE_SECONDS="${BROKK_WATCH_HEARTBEAT_STALE_SECONDS:-60}"

# The hook contract passes {"stop_hook_active":false} on stdin; unused here.
cat >/dev/null 2>&1 || true

[ -f "$STATE/.supervision-armed" ] || exit 0

heartbeat="$STATE/.watch.heartbeat"
if [ -r "$heartbeat" ]; then
  beat=$(tr -d '[:space:]' <"$heartbeat")
  now=$(date -u +%s)
  case "$beat" in
    ''|*[!0-9]*) beat=0 ;;
  esac
  if [ "$((now - beat))" -le "$STALE_SECONDS" ]; then
    exit 0
  fi
fi

printf 'Brokk supervision is off: the watcher cycle is missing, failed, or unhealthy.\n' >&2
printf 'Recovery: re-arm through the harness extension (gna_watch_arm). Do not end the turn blind.\n' >&2
exit 2
