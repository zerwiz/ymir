#!/usr/bin/env bash
# wedge-notify.sh — the Ymir wedge-alarm notifier.
#
# The away-mode supervisor (bin/fm-supervise-daemon.sh) raises a loud, rate-
# limited alarm when an escalation cannot be delivered into the primary pane past
# FM_MAX_DEFER_SECS — the "wedge" case, where the pane itself is the thing that is
# broken and no digest can reach the Allfather. Its alarm routes through a
# notifier seam (`FM_WEDGE_ALARM_EXEC <channel> <summary>`) so a channel can reach
# him when every pane is unreadable.
#
# This is that notifier on an Omarchy host: an Omarchy desktop notification, and
# the same line appended to a durable file so a missed popup is still found.
#
# Usage (as the seam):  FM_WEDGE_ALARM_EXEC=bin/wedge-notify.sh
#   bin/wedge-notify.sh <channel> <summary>
# Exit: 0 fired (or discarded), 1 could not fire at all.
set -u

CHANNEL="${1:-unknown}"
SUMMARY="${2:-}"
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
STATE_DIR="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
LOG="$STATE_DIR/wedge-alarm.log"

# "discard" is the library-mode default so no test posts a real notification.
[ "$CHANNEL" = "discard" ] && exit 0
[ -n "$SUMMARY" ] || SUMMARY="an escalation could not reach the pane"

mkdir -p "$STATE_DIR" 2>/dev/null || true
printf '%s\twedge\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CHANNEL" "$SUMMARY" >>"$LOG" 2>/dev/null || true

fired=0
# Speak through the one voice: bin/ymir-say.sh owns the desktop manner.
if [ -x "$ROOT/bin/ymir-say.sh" ]; then
  "$ROOT/bin/ymir-say.sh" --mark-alarm "wedge: escalation stuck" "$SUMMARY" >/dev/null 2>&1 && fired=1
elif command -v omarchy-notification-send >/dev/null 2>&1; then
  omarchy-notification-send -u critical -g "" "Ymir wedge: escalation stuck" "$SUMMARY" >/dev/null 2>&1 && fired=1
elif command -v notify-send >/dev/null 2>&1; then
  notify-send -u critical "Ymir wedge: escalation stuck" "$SUMMARY" >/dev/null 2>&1 && fired=1
fi

# The durable line above already recorded it; a silent host is not a failure of
# the record, so exit 0 when the log was written even if no popup could show.
[ "$fired" = 1 ] && exit 0
[ -s "$LOG" ] && exit 0
exit 1
