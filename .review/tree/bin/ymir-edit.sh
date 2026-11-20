#!/usr/bin/env bash
# ymir-edit.sh — open a file in the Allfather's editor, on its own desktop.
#
# Why a wrapper: an editor window that lands on the desktop you are working on
# steals the place you were reading. Ymir's law for its own windows is "own
# numbered desktop, preferring an empty one" (bin/desktop-place.sh), and the
# editor deserves the same treatment — open the file, then move that window off
# to a free desktop so the work you were doing stays where it was.
#
# This is the value Pi's Open Editor extension should resolve for $EDITOR:
#     export EDITOR="bin/ymir-edit.sh"
# It accepts the same shape a normal editor does: `ymir-edit.sh <path>`.
#
# Usage:
#   bin/ymir-edit.sh <path>          # open, then move to a free desktop
#   bin/ymir-edit.sh --desktop <n> <path>
#   bin/ymir-edit.sh --here <path>   # open on the current desktop (no move)
#   bin/ymir-edit.sh --version
#
# Env:
#   YMIR_EDITOR          the real editor (default: code, else nvim, else vi)
#   YMIR_EDITOR_DESKTOP  'free' (default, an empty desktop) | 'here' | a number
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

MODE="${YMIR_EDITOR_DESKTOP:-free}"
case "${1-}" in
  --desktop) MODE=${2-}; shift 2 ;;
  --here) MODE=here; shift ;;
esac
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
    code|code-insiders|codium|cursor|windsurf|subl|sublime_text|mate|atom|gedit|kate|zed) return 0 ;;
  esac
  return 1
}

# An empty numbered desktop, preferring the lowest free one. Mirrors
# bin/desktop-place.sh's rule: on Omarchy the numbered desktops are the screens.
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

move_window_to() {  # <desktop> <class-regex>
  local d=$1 cls=$2
  command -v hyprctl >/dev/null 2>&1 || return 1
  # Hyprland 0.56 here wraps dispatch in Lua, so the comma form can fail; try
  # both the classic and the keyword form, and report honestly if neither lands.
  hyprctl dispatch movetoworkspacesilent "$d,class:$cls" >/dev/null 2>&1 && return 0
  hyprctl keyword windowrulev2 "workspace $d silent,class:$cls" >/dev/null 2>&1 || true
  return 0
}

[ -n "$TARGET" ] || { printf 'error: ymir-edit needs a path\nhelp: bin/ymir-edit.sh <path>\n' >&2; exit 2; }

EDITOR_BIN="$(pick_editor)"
EDITOR_BASE="$(basename "$EDITOR_BIN")"

if ! is_gui "$EDITOR_BIN"; then
  # A terminal editor cannot be moved to another desktop: it lives in this
  # terminal. Say so instead of pretending, and open it here.
  exec "$EDITOR_BIN" "$TARGET"
fi

# Where should it land?
DEST=""
case "$MODE" in
  here) DEST="" ;;
  free) DEST="$(free_desktop)" ;;
  ''|*[!0-9]*) DEST="$(free_desktop)" ;;
  *) DEST="$MODE" ;;
esac

# Launch detached — the GUI editor must not block the caller.
"$EDITOR_BIN" "$TARGET" >/dev/null 2>&1 < /dev/null &
disown 2>/dev/null || true

if [ -z "$DEST" ]; then
  printf 'ymir-edit[1]{editor,path,desktop}:\n  "%s","%s","current"\n' "$EDITOR_BASE" "$TARGET"
  exit 0
fi

# Give the window a moment to map, then move it to its own desktop. The class
# for VS Code is `code`; for others use the binary's own name.
case "$EDITOR_BASE" in
  code|code-insiders|codium) CLASS="code" ;;
  cursor) CLASS="cursor" ;;
  zed) CLASS="dev.zed.Zed" ;;
  subl|sublime_text) CLASS="sublime_text" ;;
  *) CLASS="$EDITOR_BASE" ;;
esac

moved=no
for _ in $(seq 1 20); do
  sleep 0.25
  if hyprctl clients -j 2>/dev/null | python3 -c '
import json,sys
cls=sys.argv[1]
try:
    cs=json.load(sys.stdin)
except Exception:
    sys.exit(1)
sys.exit(0 if any(cls.lower() in (c.get("class") or "").lower() for c in cs) else 1)
' "$CLASS" 2>/dev/null; then
    move_window_to "$DEST" "^($CLASS)\$" && moved=yes
    break
  fi
done

printf 'ymir-edit[1]{editor,path,desktop,moved}:\n  "%s","%s","%s","%s"\n' \
  "$EDITOR_BASE" "$TARGET" "$DEST" "$moved"
