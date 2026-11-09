#!/usr/bin/env bash
# ymir-say.sh — let Ymir speak on the Allfather's desktop.
#
# Ymir works for hours without him watching. When something is worth knowing — a
# job done, a crash seen, an alarm that could not be delivered, a task needing a
# word — it should reach him where he already is: an Omarchy desktop
# notification, with a durable line on disk so a missed popup is still found.
#
# This is the single owner of "Ymir speaks on the desktop". Anything with news
# calls it, so the manner (glyph, urgency, app identity) cannot drift.
#
# Usage:
#   systems/snotra/services/tts-lease/ymir-say.sh <headline> [body] [--urgency low|normal|critical] [--glyph G]
#   systems/snotra/services/tts-lease/ymir-say.sh --mark-done "<what>"     # a job finished
#   systems/snotra/services/tts-lease/ymir-say.sh --mark-alarm "<what>"    # something needs him soon
#   systems/snotra/services/tts-lease/ymir-say.sh --mark-fail "<what>"     # something went wrong
#   systems/snotra/services/tts-lease/ymir-say.sh status                   # what has been said, and where it went
#   systems/snotra/services/tts-lease/ymir-say.sh --version
#
# The desktop notifier is the house's notify door when present (`bin/notify/open-target.sh`,
# which also owns the click, plan 230), and with neither, the line is still recorded — a silent
# host is not a lost message. Nothing here calls the notifier itself: one door owns the toast.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The roots that live OUTSIDE the code tree: this machine's records and the
# runtime state belong to the home the operator chose at installation, never in
# the tree — a packaged install replaces its tree on upgrade (Rule 04).
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  _yr="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  for _yc in "$_yr/hoard-lib.sh" "$_yr/../vault/hoard-lib.sh" "$_yr/../../vault/hoard-lib.sh"; do
    [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yr _yc
fi
hoard_state_dir YMIR_STATE_DIR
hoard_data_dir YMIR_DATA_DIR
STATE_DIR="${BROKK_STATE_OVERRIDE:-$YMIR_STATE_DIR}"
LOG="$STATE_DIR/ymir-said.log"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  status)
    if [ -r "$LOG" ]; then
      printf 'ymir-say[%d]{when,mark,who,what}:\n' "$(grep -c . "$LOG" 2>/dev/null || echo 0)"
      tail -8 "$LOG" | while IFS=$'\t' read -r when mark who what; do
        printf '  "%s","%s","%s","%s"\n' "$when" "$mark" "$who" "$what"
      done
    else
      printf 'ymir-say[1]{state}:\n  "nothing said yet"\n'
    fi
    exit 0 ;;
esac

URGENCY="normal"
GLYPH=""
MARK="note"
TARGET=""
EXEC_CMDS=()
case "${1-}" in
  --mark-done)  MARK="done";  URGENCY="low";      GLYPH="✓"; set -- "${2:-A job finished}" "${3:-}" ;;
  --mark-alarm) MARK="alarm"; URGENCY="critical"; GLYPH="!"; set -- "${2:-Needs your word}" "${3:-}" ;;
  --mark-fail)  MARK="fail";  URGENCY="critical"; GLYPH="✗"; set -- "${2:-Something went wrong}" "${3:-}" ;;
esac

# ONE parser for the flags, wherever they sit: a call like `<message> --exec <cmd>` used to lose
# the click entirely (the flag was eaten before EXEC_ARGS looked at it), which is how an approval
# toast became a toast that could not approve anything (measured 2026-11-09, plan 230/231).
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --urgency) URGENCY=${2:-normal}; shift 2 ;;
    --glyph)   GLYPH=${2:-}; shift 2 ;;
    --mark)    MARK=${2:-note}; shift 2 ;;
    --target)  TARGET=${2:-}; shift 2 ;;
    --exec)    EXEC_CMDS+=("${2:-}"); shift 2 ;;
    *)         POS+=("$1"); shift ;;
  esac
done
HEADLINE="${POS[0]:-}"
BODY="${POS[1]:-}"

[ -n "$HEADLINE" ] || { printf 'error: ymir-say needs a headline\nhelp: systems/snotra/services/tts-lease/ymir-say.sh "<headline>" ["<body>"]\n' >&2; exit 2; }

WHO="${YMIR_SAY_WHO:-Ymir}"
[ -n "$GLYPH" ] || GLYPH="•"

mkdir -p "$STATE_DIR" 2>/dev/null || true
printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$MARK" "$HEADLINE" "$BODY" >>"$LOG" 2>/dev/null || true

TITLE="$GLYPH $WHO — $HEADLINE"
fired=0
# A click can run a command (`--exec`), which is how an approval becomes one gesture.
EXEC_ARGS=()
for _c in "${EXEC_CMDS[@]:-}"; do [ -n "$_c" ] && EXEC_ARGS+=(--exec "$_c"); done

# ONE door shows the toast and owns the click (plan 230). A message with no target says `(no
# link)` in its title, which is the whole point: he learns at a glance which few are dead ends.
NOTIFY_DOOR="$ROOT/bin/notify/open-target.sh"
if [ -x "$NOTIFY_DOOR" ]; then
  args=(toast --app "$WHO" --glyph "$GLYPH" --urgency "$URGENCY" --title "$TITLE")
  [ -n "$BODY" ] && args+=(--body "$BODY")
  [ -n "$TARGET" ] && args+=(--target "$TARGET")
  [ ${#EXEC_ARGS[@]} -gt 0 ] && args+=("${EXEC_ARGS[@]}")
  "$NOTIFY_DOOR" "${args[@]}" >/dev/null 2>&1 && fired=1
fi

# The durable line was written either way; only report the channel's fate.
if [ "$fired" = 1 ]; then
  printf 'ymir-say[1]{mark,urgency,channel}:\n  "%s","%s","desktop"\n' "$MARK" "$URGENCY"
  exit 0
fi
printf 'ymir-say[1]{mark,urgency,channel}:\n  "%s","%s","record only (no notify door or no desktop notifier)"\n' "$MARK" "$URGENCY"
exit 0
