#!/usr/bin/env bash
# hypr.sh — the one Hyprland door (plan 341): every window, workspace, keystroke and config check the
# house needs, through verbs that know the dialect.
#
# It is the COMMAND-LINE FACE of bin/desktop/display-lib.sh, not a second library: the dialect (Lua on
# Hyprland 0.56 with an Omarchy config, classic before it) is known in that one file, and this file only
# parses arguments, guards and prints. A person, a script, an agent and the MCP all use these verbs.
#
# Read verbs (they change nothing):
#   hypr.sh dialect                       lua | classic | none, and the version
#   hypr.sh windows [--json]              every window: address, class, workspace, monitor, pid, agent, title
#   hypr.sh find <query> [--class|--title|--pid|--address] [--first]
#                                         one address, or a refusal that names the candidates
#   hypr.sh active                        the focused window's address
#   hypr.sh workspaces [--json] · workspace-active · workspace-free [max]
#   hypr.sh monitors [--json] · monitor <role>   (reading | code | primary | a monitor name)
#   hypr.sh config check [--dir <hypr-config-dir>]
#                                         Hyprland's own config errors + a syntax check of the house's ymir-*.lua
#
# Acting verbs:
#   hypr.sh focus <query>                 focus it, and remember what had focus
#   hypr.sh back                          give focus back to what had it before the last focus/type
#   hypr.sh type <query> "<line>" [--no-enter] [--stay]
#                                         focus, VERIFY focus landed, type, Enter, focus back. Types NOTHING
#                                         unless focus landed, and refuses while the desk is in a call.
#   hypr.sh workspace <n>                 switch desktop
#   hypr.sh move <query> --workspace <n> | --monitor <role>
#   hypr.sh notify "<text>" [--ms N]      an on-screen notice
#   hypr.sh config reload [--dir …]       reload, then `config check` — names the broken file and line
#   hypr.sh set <section:key> <value>     a runtime option: `eval hl.config(…)` on Lua, `keyword` on classic
#
# Off Hyprland every verb but `dialect` refuses by name (exit 3): macOS and Windows bring their own layer
# (RULES/05), and a clean refusal is a pass (RULES/25).
#
# Env: YMIR_HYPRCTL (the hyprctl to ask — tests point it at a recording) · YMIR_HYPR_DIR (config dir,
# default ~/.config/hypr) · YMIR_HYPR_STATE (where `back` is remembered) · YMIR_WTYPE (the typist,
# default wtype) · YMIR_IN_CALL (the desk door, default bin/desk/in-call.sh) · YMIR_HYPR_SETTLE (seconds
# `type` waits for focus to land, default 1).
#
# Exit: 0 ok · 1 a fault (config errors, an action Hyprland refused) · 2 usage · 3 refused (no Hyprland,
# the desk is in a call) · 4 no such window, several windows, or focus did not land.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=display-lib.sh
. "$HERE/display-lib.sh"

VERSION="1.0.0"
HYPR_DIR="${YMIR_HYPR_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr}"
STATE="${YMIR_HYPR_STATE:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/ymir/hypr-focus-back}"
WTYPE="${YMIR_WTYPE:-wtype}"
IN_CALL="${YMIR_IN_CALL:-$ROOT/bin/desk/in-call.sh}"

say()    { printf 'hypr: %s\n' "$*" >&2; }
usage()  { say "$*"; say "help: bin/desktop/hypr.sh --help"; exit 2; }
need_hypr() {
  display_up && return 0
  say "no Hyprland answers here (dialect none) — '${1:-this verb}' needs Hyprland; another desktop brings its own layer"
  exit 3
}
q() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '; }  # a TOON-safe field

# ── find ──────────────────────────────────────────────────────────────────────────────────────────────
resolve() {  # <query> [kind] -> address on stdout, or the refusal on stderr and exit 4
  local addr
  addr="$(window_resolve "$1" "${2:-auto}")" || exit 4
  [ -n "$addr" ] || { say "no window matches '$1'"; exit 4; }
  printf '%s' "$addr"
}
parse_find() {  # sets QUERY KIND ; consumes flags
  QUERY="" KIND="auto"
  while [ $# -gt 0 ]; do
    case "$1" in
      --class) KIND=class ;; --title) KIND=title ;; --pid) KIND=pid ;; --address) KIND=address ;;
      --first) export YMIR_HYPR_FIRST=1 ;;
      -*) usage "unknown flag $1" ;;
      *) [ -z "$QUERY" ] && QUERY="$1" || usage "one query only (got '$QUERY' and '$1')" ;;
    esac
    shift
  done
  [ -n "$QUERY" ] || usage "find needs a query: a class, a title, a pid or an address"
}

remember_focus() {
  local cur; cur="$(window_active)"
  [ -n "$cur" ] || return 0
  mkdir -p "$(dirname "$STATE")" 2>/dev/null && printf '%s\n' "$cur" >"$STATE"
}

# Focus and wait until Hyprland says the window holds focus. 0 landed · 4 did not.
focus_and_verify() {  # <address>
  local a="$1" i tries
  window_focus "$a" || return 1
  tries="$(awk -v s="${YMIR_HYPR_SETTLE:-1}" 'BEGIN{printf "%d", s*20}')"; [ "$tries" -ge 1 ] || tries=1
  for i in $(seq 1 "$tries"); do
    [ "$(window_active)" = "$a" ] && return 0
    sleep 0.05
  done
  [ "$(window_active)" = "$a" ]
}

desk_holder() {
  [ -x "$IN_CALL" ] || [ -r "$IN_CALL" ] || return 0
  bash "$IN_CALL" holder 2>/dev/null | head -1
}

# ── config check ──────────────────────────────────────────────────────────────────────────────────────
# Rows: source<TAB>file<TAB>line<TAB>error. Hyprland's own errors first (they are what a reload left),
# then a syntax check of the house's generated files, which names the file even when Hyprland's message
# does not.
config_rows() {
  local f out
  config_errors | python3 -c '
import re,sys
for l in sys.stdin:
    l=l.rstrip("\n")
    if not l.strip(): continue
    m=re.search(r"([^\s:\"\x27\[\]()]+\.(?:lua|conf)):(\d+)",l) or re.search(r"[\"\x27]?([^\s\"\x27]+\.(?:lua|conf))[\"\x27]?.*?line (\d+)",l)
    print("hyprland\t%s\t%s\t%s" % (m.group(1) if m else "", m.group(2) if m else "", l))
'
  [ "$DIALECT" = lua ] || return 0
  command -v luac >/dev/null 2>&1 || return 0
  for f in "$HYPR_DIR"/ymir-*.lua; do
    [ -f "$f" ] || continue
    out="$(luac -p "$f" 2>&1)" && continue
    # luac: <file>:<line>: <message>
    printf '%s' "$out" | head -1 | F="$f" python3 -c '
import os,re,sys
l=sys.stdin.read().strip(); f=os.environ["F"]
m=re.search(re.escape(f)+r":(\d+):\s*(.*)",l)
print("syntax\t%s\t%s\t%s" % (f, m.group(1) if m else "", m.group(2) if m else l))
'
  done
}

config_check() {  # prints the verdict; exit 0 clean · 1 broken
  local rows
  rows="$(config_rows)"
  if [ -z "$rows" ]; then
    printf 'hypr-config[1]{state,dialect,dir}:\n  "clean","%s","%s"\n' "$DIALECT" "$(q "$HYPR_DIR")"
    return 0
  fi
  printf 'hypr-config[%s]{source,file,line,error}:\n' "$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
  while IFS=$'\t' read -r src file line err; do
    printf '  "%s","%s","%s","%s"\n' "$src" "$(q "$file")" "$line" "$(q "$err")"
  done <<<"$rows"
  first="$(printf '%s\n' "$rows" | awk -F'\t' '$2!=""{print $2 ($3!=""?":"$3:""); exit}')"
  if [ -n "$first" ]; then say "the Hyprland config is broken at $first"
  else say "Hyprland reports config errors (no file named): $(printf '%s\n' "$rows" | head -1 | cut -f4)"; fi
  return 1
}

# ── verbs ─────────────────────────────────────────────────────────────────────────────────────────────
VERB="${1:-}"; shift || true
case "$VERB" in
  -h|--help|help|"") sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
esac

DIALECT="$(display_dialect)"

case "$VERB" in
  dialect)
    printf 'hypr-dialect[1]{dialect,version}:\n  "%s","%s"\n' "$DIALECT" "$(display_version)"
    ;;

  windows)
    need_hypr windows
    if [ "${1:-}" = --json ]; then windows_json; exit 0; fi
    windows_json | python3 -c '
import json,sys
try: ws=json.load(sys.stdin)
except Exception: ws=[]
def q(s): return str(s).replace("\\","\\\\").replace("\"","\\\"").replace("\n"," ")
print("hypr-windows[%d]{address,class,workspace,monitor,pid,agent,title}:" % len(ws))
for w in ws:
    print("  \"%s\",\"%s\",%s,%s,%s,\"%s\",\"%s\"" % (q(w.get("address","")),q(w.get("class","")),
      (w.get("workspace") or {}).get("id",""),w.get("monitor",""),w.get("pid",""),q(w.get("agent","")),q(w.get("title",""))))
'
    ;;

  find)
    need_hypr find
    parse_find "$@"
    resolve "$QUERY" "$KIND"; printf '\n'
    ;;

  active)
    need_hypr active
    printf '%s\n' "$(window_active)"
    ;;

  focus)
    need_hypr focus
    parse_find "$@"
    a="$(resolve "$QUERY" "$KIND")" || exit 4
    remember_focus
    focus_and_verify "$a" || { say "focus did not land on $a"; exit 4; }
    printf 'hypr-focus[1]{address,state}:\n  "%s","focused"\n' "$a"
    ;;

  back)
    need_hypr back
    [ -r "$STATE" ] || { say "nothing to give focus back to — no focus or type has run"; exit 4; }
    a="$(head -1 "$STATE")"
    [ -n "$a" ] || { say "the remembered focus is empty"; exit 4; }
    window_resolve "$a" address >/dev/null 2>&1 || { say "the window that had focus ($a) is gone"; exit 4; }
    window_focus "$a" || { say "Hyprland refused to focus $a"; exit 1; }
    printf 'hypr-back[1]{address,state}:\n  "%s","focused"\n' "$a"
    ;;

  type)
    need_hypr type
    ENTER=1 STAY=0 TQ="" LINE="" got=0 KIND=auto
    while [ $# -gt 0 ]; do
      case "$1" in
        --no-enter) ENTER=0 ;; --stay) STAY=1 ;;
        --class) KIND=class ;; --title) KIND=title ;; --pid) KIND=pid ;; --address) KIND=address ;;
        --) shift; [ $got = 1 ] && LINE="$*" && got=2; break ;;
        -*) usage "unknown flag $1" ;;
        *) if [ $got = 0 ]; then TQ="$1"; got=1; elif [ $got = 1 ]; then LINE="$1"; got=2; else usage "type takes one window and one line (quote the line)"; fi ;;
      esac
      shift
    done
    [ "$got" = 2 ] || usage 'type needs a window and a line: hypr.sh type <query> "<line>"'
    # The desk first: while the operator is on a call the keyboard and the windows are his.
    holder="$(desk_holder)"
    if [ -n "$holder" ]; then say "the desk is in a call ($holder) — nothing typed"; exit 3; fi
    command -v "$WTYPE" >/dev/null 2>&1 || { say "no typist ($WTYPE) on this machine — nothing typed"; exit 3; }
    a="$(resolve "$TQ" "$KIND")" || exit 4
    prev="$(window_active)"
    [ -n "$prev" ] && { mkdir -p "$(dirname "$STATE")" 2>/dev/null && printf '%s\n' "$prev" >"$STATE"; }
    if ! focus_and_verify "$a"; then
      say "focus did not land on $a — nothing typed"
      [ -n "$prev" ] && [ "$prev" != "$a" ] && window_focus "$prev"
      exit 4
    fi
    "$WTYPE" -- "$LINE" || { say "the typist failed on $a"; exit 1; }
    [ "$ENTER" = 1 ] && { "$WTYPE" -k Return || { say "Enter failed on $a"; exit 1; }; }
    back="kept"
    if [ "$STAY" = 0 ] && [ -n "$prev" ] && [ "$prev" != "$a" ]; then window_focus "$prev" && back="$prev"; fi
    printf 'hypr-type[1]{address,chars,enter,focus_back}:\n  "%s",%s,%s,"%s"\n' "$a" "${#LINE}" "$ENTER" "$back"
    ;;

  workspaces)
    need_hypr workspaces
    if [ "${1:-}" = --json ]; then workspaces_json; exit 0; fi
    workspaces_json | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d=[]
print("hypr-workspaces[%d]{id,monitor,windows}:" % len(d))
for w in sorted(d,key=lambda w:(w.get("id") if isinstance(w.get("id"),int) else 999)):
    print("  %s,\"%s\",%s" % (w.get("id",""),w.get("monitor",""),w.get("windows",0)))
'
    ;;
  workspace-active) need_hypr workspace-active; printf '%s\n' "$(workspace_active)" ;;
  workspace-free)   need_hypr workspace-free;   printf '%s\n' "$(workspace_free "${1:-10}")" ;;

  workspace)
    need_hypr workspace
    n="${1:-}"; [ -n "$n" ] || usage "workspace needs a number"
    workspace_go "$n" || { say "Hyprland refused workspace $n"; exit 1; }
    printf 'hypr-workspace[1]{workspace,state}:\n  "%s","switched"\n' "$n"
    ;;

  monitors)
    need_hypr monitors
    if [ "${1:-}" = --json ]; then display_json; exit 0; fi
    display_json | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d=[]
print("hypr-monitors[%d]{name,width,height,scale,focused}:" % len(d))
for m in d: print("  \"%s\",%s,%s,%s,%s" % (m.get("name",""),m.get("width",0),m.get("height",0),m.get("scale",1),str(m.get("focused",False)).lower()))
'
    ;;
  monitor) need_hypr monitor; printf '%s\n' "$(display_name_for "${1:-primary}")" ;;

  move)
    need_hypr move
    MQ="" WS="" MON=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --workspace) WS="${2:-}"; shift ;;
        --monitor)   MON="${2:-}"; shift ;;
        -*) usage "unknown flag $1" ;;
        *) [ -z "$MQ" ] && MQ="$1" || usage "move takes one window" ;;
      esac
      shift
    done
    [ -n "$MQ" ] || usage "move needs a window"
    [ -n "$WS$MON" ] || usage "move needs --workspace <n> or --monitor <role>"
    a="$(resolve "$MQ")" || exit 4
    if [ -n "$WS" ]; then
      window_to_desktop "$a" "$WS" || { say "Hyprland refused to move $a to workspace $WS"; exit 1; }
      printf 'hypr-move[1]{address,workspace}:\n  "%s","%s"\n' "$a" "$WS"
    else
      name="$(display_name_for "$MON")"; [ -n "$name" ] || { say "no monitor answers to '$MON'"; exit 4; }
      window_to_monitor "$a" "$name" || { say "Hyprland refused to move $a to $name"; exit 1; }
      printf 'hypr-move[1]{address,monitor}:\n  "%s","%s"\n' "$a" "$name"
    fi
    ;;

  notify)
    MS=5000 TEXT=""
    while [ $# -gt 0 ]; do
      case "$1" in --ms) MS="${2:-5000}"; shift ;; *) TEXT="${TEXT:+$TEXT }$1" ;; esac; shift
    done
    [ -n "$TEXT" ] || usage 'notify needs the text: hypr.sh notify "<text>"'
    display_notify "$MS" "$TEXT" || { say "no notice road here (no Hyprland, no notify-send)"; exit 3; }
    printf 'hypr-notify[1]{state,ms}:\n  "shown",%s\n' "$MS"
    ;;

  config)
    sub="${1:-}"; shift || true
    while [ $# -gt 0 ]; do
      case "$1" in --dir) HYPR_DIR="${2:?--dir needs a directory}"; shift ;; *) usage "unknown argument $1" ;; esac; shift
    done
    case "$sub" in
      check)  need_hypr "config check"; config_check ;;
      reload)
        need_hypr "config reload"
        config_reload || { say "Hyprland did not take the reload request"; config_check; exit 1; }
        config_check
        ;;
      *) usage "config check | config reload" ;;
    esac
    ;;

  set)
    need_hypr set
    opt="${1:-}"; [ $# -ge 2 ] || usage "set needs an option and a value: hypr.sh set general:gaps_in 5"
    val="$2"
    case "$opt" in *[!A-Za-z0-9_:.-]*|"") usage "'$opt' is not an option name (section:key)" ;; esac
    option_set "$opt" "$val"; rc=$?
    case "$rc" in
      0) printf 'hypr-set[1]{option,value,dialect}:\n  "%s","%s","%s"\n' "$opt" "$(q "$val")" "$DIALECT" ;;
      2) usage "'$opt' cannot be spelled as a Lua table path" ;;
      *) say "Hyprland refused $opt = $val"; exit 1 ;;
    esac
    ;;

  *) usage "unknown verb '$VERB'" ;;
esac
