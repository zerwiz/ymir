#!/usr/bin/env bash
# display-lib.sh — the ONE place that knows the displays, and how to talk to the
# window manager about them.
#
# Source-safe: defines functions only. Nothing here opens anything.
#
# Why it exists (2026-10-18): placing a window on a named monitor was done by hand
# with `hyprctl dispatch movewindow mon:…`, which on Hyprland 0.56 (an Omarchy Lua
# config) fails with a Lua syntax error and looks like a broken window manager. The
# dialect is a platform fact, so it lives here — with a probe, not a guess — and
# every caller asks this file instead of remembering.
#
#   display_up                     -> 0 when a Hyprland instance answers
#   display_dialect                -> lua | classic | none
#   display_json                   -> `hyprctl monitors -j`
#   display_name_for <role>        -> the monitor name for a role (see below)
#   window_find <class> <title-re> -> the window address, empty when none
#   window_focus <address>         -> focus it
#   window_to_monitor <address> <monitor>
#   window_fullscreen <address>    -> only where the dialect offers it
#
# **Roles** are the operator's words for his screens, resolved: env → the recorded
# config → a documented default (Rule 07):
#
#   reading   the LARGEST monitor (area) — where a document is read
#   code      the focused monitor — where the work already is
#   primary   the focused monitor
#   <name>    a monitor name is passed through untouched (e.g. HDMI-A-1)
#
# The recorded config is a plain `role = monitor` file:
#   ~/.config/ymir/displays.conf      reading = HDMI-A-1
#                                     code    = eDP-1
# Omit it and the defaults above hold; never hardcode a port name in code.

YMIR_DISPLAYS_CONF="${YMIR_DISPLAYS_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/ymir/displays.conf}"
YMIR_HYPRCTL="${YMIR_HYPRCTL:-hyprctl}"

hypr() { "$YMIR_HYPRCTL" "$@" 2>/dev/null; }

display_up() {
  command -v "$YMIR_HYPRCTL" >/dev/null 2>&1 || return 1
  hypr monitors -j >/dev/null 2>&1
}

# The dispatcher dialect. PROBED, never guessed from a version: Hyprland's Lua
# builds answer `hyprctl eval`, classic builds do not know the command at all.
display_dialect() {
  display_up || { printf 'none'; return 0; }
  if hypr eval 'return 1' >/dev/null 2>&1; then printf 'lua'; else printf 'classic'; fi
}

display_json() { hypr monitors -j; }

# <role> -> monitor name. A name that matches a monitor passes through.
display_name_for() {
  local role="${1:-primary}" want="" name
  display_up || { printf '%s' ""; return 1; }
  # An explicit monitor name is authoritative — the operator said it himself.
  name="$(display_json | NAME="$role" python3 -c '
import json,os,sys
want=os.environ["NAME"]
try: ms=json.load(sys.stdin)
except Exception: sys.exit(0)
names=[m.get("name","") for m in ms if m.get("name")]
if want in names: print(want)
')"
  [ -n "$name" ] && { printf '%s' "$name"; return 0; }

  # The recorded choice, then the documented default.
  if [ -r "$YMIR_DISPLAYS_CONF" ]; then
    want="$(sed -nE "s/^[[:space:]]*${role}[[:space:]]*=[[:space:]]*\"?([^\"]+)\"?.*/\1/p" "$YMIR_DISPLAYS_CONF" | head -1)"
    if [ -n "$want" ] && [ "$want" != "largest" ] && [ "$want" != "focused" ]; then
      printf '%s' "$want"; return 0
    fi
  fi

  display_json | ROLE="$role" WANT="$want" python3 -c '
import json,os,sys
role=os.environ["ROLE"]; want=os.environ.get("WANT","")
ms=json.load(sys.stdin)
def area(m): return int(m.get("width",0))*int(m.get("height",0))
if role=="reading" or want=="largest":
    print(max(ms,key=area)["name"] if ms else "")
else:
    f=[m for m in ms if m.get("focused")]
    print((f or ms or [{"name":""}])[0].get("name",""))
'
}

# The window class Hyprland reports for an editor binary.
editor_class() {
  case "$(basename "${1:-}")" in
    marktext)  printf 'marktext' ;;
    zed)       printf 'dev\\.zed\\.Zed' ;;
    code|code-insiders|codium) printf 'code' ;;
    cursor)    printf 'cursor' ;;
    subl|sublime_text) printf 'sublime_text' ;;
    obsidian)  printf 'obsidian' ;;
    *)         printf '%s' "$(basename "${1:-}")" ;;
  esac
}

window_find() {  # <class-regex> <title-regex>
  local cls="${1:-}" title="${2:-}" out=""
  display_up || return 0
  out="$(display_json >/dev/null; hypr clients -j | CLS="$cls" TITLE="$title" python3 -c '
import json,os,sys,re
try: ws=json.load(sys.stdin)
except Exception: sys.exit(0)
cls=re.compile(os.environ.get("CLS") or ".")
title=re.compile(os.environ.get("TITLE") or ".", re.I)
hit=[w for w in ws if cls.search(w.get("class","")) and title.search(w.get("title",""))]
if hit: print(hit[0].get("address",""))
')"
  printf '%s' "$out"
}

window_focus() {  # <address>
  local a="${1:?}"
  case "$(display_dialect)" in
    lua)     hypr dispatch "hl.dsp.focus({ window = \"address:$a\" })" >/dev/null ;;
    classic) hypr dispatch focuswindow "address:$a" >/dev/null ;;
    *)       return 3 ;;
  esac
}

window_to_monitor() {  # <address> <monitor>
  local a="${1:?}" mon="${2:?}"
  [ -n "$mon" ] || return 2
  case "$(display_dialect)" in
    lua)
      hypr dispatch "hl.dsp.window.move({ window = \"address:$a\", monitor = \"$mon\" })" >/dev/null ;;
    classic)
      # Classic takes the monitor with the window already focused.
      hypr dispatch focuswindow "address:$a" >/dev/null
      hypr dispatch movewindow "mon:$mon" >/dev/null ;;
    *) return 3 ;;
  esac
}

window_fullscreen() {  # <address> [mode]
  local a="${1:?}" mode="${2:-1}"
  case "$(display_dialect)" in
    lua)     hypr dispatch "hl.dsp.window.fullscreen({ window = \"address:$a\", mode = $mode })" >/dev/null ;;
    classic) hypr dispatch focuswindow "address:$a" >/dev/null; hypr dispatch fullscreen "$mode" >/dev/null ;;
    *)       return 3 ;;
  esac
}

window_field() {  # <address> <json-field> — read one field back (monitor, workspace, size…)
  local a="${1:?}" f="${2:-monitor}"
  hypr clients -j | F="$f" A="$a" python3 -c '
import json,os,sys
try: ws=json.load(sys.stdin)
except Exception: sys.exit(0)
for w in ws:
    if str(w.get("address","")).lower()==os.environ["A"].lower():
        v=w.get(os.environ["F"],"")
        if isinstance(v,dict): v=v.get("id",v)
        print(v); break
'
}
