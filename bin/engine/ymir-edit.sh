#!/usr/bin/env bash
# ymir-edit.sh — open a file in the Allfather's editor, on its own desktop.
#
# Why a wrapper: an editor window that lands on the desktop you are working on
# steals the place you were reading. Ymir's law for its own windows is "own
# numbered desktop, preferring an empty one" (bin/desktop/desktop-place.sh), and the
# editor deserves the same treatment — open the file, then move that window off
# to a free desktop so the work you were doing stays where it was.
#
# This is the value Pi's Open Editor extension should resolve for $EDITOR:
#     export EDITOR="bin/engine/ymir-edit.sh"
# It accepts the same shape a normal editor does: `ymir-edit.sh <path>`.
#
# Usage:
#   bin/engine/ymir-edit.sh <path>          # open, then move to a free desktop
#   bin/engine/ymir-edit.sh --desktop <n> <path>
#   bin/engine/ymir-edit.sh --here <path>   # open on the current desktop (no move)
#   bin/engine/ymir-edit.sh --role reading <path>   # open on a DISPLAY, by role
#   bin/engine/ymir-edit.sh --role code --fullscreen <path>
#   bin/engine/ymir-edit.sh --new <path>    # force a second window for the same file
#   bin/engine/ymir-edit.sh --version
#
# Roles come from bin/desktop/display-lib.sh: `reading` is the largest screen,
# `code` / `primary` the focused one, and a monitor name passes through. The
# dispatcher dialect is PROBED (Hyprland 0.56 speaks Lua, earlier ones the classic
# strings) — the old comma-form move failed silently here, which is why windows did
# not land where they were asked to.
#
# Env:
#   YMIR_EDITOR          the real editor (default: code, else nvim, else vi)
#   YMIR_EDITOR_DESKTOP  'free' (default, an empty desktop) | 'here' | a number
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

. "$ROOT/bin/desktop/display-lib.sh" 2>/dev/null || true

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

MODE="${YMIR_EDITOR_DESKTOP:-free}"
ROLE="" NEW=0 FULL=0 DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --desktop) MODE=${2-}; shift 2 ;;
    --here)    MODE=here; shift ;;
    --role)    ROLE=${2:?--role needs a value}; shift 2 ;;
    --new)     NEW=1; shift ;;
    --fullscreen) FULL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    *) break ;;
  esac
done
TARGET="${1:-}"

have() { command -v "$1" >/dev/null 2>&1; }

# The real editor: an explicit override, else the first that exists. Never a
# bare 'vi' — a host may have only nvim (this machine does).
pick_editor() {
  if [ -n "${YMIR_EDITOR:-}" ]; then printf '%s' "$YMIR_EDITOR"; return 0; fi
  for e in code cursor zed subl nvim vim hx helix nano micro emacs; do
    have "$e" && { printf '%s' "$e"; return 0; }
  done
  printf 'vi'
}

# Is this editor a GUI one (safe to launch detached and move)?
is_gui() {
  case "$(basename "$1")" in
    code|code-insiders|codium|cursor|windsurf|subl|sublime_text|mate|atom|gedit|kate|zed|marktext|obsidian|typora|ghostwriter|logseq) return 0 ;;
  esac
  return 1
}

# An empty numbered desktop, preferring the lowest free one. Mirrors
# bin/desktop/desktop-place.sh's rule: on Omarchy the numbered desktops are the screens.
free_desktop() {
  command -v hyprctl >/dev/null 2>&1 || return 1
  hyprctl workspaces -j 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(0)
used={w.get("id") for w in d if w.get("windows",0)>0}
for n in range(1,11):
    if n not in used:
        print(n); break
' 2>/dev/null
}

[ -n "$TARGET" ] || { printf 'error: ymir-edit needs a path\nhelp: bin/engine/ymir-edit.sh <path>\n' >&2; exit 2; }

EDITOR_BIN="$(pick_editor)"
EDITOR_BASE="$(basename "$EDITOR_BIN")"
# The window class Hyprland reports — from the display library, one place knows it.
CLASS="$(editor_class "$EDITOR_BIN")"

if ! is_gui "$EDITOR_BIN"; then
  # A terminal editor cannot be moved to another desktop: it lives in this
  # terminal. Say so instead of pretending, and open it here.
  exec "$EDITOR_BIN" "$TARGET"
fi

if [ "$DRY" = 1 ]; then
  if [ -n "$ROLE" ]; then
    printf 'ymir-edit-plan[1]{editor,path,role,monitor,dialect}:\n  "%s","%s","%s","%s","%s"\n' \
      "$EDITOR_BASE" "$TARGET" "$ROLE" "$(display_name_for "$ROLE")" "$(display_dialect)"
  else
    printf 'ymir-edit-plan[1]{editor,path,desktop,dialect}:\n  "%s","%s","%s","%s"\n' \
      "$EDITOR_BASE" "$TARGET" "$MODE" "$(display_dialect)"
  fi
  exit 0
fi

# One window per file: focus the one already open unless --new was given.
BASE="$(basename "$TARGET")"
ESC="$(printf '%s' "$BASE" | sed 's/[][\.*^$/]/\\&/g')"
REUSED=0
ADDR=""
if [ "$NEW" = 0 ] && command -v "${YMIR_HYPRCTL:-hyprctl}" >/dev/null 2>&1; then
  ADDR="$(window_find "$CLASS" "$ESC")"
  [ -n "$ADDR" ] && REUSED=1
fi

if [ "$REUSED" = 0 ]; then
  # Launch detached — the GUI editor must not block the caller.
  "$EDITOR_BIN" "$TARGET" >/dev/null 2>&1 < /dev/null &
  disown 2>/dev/null || true
  # Give the window a moment to map.
  for _ in $(seq 1 40); do
    sleep 0.25
    ADDR="$(window_find "$CLASS" "$ESC")"
    [ -n "$ADDR" ] && break
  done
fi

# Where should it land? A ROLE names a display; otherwise a numbered desktop.
DEST=""
if [ -z "$ROLE" ]; then
  case "$MODE" in
    here) DEST="" ;;
    free) DEST="$(free_desktop)" ;;
    ''|*[!0-9]*) DEST="$(free_desktop)" ;;
    *) DEST="$MODE" ;;
  esac
fi

MON=""; PLACED="no"
if [ "$ROLE" != "" ]; then
  MON="$(display_name_for "$ROLE")"
  if [ -n "$ADDR" ] && [ -n "$MON" ]; then
    window_to_monitor "$ADDR" "$MON" && PLACED="yes"
    window_focus "$ADDR" || true
    [ "$FULL" = 1 ] && window_fullscreen "$ADDR" 1 || true
  fi
  printf 'ymir-edit[1]{editor,path,role,monitor,reused,placed}:\n  "%s","%s","%s","%s","%s","%s"\n' \
    "$EDITOR_BASE" "$TARGET" "$ROLE" "${MON:--}" "$REUSED" "$PLACED"
  exit 0
fi

if [ -z "$DEST" ]; then
  printf 'ymir-edit[1]{editor,path,desktop,reused}:\n  "%s","%s","current","%s"\n' "$EDITOR_BASE" "$TARGET" "$REUSED"
  exit 0
fi

[ -n "$ADDR" ] && window_to_desktop "$ADDR" "$DEST" >/dev/null 2>&1 && PLACED="yes"

printf 'ymir-edit[1]{editor,path,desktop,reused,moved}:\n  "%s","%s","%s","%s","%s"\n' \
  "$EDITOR_BASE" "$TARGET" "$DEST" "$REUSED" "$PLACED"
