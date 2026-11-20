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
# Added 2026-11-20 (plan 341, one Hyprland door — `bin/desktop/hypr.sh` is the command-line face of
# this file, and no other file in bin/ may call `hyprctl dispatch`; bin/gates/guards/hypr-door-guard.sh
# keeps it so):
#
#   display_version                -> "0.56.2" (empty when none answers)
#   windows_json                   -> `hyprctl clients -j`, each window given an "agent" field
#   window_active                  -> the focused window's address
#   window_resolve <query> [kind]  -> one address; exit 4 and the candidates on stderr otherwise
#   workspaces_json · workspace_active · workspace_free [max] · workspace_go <n>
#   config_errors                  -> one line per Hyprland config error (empty = clean)
#   config_reload                  -> ask Hyprland to reload (no verdict — config_errors is the verdict)
#   option_set <a:b:c> <value>     -> `eval hl.config(...)` on Lua, `keyword` on classic
#   display_notify <ms> <text>     -> an on-screen notice
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

# An ACT (dispatch, eval, keyword, reload): Hyprland answers a refused act with exit 0 and the
# reason as text — "error: [string …]: ')' expected", "keyword can't work with non-legacy parsers",
# "unknown request" — so the answer is read, not only the exit code. 0 taken · 1 refused (the
# reason on stderr, prefixed `hyprland:`).
hypr_act() {
  local out rc
  out="$("$YMIR_HYPRCTL" "$@" 2>&1)"; rc=$?
  case "$out" in
    *[Ee]rror*|*[Ii]nvalid*|*[Uu]nknown*|*"can't"*|*expected*|*"not found"*|*[Nn]o\ such*) rc=1 ;;
  esac
  [ "$rc" = 0 ] || printf 'hyprland: %s\n' "$(printf '%s' "$out" | head -2 | tr '\n' ' ')" >&2
  return "$rc"
}

display_up() {
  command -v "$YMIR_HYPRCTL" >/dev/null 2>&1 || return 1
  hypr monitors -j >/dev/null 2>&1
}

# The dispatcher dialect. PROBED, never guessed from a version: Hyprland's Lua
# builds answer `hyprctl eval`, classic builds do not know the command at all.
display_dialect() {
  display_up || { printf 'none'; return 0; }
  # A classic build may answer an unknown request with exit 0 and the words "unknown request",
  # so the answer is read as well as the exit code (plan 341.1).
  local out
  if out="$("$YMIR_HYPRCTL" eval 'return 1' 2>&1)"; then
    case "$out" in *[Uu]nknown*|*[Ii]nvalid*) printf 'classic' ;; *) printf 'lua' ;; esac
  else
    printf 'classic'
  fi
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
    lua)     hypr_act dispatch "hl.dsp.focus({ window = \"address:$a\" })" >/dev/null ;;
    classic) hypr_act dispatch focuswindow "address:$a" >/dev/null ;;
    *)       return 3 ;;
  esac
}

window_to_monitor() {  # <address> <monitor>
  local a="${1:?}" mon="${2:?}"
  [ -n "$mon" ] || return 2
  case "$(display_dialect)" in
    lua)
      hypr_act dispatch "hl.dsp.window.move({ window = \"address:$a\", monitor = \"$mon\" })" >/dev/null ;;
    classic)
      # Classic takes the monitor with the window already focused.
      hypr_act dispatch focuswindow "address:$a" >/dev/null
      hypr_act dispatch movewindow "mon:$mon" >/dev/null ;;
    *) return 3 ;;
  esac
}

window_fullscreen() {  # <address> [mode]
  local a="${1:?}" mode="${2:-1}"
  case "$(display_dialect)" in
    lua)     hypr_act dispatch "hl.dsp.window.fullscreen({ window = \"address:$a\", mode = $mode })" >/dev/null ;;
    classic) hypr_act dispatch focuswindow "address:$a" >/dev/null; hypr_act dispatch fullscreen "$mode" >/dev/null ;;
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

# Move a window to a numbered desktop (workspace) — the other placement axis.
# Hyprland 0.56 rejects the classic `movetoworkspacesilent <n>,class:x` string for
# this too, so the Lua form is the one to reach for when it is available.
window_to_desktop() {  # <address> <n>
  local a="${1:?}" n="${2:?}"
  case "$(display_dialect)" in
    lua)     hypr_act dispatch "hl.dsp.window.move({ window = \"address:$a\", workspace = \"$n\", follow = false })" >/dev/null ;;
    classic) hypr_act dispatch movetoworkspacesilent "$n,address:$a" >/dev/null ;;
    *)       return 3 ;;
  esac
}

# ── plan 341 · one Hyprland door (2026-11-20) ────────────────────────────────────────────────────────
# Everything below is read by bin/desktop/hypr.sh. The dialect stays in THIS file: a caller never
# writes a dispatcher string, a `keyword`, or an `eval` of its own.

display_version() {
  display_up || return 0
  hypr version -j | python3 -c '
import json,sys
try: print(json.load(sys.stdin).get("version",""))
except Exception: pass
' 2>/dev/null
}

# The windows, each with the agent running inside it when one is (claude, pi, opencode, codex,
# hermes, …) — found by walking the window process's children in /proc, so a terminal that hosts an
# agent is named for what it hosts. YMIR_HYPR_PROC points the walk at a test tree.
windows_json() {
  display_up || return 0
  hypr clients -j | PROC="${YMIR_HYPR_PROC:-/proc}" python3 -c '
import json,os,sys
try: ws=json.load(sys.stdin)
except Exception: sys.exit(0)
proc=os.environ.get("PROC","/proc")
AGENTS=("claude","pi","opencode","codex","hermes","cursor-agent","aider","gemini","omp")
kids={}; names={}
try:
    for d in os.listdir(proc):
        if not d.isdigit(): continue
        try:
            st=open(os.path.join(proc,d,"stat")).read()
            name=st[st.index("(")+1:st.rindex(")")]
            ppid=int(st[st.rindex(")")+2:].split()[1])
        except Exception: continue
        names[int(d)]=name; kids.setdefault(ppid,[]).append(int(d))
except Exception: pass
def agent(pid):
    seen=set(); todo=list(kids.get(pid,[]))
    while todo:
        p=todo.pop(0)
        if p in seen: continue
        seen.add(p)
        n=names.get(p,"")
        if n in AGENTS: return n
        todo.extend(kids.get(p,[]))
    return ""
for w in ws:
    w["agent"]=agent(int(w.get("pid") or 0)) if w.get("pid") else ""
print(json.dumps(ws))
'
}

window_active() {
  display_up || return 0
  hypr activewindow -j | python3 -c '
import json,sys
try: print(json.load(sys.stdin).get("address",""))
except Exception: pass
' 2>/dev/null
}

# <query> [kind] -> exactly one address. kind: auto (default) | address | pid | class | title.
# auto: 0x… is an address, digits are a pid, then an exact class, a class regex, a title regex.
# None -> exit 4 · several -> exit 4 with the candidates (address, class, title) on stderr, unless
# YMIR_HYPR_FIRST=1 asks for the first (the old window_find behaviour).
window_resolve() {
  local q="${1:-}" kind="${2:-auto}"
  [ -n "$q" ] || return 2
  display_up || return 3
  windows_json | Q="$q" KIND="$kind" FIRST="${YMIR_HYPR_FIRST:-0}" python3 -c '
import json,os,re,sys
q=os.environ["Q"]; kind=os.environ["KIND"]; first=os.environ["FIRST"]=="1"
try: ws=json.load(sys.stdin)
except Exception: ws=[]
ws=[w for w in ws if w.get("mapped",True)]
def rx(p,flags=0):
    try: return re.compile(p,flags)
    except re.error: return re.compile(re.escape(p),flags)
def pick(k):
    if k=="address": return [w for w in ws if str(w.get("address","")).lower()==q.lower()]
    if k=="pid":     return [w for w in ws if str(w.get("pid",""))==q]
    if k=="class":
        ex=[w for w in ws if w.get("class","")==q]
        return ex or [w for w in ws if rx(q).search(w.get("class",""))]
    if k=="title":   return [w for w in ws if rx(q,re.I).search(w.get("title",""))]
    return []
if kind=="auto":
    if re.fullmatch(r"0x[0-9a-fA-F]+",q): order=["address"]
    elif q.isdigit(): order=["pid"]
    else: order=["class","title"]
else: order=[kind]
hit=[]
for k in order:
    hit=pick(k)
    if hit: break
if not hit:
    sys.stderr.write("no window matches %r\n" % q); sys.exit(4)
if len(hit)>1 and not first:
    sys.stderr.write("%d windows match %r — name one:\n" % (len(hit),q))
    for w in hit:
        sys.stderr.write("  %s  %s  %s\n" % (w.get("address",""),w.get("class",""),(w.get("title","") or "")[:60]))
    sys.exit(4)
print(hit[0].get("address",""))
'
}

workspaces_json() { display_up || return 0; hypr workspaces -j; }

workspace_active() {
  display_up || return 0
  hypr activeworkspace -j | python3 -c '
import json,sys
try: n=json.load(sys.stdin).get("id",0)
except Exception: n=0
print(n if isinstance(n,int) and n>0 else "")
' 2>/dev/null
}

# The lowest numbered desktop holding no window (1..max, default 10).
workspace_free() {
  local max="${1:-10}"
  display_up || return 1
  workspaces_json | MAX="$max" python3 -c '
import json,os,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
used={w.get("id") for w in d if w.get("windows",0)>0}
for n in range(1,int(os.environ["MAX"])+1):
    if n not in used:
        print(n); break
' 2>/dev/null
}

workspace_go() {  # <n|name>
  local n="${1:?}"
  case "$(display_dialect)" in
    lua)     hypr_act dispatch "hl.dsp.focus({ workspace = \"$n\" })" >/dev/null ;;
    classic) hypr_act dispatch workspace "$n" >/dev/null ;;
    *)       return 3 ;;
  esac
}

# One line per error. `hyprctl configerrors` answers a clean config with an empty line (and
# `-j` with [""]), so blank lines are not errors.
config_errors() {
  display_up || return 0
  hypr configerrors | sed '/^[[:space:]]*$/d'
}

config_reload() { display_up || return 3; hypr_act reload >/dev/null; }

# <section:key[:key…]> <value>. Lua: hl.config({ section = { key = value } }) through eval.
# Classic: keyword section:key value. A value that is a number or true/false is passed bare;
# anything else is a quoted Lua string.
option_set() {
  local opt="${1:?}" val="${2-}" expr
  case "$(display_dialect)" in
    lua)
      expr="$(OPT="$opt" VAL="$val" python3 -c '
import os,re
opt=os.environ["OPT"].split(":"); v=os.environ["VAL"]
if re.fullmatch(r"-?[0-9]+(\.[0-9]+)?|true|false",v): lit=v
else: lit="\""+v.replace("\\","\\\\").replace("\"","\\\"")+"\""
for k in opt:
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*",k): raise SystemExit(2)
out=lit
for k in reversed(opt): out="{ %s = %s }" % (k,out)
print("hl.config(%s)" % out)
')" || return 2
      hypr_act eval "$expr" >/dev/null ;;
    classic) hypr_act keyword "$opt" "$val" >/dev/null ;;
    *)       return 3 ;;
  esac
}

display_notify() {  # <ms> <text>
  local ms="${1:-5000}" text="${2-}"
  if display_up && hypr notify -1 "$ms" 0 "$text" >/dev/null; then return 0; fi
  command -v notify-send >/dev/null 2>&1 && notify-send -t "$ms" "Ymir" "$text" && return 0
  return 3
}
