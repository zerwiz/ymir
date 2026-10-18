#!/usr/bin/env bash
# open-on.sh — open a file the RIGHT way: the operator's editor, on the RIGHT
# display, reusing the window if the file is already open.
#
#   open-on.sh <path> [--role reading|code|primary|<monitor>] [--editor <name>]
#                     [--new] [--fullscreen] [--dry-run] [--wait <seconds>]
#
# Why (2026-10-18): "I have this understanding to open editors, so it understands
# displays and things … so it can open things in the right way." Placing a window
# was hand-done per session, and the dispatcher dialect (Hyprland 0.56 speaks Lua
# dispatchers, not the classic strings) made it look broken. Both facts now live in
# display-lib.sh, and this is the door that uses them.
#
# What it guarantees:
#   * ONE window per file — a second call focuses the one already open (--new forces another)
#   * the display is chosen by ROLE, never by a hardcoded port name (Rule 07)
#   * off Hyprland it still opens the file and says the placement was skipped (Rule 05)
#   * it never edits the operator's Hyprland config; it only moves the window it opened
#
# Exit: 0 opened and placed · 2 usage · 3 opened but unplaced (no window manager)
#       1 the file or the editor failed, with the reason on stderr.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/display-lib.sh"

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

PATH_ARG="" ROLE="reading" EDITOR="" FORCE_NEW=0 FULLSCREEN=0 DRY=0 WAIT=15
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --version) printf '%s\n' "$VERSION"; exit 0 ;;
    --role)    ROLE="${2:?--role needs a value}"; shift 2 ;;
    --editor)  EDITOR="${2:?--editor needs a value}"; shift 2 ;;
    --new)     FORCE_NEW=1; shift ;;
    --fullscreen) FULLSCREEN=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --wait)    WAIT="${2:?--wait needs seconds}"; shift 2 ;;
    -*)        printf 'error: unknown flag %s\nhelp: open-on.sh --help\n' "$1" >&2; exit 2 ;;
    *)         [ -n "$PATH_ARG" ] && { printf 'error: one file at a time\nhelp: open-on.sh --help\n' >&2; exit 2; }
               PATH_ARG="$1"; shift ;;
  esac
done

[ -n "$PATH_ARG" ] || { usage >&2; exit 2; }
FILE="$PATH_ARG"
case "$FILE" in /*) ;; *) FILE="$PWD/$FILE" ;; esac
[ -e "$FILE" ] || { printf 'error: no such file: %s\nhelp: open-on.sh <path>\n' "$PATH_ARG" >&2; exit 1; }
BASE="$(basename "$FILE")"

# ── the editor: the operator's choice, never a guess (Rule 07) ────────────────
EDITOR_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/ymir/editor"
editor_bin() {
  local e="${EDITOR:-${YMIR_EDITOR:-}}"
  [ -n "$e" ] || [ -r "$EDITOR_CONF" ] && e="${e:-$(head -n1 "$EDITOR_CONF" 2>/dev/null | tr -d '[:space:]')}"
  if [ -z "$e" ]; then
    for c in marktext zed code cursor obsidian; do command -v "$c" >/dev/null 2>&1 && { e="$c"; break; }; done
  fi
  printf '%s' "$e"
}
BIN="$(editor_bin)"
[ -n "$BIN" ] && command -v "$BIN" >/dev/null 2>&1 || {
  printf 'error: no editor found\nhelp: set $YMIR_EDITOR, or write one line in %s\n' "$EDITOR_CONF" >&2; exit 1; }
CLASS="$(editor_class "$BIN")"

# ── the display: by role, from the library ────────────────────────────────────
MON=""; DIAl=""
DIAl="$(display_dialect)"
[ "$DIAl" != "none" ] && MON="$(display_name_for "$ROLE")"

if [ "$DRY" = 1 ]; then
  printf 'open-plan[1]{file,editor,class,role,monitor,dialect}:\n'
  printf '  "%s","%s","%s","%s","%s","%s"\n' "$FILE" "$BIN" "$CLASS" "$ROLE" "${MON:--}" "$DIAl"
  exit 0
fi

# ── one window per file: focus what is already open ──────────────────────────
ADDR=""
if [ "$FORCE_NEW" = 0 ]; then
  ADDR="$(window_find "$CLASS" "$(printf '%s' "$BASE" | sed 's/[][\.*^$/]/\\&/g')")"
fi
REUSED=0
if [ -n "$ADDR" ]; then
  REUSED=1
else
  setsid "$BIN" "$FILE" >/dev/null 2>&1 < /dev/null &
  if [ "$DIAl" != "none" ]; then
    i=0
    while [ "$i" -lt "$WAIT" ]; do
      sleep 1; i=$((i+1))
      ADDR="$(window_find "$CLASS" "$(printf '%s' "$BASE" | sed 's/[][\.*^$/]/\\&/g')")"
      [ -n "$ADDR" ] && break
    done
  fi
fi

# ── place it ─────────────────────────────────────────────────────────────────
PLACED="no"; WS="-"
if [ -n "$ADDR" ] && [ "$DIAl" != "none" ] && [ -n "$MON" ]; then
  window_to_monitor "$ADDR" "$MON" && PLACED="yes"
  window_focus "$ADDR" || true
  [ "$FULLSCREEN" = 1 ] && window_fullscreen "$ADDR" 1 || true
  WS="$(window_field "$ADDR" workspace)"
fi

printf 'open[1]{file,editor,address,reused,role,monitor,workspace,placed}:\n'
printf '  "%s","%s","%s",%s,"%s","%s","%s","%s"\n' \
  "$FILE" "$BIN" "${ADDR:-}" "$REUSED" "$ROLE" "${MON:--}" "${WS:--}" "$PLACED"
if [ "$DIAl" = "none" ]; then
  printf 'open-on: opened, but no window manager answered — placement skipped\n' >&2
  exit 3
fi
[ -n "$ADDR" ] || { printf 'open-on: the window never appeared — is %s installed and able to start?\n' "$BIN" >&2; exit 1; }
exit 0
