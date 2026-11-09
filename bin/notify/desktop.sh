#!/usr/bin/env bash
# desktop.sh — THE desktop toast: one sender, one clickable target, and honesty about both.
#
# Plan 230. Before this, four subsystems each drew their own toast — `bin/gates/wedge-notify.sh`,
# `bin/host/crash-sense.sh`, `systems/snotra/services/cron/snotra-cron.sh` and the voice door —
# with three different behaviours and, in one of them, a click that did nothing at all. A toast
# that looks clickable and is not teaches him to stop clicking.
#
#   desktop.sh --title T [--body B] [--urgency low|normal|critical] [--glyph G] [--app A]
#              [--target <spec>] [--dry-run]
#
# With a target, the toast carries a default action ("Open") and a detached companion waits for
# the click and calls `bin/notify/open-target.sh` — so the click opens the digest, the plan, the
# PR or the Hlidskjalf route it is about. Without a target the title says `(no link)`, in his own
# words' spirit: he learns at a glance which few messages are dead ends instead of clicking.
#
# Exit: 0 handed to the desktop · 1 no notifier answered · 2 usage.
set -u
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TITLE=""; BODY=""; URGENCY="normal"; GLYPH=""; APP="Ymir"; TARGET=""; DRY=0; EXEC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --title|-t) TITLE="${2-}"; shift 2 ;;
    --body|-b) BODY="${2-}"; shift 2 ;;
    --urgency|-u) URGENCY="${2-normal}"; shift 2 ;;
    --glyph|-g) GLYPH="${2-}"; shift 2 ;;
    --app|-a) APP="${2-Ymir}"; shift 2 ;;
    --target) TARGET="${2-}"; shift 2 ;;
    --exec) EXEC="${2-}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -v|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    *) printf 'error: unknown argument %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$TITLE" ] || { printf 'error: --title is required\n' >&2; exit 2; }

RESOLVED=""; TARGET_STATE="none"
if [ -n "$TARGET" ]; then
  resolved="$(bash "$SCRIPT_DIR/open-target.sh" --check "$TARGET" 2>/dev/null | sed -n 's/^  "[^"]*","[^"]*","\([^"]*\)","[^"]*"$/\1/p' | head -1)"
  if [ -n "$resolved" ]; then
    RESOLVED="$resolved"; TARGET_STATE="resolved"
  else
    TARGET_STATE="missing"
    TITLE="$TITLE (target missing)"
  fi
else
  TITLE="$TITLE (no link)"
fi

if [ "$DRY" = 1 ]; then
  printf 'desktop[4]{title,urgency,target_state,resolved}:\n  "%s","%s","%s","%s"\n' \
    "$(printf '%s' "$TITLE" | sed 's/"/'"'"'/g')" "$URGENCY" "$TARGET_STATE" "$RESOLVED"
  exit 0
fi

have() { command -v "$1" >/dev/null 2>&1; }
fired=0; channel="none"

_send_plain() {  # no clickable target: Omarchy's own notifier first, then notify-send
  if have omarchy-notification-send; then
    if [ -n "$BODY" ]; then
      omarchy-notification-send -u "$URGENCY" ${GLYPH:+-g "$GLYPH"} "$TITLE" "$BODY" >/dev/null 2>&1 && { fired=1; channel="omarchy"; }
    else
      omarchy-notification-send -u "$URGENCY" ${GLYPH:+-g "$GLYPH"} "$TITLE" >/dev/null 2>&1 && { fired=1; channel="omarchy"; }
    fi
  fi
  if [ "$fired" = 0 ] && have notify-send; then
    if [ -n "$BODY" ]; then
      notify-send -a "$APP" -u "$URGENCY" "$TITLE" "$BODY" >/dev/null 2>&1 && { fired=1; channel="notify-send"; }
    else
      notify-send -a "$APP" -u "$URGENCY" "$TITLE" >/dev/null 2>&1 && { fired=1; channel="notify-send"; }
    fi
  fi
}

_send_clickable() {  # a real target: libnotify waits for the action, the companion opens it
  if have notify-send; then
    (
      choice="$(notify-send -a "$APP" -u "$URGENCY" --action=default=Open --wait "$TITLE" "${BODY:-$RESOLVED}" 2>/dev/null || true)"
      [ "$choice" = "default" ] && bash "$SCRIPT_DIR/open-target.sh" "$TARGET" >/dev/null 2>&1
    ) >/dev/null 2>&1 &
    fired=1; channel="notify-send(clickable)"
  else
    _send_plain
  fi
}

# An approval is a click that RUNS something (`--exec`); a notice is a click that OPENS
# something (`--target`). The first wins when both are given: the gesture must do the
# thing that was asked for.
if [ -n "$EXEC" ]; then
  if have omarchy-notification-send; then
    omarchy-notification-send -u "$URGENCY" ${GLYPH:+-g "$GLYPH"} "$TITLE" "${BODY:-$EXEC}" --exec "$EXEC" >/dev/null 2>&1 \
      && { fired=1; channel="omarchy(exec)"; }
  fi
  if [ "$fired" = 0 ] && have notify-send; then
    (
      choice="$(notify-send -a "$APP" -u "$URGENCY" --action=default=Continue --wait "$TITLE" "${BODY:-$EXEC}" 2>/dev/null || true)"
      [ "$choice" = "default" ] && bash -c "$EXEC" >/dev/null 2>&1
    ) >/dev/null 2>&1 &
    fired=1; channel="notify-send(exec)"
  fi
elif [ "$TARGET_STATE" = "resolved" ]; then _send_clickable
else _send_plain; fi

printf 'desktop[4]{state,channel,urgency,target}:\n  "%s","%s","%s","%s"\n' \
  "$([ "$fired" = 1 ] && echo dispatched || echo 'not delivered')" "$channel" "$URGENCY" \
  "$([ "$TARGET_STATE" = "resolved" ] && printf '%s' "$RESOLVED" || printf '%s' "$TARGET_STATE")"
[ "$fired" = 1 ] && exit 0
exit 1
