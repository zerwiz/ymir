#!/usr/bin/env bash
# tell.sh — the one door to every agent on this machine (plan 340.4).
#
# The caller names WHO; the door finds the road and says which one it took. Five places an agent
# can live, one verb:
#
#   tell.sh --list                                   every reachable agent, with its road
#   tell.sh [--from <who>] <who> "<line>"            hand one line
#   tell.sh --dry-run <who> "<line>"                 resolve the road, hand nothing
#
# <who> is one of:
#   arm                          the arm holder on this machine      -> bin/voice/rodd-arm.sh tell
#   hermes                       Hermes, a fresh session             -> bin/agents/hermes-tell.sh --new
#   hermes:desktop               the conversation the desktop is on  -> hermes-tell.sh --desktop
#   hermes:<session|title>       a named Hermes session              -> hermes-tell.sh --session
#   herdr:<pane|name> or a pane id (wXX:pY) or an errand id (the pane's name)
#                                                                    -> bin/agents/eindri-send.sh
#   window:<pid|word>            an agent in a plain terminal window -> bin/agents/window-tell.sh
#   a bare word                  a herdr pane named so, else a terminal-window agent matching it
#
# Promises: every line is stamped "[from <who>]" by the road that carries it (--from, else
# YMIR_MSG_FROM, else "script tell"); the result is HANDED plus any answer, never "done"; one
# line only — a long message goes in a letter file and the line points at it.
# Not yet: <machine>:<who> on another machine is plan 340.5, and is refused by name here.
#
# Exit: the road's own exit code · 2 usage or no road · 64 refused before any road was taken.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FROM="${YMIR_MSG_FROM:-script tell}"
DRY=0

die() { printf 'tell: %s\n' "$*" >&2; exit "${2:-2}"; }
say() { printf 'tell: %s\n' "$*"; }

EINDRI_SEND="$HERE/eindri-send.sh"
WINDOW_TELL="$HERE/window-tell.sh"
HERMES_TELL="$HERE/hermes-tell.sh"
RODD_ARM="$ROOT/bin/voice/rodd-arm.sh"

# herdr panes as tab-separated rows: pane_id  name  agent  status  title
herdr_rows() {
  command -v herdr >/dev/null || return 0
  herdr agent list 2>/dev/null | python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
for a in (d.get("result") or {}).get("agents") or []:
    print("\t".join([a.get("pane_id",""), a.get("name",""), a.get("agent",""),
                     a.get("agent_status",""), (a.get("terminal_title_stripped") or "")[:50]]))'
}

herdr_pane_for() {  # <pane-id|name> -> pane id, or nothing
  local want="$1"
  herdr_rows | awk -F'\t' -v w="$want" '$1==w {print $1; exit} $2==w {print $1; exit}'
}

list() {
  printf 'agents{who,road,target,state,title}:\n'
  # the arm
  if [ -x "$RODD_ARM" ]; then
    "$RODD_ARM" who 2>/dev/null | awk -F'"' 'NR==2 {printf "  arm,arm,\"%s (%s)\",\"heartbeat %ss\",\"the arm holder on %s\"\n",$2,$4,$22,$8}'
  fi
  # herdr panes
  herdr_rows | awk -F'\t' '{who=($2!=""?$2:$1); printf "  %s,herdr,%s,%s,\"%s · %s\"\n",who,$1,$4,$3,$5}'
  # terminal windows
  if [ -x "$WINDOW_TELL" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
    "$WINDOW_TELL" --list 2>/dev/null | awk -F',' 'NR>1 {sub(/^ +/,"",$1); printf "  window:%s,window,%s,-,%s · %s\n",$1,$4,$2,$6}'
  fi
  # Hermes
  if [ -x "$HERMES_TELL" ]; then
    local where key dsid dstate
    where="$("$HERMES_TELL" --where 2>/dev/null || true)"
    if printf '%s\n' "$where" | grep -q '^  listener,http'; then
      key="$(printf '%s\n' "$where" | awk -F',' '$1=="  key"{print $2}')"
      dsid="$(printf '%s\n' "$where" | awk -F',' '$1=="  desktop_session"{print $2}')"
      dstate="$(printf '%s\n' "$where" | sed -n 's/^  desktop_state,"\(.*\)"$/\1/p')"
      printf '  hermes,hermes-api,new session,%s,"Hermes gateway"\n' "$([ "${key%% *}" = present ] && echo ready || echo 'no key')"
      [ "$dsid" != "-" ] && printf '  hermes:desktop,hermes-api,%s,"%s","the conversation the desktop is on"\n' "${dsid:0:24}" "$dstate"
      "$HERMES_TELL" --sessions 2>/dev/null | awk -F',' 'NR>1 {sub(/^ +/,"",$1); printf "  hermes:%s,hermes-api,%s,%s,%s\n",substr($1,1,16),substr($1,1,24),$6,$4}'
    fi
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --list) list; exit 0 ;;
    --from) [ -n "${2:-}" ] || die "--from needs a name"; FROM="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --) shift; break ;;
    -*) die "unknown flag $1 (see --help)" ;;
    *) break ;;
  esac
done
[ $# -ge 2 ] || die 'usage: tell.sh [--from <who>] <who> "<line>"   (tell.sh --list names every agent)'
who="$1"; shift
line="$*"
case "$line" in *$'\n'*) die "one line only — put a long message in a letter file and tell its path" 64 ;; esac
case "$line" in *$'\e'*) die "refusing a line carrying an escape sequence" 64 ;; esac
[ -n "${line//[[:space:]]/}" ] || die "no line to hand" 64

# ── resolve who -> road ───────────────────────────────────────────────────────
road=""; target=""; argv=()
case "$who" in
  arm)
    road=arm; target="the arm holder"
    argv=("$RODD_ARM" tell --from "$FROM" "$line") ;;
  hermes)
    road=hermes-api; target="a fresh Hermes session"
    argv=("$HERMES_TELL" --from "$FROM" --new) ;;
  hermes:desktop)
    road=hermes-api; target="the Hermes desktop's conversation"
    argv=("$HERMES_TELL" --from "$FROM" --desktop) ;;
  hermes:*)
    road=hermes-api; target="Hermes session ${who#hermes:}"
    argv=("$HERMES_TELL" --from "$FROM" --session "${who#hermes:}") ;;
  window:*)
    road=window; target="terminal window ${who#window:}"
    argv=("$WINDOW_TELL" --from "$FROM" "${who#window:}") ;;
  herdr:*)
    p="$(herdr_pane_for "${who#herdr:}")"
    [ -n "$p" ] || die "no herdr pane is named or numbered '${who#herdr:}' (see --list)"
    road=herdr; target="pane $p"
    argv=("$EINDRI_SEND" --from "$FROM" "$p") ;;
  *)
    p="$(herdr_pane_for "$who")"
    if [ -n "$p" ]; then
      road=herdr; target="pane $p"
      argv=("$EINDRI_SEND" --from "$FROM" "$p")
    elif [[ "$who" =~ ^[^:]+:[^:]+$ ]] && ! [[ "$who" =~ ^w[0-9A-Za-z]+:p[0-9A-Za-z]+$ ]]; then
      die "'$who' looks like <machine>:<who> — another machine's road is plan 340.5, not built yet; use bin/fleet/arm-send.sh or eindri-send.sh --machine" 64
    elif [ -x "$WINDOW_TELL" ] && "$WINDOW_TELL" --dry-run "$who" "probe" >/dev/null 2>&1; then
      road=window; target="terminal window matching '$who'"
      argv=("$WINDOW_TELL" --from "$FROM" "$who")
    else
      die "no agent answers to '$who' on any road (see tell.sh --list)"
    fi ;;
esac

[ -x "${argv[0]}" ] || die "the $road road is missing here (${argv[0]#"$ROOT"/})"
say "road $road → $target"
if [ "$DRY" = 1 ]; then
  case "$road" in
    window|hermes-api) "${argv[0]}" --dry-run "${argv[@]:1}" "$line"; exit $? ;;
    *) say "dry run — would hand: [from $FROM] $line"; exit 0 ;;
  esac
fi
# arm's line is already the last argv; the others take it now.
[ "$road" = arm ] || argv+=("$line")
"${argv[@]}"
rc=$?
if [ "$rc" -eq 0 ]; then
  say "handed via $road — a tell is HANDED, not done, until the agent answers"
else
  say "the $road road refused or failed (exit $rc) — see its line above"
fi
exit "$rc"
