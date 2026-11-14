#!/usr/bin/env bash
# msg-origin.sh — the stamp that says where a message to an agent came from (2026-11-14).
#
# At the Allfather's word: "when talking to eindris we need to tell where the message is coming from — herdr panes,
# rödd, bifrost, terminal, etc." A worker that reads a bare line cannot tell the Allfather's voice from a script or
# from another worker. Every road that speaks into an agent puts this stamp in front of the line.
#
#   . bin/agents/msg-origin.sh; line="$(msg_stamp "<text>")"      # in a script
#   bin/agents/msg-origin.sh "<text>"                               # prints the stamped line
#   bin/agents/msg-origin.sh --origin                               # prints only the origin
#
# The stamp names WHO first — the Allfather, an agent, a person, or a script — then the road, then the machine:
#   [from agent Hœnir (the helm, claude) · herdr pane w39:pT · heimdall] …
#   [from agent sessrumnir-fix (pi) · herdr pane w39:pW · heimdall] …
#   [from the Allfather, by voice through Rödd · heimdall] …
# Who, first match wins:
#   YMIR_MSG_FROM            the caller names the sender in full: "the Allfather, by voice through Rödd", "script Níðhöggr" …
#   HERDR_PANE_ID            the pane's agent; the helm when the pane is the arm holder's ($STATE/.arm.pane)
#   a terminal on stdin      "a person at terminal /dev/pts/3"
#   otherwise                "script <parent command>"
# Only a caller that KNOWS a person spoke may write "the Allfather"; everything else says agent, person or script.
# A line that already starts with "[from " is left as it is, so a relayed message is never stamped twice.

# The herdr pane's agent: "<agent>\t<name>" for a pane id, from herdr itself.
_pane_agent() {
  command -v herdr >/dev/null 2>&1 || return 0
  timeout 8 herdr agent list 2>/dev/null | P="$1" python3 -c 'import json,os,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
for a in (d.get("result") or {}).get("agents") or []:
    if a.get("pane_id")==os.environ["P"]:
        print("%s\t%s" % (a.get("agent") or "", a.get("name") or "")); break' 2>/dev/null
}

# The arm holder's pane — the helm — as the arm records it ($STATE/.arm.pane).
_helm_pane() {
  local st="${YMIR_STATE_DIR:-${BROKK_STATE_OVERRIDE:-}}"
  if [ -z "$st" ]; then
    local h=""; . "$(dirname "${BASH_SOURCE[0]}")/../vault/hoard-lib.sh" 2>/dev/null && ymir_home_root h 2>/dev/null
    st="${h:-$HOME/Documents/ymirhome}/state"   # allow-home-default: the one home
  fi
  head -1 "$st/.arm.pane" 2>/dev/null | tr -dc '[:alnum:]:._-'
}

# WHO sent it comes first, and it says plainly whether that is the Allfather or an agent (2026-11-14: a worker read
# a helm's line as the Allfather's own word). Only a caller that knows a person spoke says "the Allfather".
msg_origin() {
  local who="${YMIR_MSG_FROM:-}" road=""
  if [ -n "${HERDR_PANE_ID:-}" ]; then
    road="herdr pane ${HERDR_PANE_ID}"
    if [ -z "$who" ]; then
      local pa agent name seat
      pa="$(_pane_agent "$HERDR_PANE_ID")"; agent="${pa%%$'\t'*}"; name="${pa#*$'\t'}"; [ "$name" = "$pa" ] && name=""
      if [ -n "$HERDR_PANE_ID" ] && [ "$(_helm_pane)" = "$HERDR_PANE_ID" ]; then
        seat="$(sed -n 's/^primary=//p' "$HOME/.pi/agent/extensions/.ymir-seat" 2>/dev/null | head -1)"
        who="agent ${seat:-the helm} (the helm${agent:+, $agent})"
      elif [ -n "$name" ]; then
        who="agent ${name}${agent:+ ($agent)}"
      else
        who="agent ${agent:-in a pane}"
      fi
    fi
  fi
  if [ -z "$who" ] && [ -t 0 ]; then who="a person at terminal $(tty 2>/dev/null)"; fi
  if [ -z "$who" ]; then who="script $(ps -o comm= -p "${PPID:-0}" 2>/dev/null | tr -d ' ')"; fi
  printf '%s%s · %s' "$who" "${road:+ · $road}" "$(hostname -s 2>/dev/null || uname -n)"
}

msg_stamp() {  # <text> → "[from <origin>] <text>"
  case "${1-}" in "[from "*) printf '%s' "$1"; return 0 ;; esac
  printf '[from %s] %s' "$(msg_origin)" "${1-}"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1-}" in
    --origin) msg_origin; printf '\n' ;;
    -h|--help|"") sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) msg_stamp "$*"; printf '\n' ;;
  esac
fi
