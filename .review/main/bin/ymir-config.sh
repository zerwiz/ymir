#!/usr/bin/env bash
# ymir-config.sh — the operator's own preferences, honoured and remembered.
#
# Some lines a script prints are information the first time and noise the tenth:
# the version that moved, the long-hour words, the hints. A user must be able to
# say "not again" — once — and be believed. That is what this door is for.
#
#   ymir-config.sh show                       # every preference and its state
#   ymir-config.sh notice <key> off|on        # silence or restore one notice
#   ymir-config.sh notice <key>               # what it is now
#
# The store is the operator's settings, in the home they chose — never the code
# tree (Rule 04) — one `key=on|off` line per name:
#
#   <home>/config/notices.conf
#
#   keys: version   the "the tree moved x → y" line
#         patience  the long-hour words before a slow install or build
#         next      the "where to go from here" block
#         hints     the one-line helpers ("hide this next time: …")
#
# Exit: 0 ok, 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/hoard-lib.sh
. "$SCRIPT_DIR/hoard-lib.sh"
hoard_settings_dir SETTINGS
STORE="$SETTINGS/notices.conf"
KNOWN="version patience next hints"

usage() { sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; }

state_of() {  # <key> → on|off (absent = on)
  local key="$1" line
  [ -r "$STORE" ] || { printf 'on'; return 0; }
  line="$(grep -m1 "^${key}=" "$STORE" 2>/dev/null || true)"
  [ -n "$line" ] && printf '%s' "${line#*=}" || printf 'on'
}

set_state() {  # <key> <on|off>
  local key="$1" value="$2" tmp
  case "$value" in on|off) ;; *) printf 'error: %s is not on or off\nhelp: ymir config notice %s off\n' "$value" "$key" >&2; exit 2 ;; esac
  mkdir -p "$SETTINGS" 2>/dev/null || { printf 'error: cannot write %s\n' "$SETTINGS" >&2; exit 1; }
  tmp="$(mktemp)"; chmod 600 "$tmp"
  if [ -r "$STORE" ]; then grep -v "^${key}=" "$STORE" >"$tmp" 2>/dev/null || true; fi
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv "$tmp" "$STORE"
}

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help|"") usage; exit 0 ;;
  show)
    printf 'notices[%d]{key,state,what}:\n' 4
    printf '  "version","%s","the line that says which version moved to which"\n' "$(state_of version)"
    printf '  "patience","%s","the long-hour words before a slow install or build"\n' "$(state_of patience)"
    printf '  "next","%s","the where-to-go-from-here block at the end"\n' "$(state_of next)"
    printf '  "hints","%s","the one-line helpers that say how to hide a notice"\n' "$(state_of hints)"
    printf 'store[1]{path}:\n  "%s"\n' "$STORE"
    ;;
  notice)
    key="${2-}"; value="${3-}"
    [ -n "$key" ] || { printf 'error: which notice?\nhelp: ymir config notice <version|patience|next|hints> off\n' >&2; exit 2; }
    case " $KNOWN " in *" $key "*) ;; *) printf 'error: unknown notice %s\nhelp: one of: %s\n' "$key" "$KNOWN" >&2; exit 2 ;; esac
    if [ -z "$value" ]; then
      printf 'notices[1]{key,state}:\n  "%s","%s"\n' "$key" "$(state_of "$key")"
    else
      set_state "$key" "$value"
      printf 'notices[1]{key,state}:\n  "%s","%s"\n' "$key" "$value"
      [ "$value" = off ] && printf 'this notice will not be shown again — restore it with: ymir config notice %s on\n' "$key"
    fi
    ;;
  *) printf 'error: unknown action %s\nhelp: bin/ymir-config.sh [show|notice <key> on|off]\n' "$1" >&2; exit 2 ;;
esac
