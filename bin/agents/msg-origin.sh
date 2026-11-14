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
#   the pane hosting us     the pane's agent; the helm when the pane is the arm holder's ($STATE/.arm.pane).
#                            HERDR_PANE_ID is only a hint — it is PROVED against this process's ancestry,
#                            because a child inherits its parent pane's id (2026-11-14)
#   a terminal on stdin      "a person at terminal /dev/pts/3"
#   otherwise                "script <parent command>"
# Only a caller that KNOWS a person spoke may write "the Allfather"; everything else says agent, person or script.
# A line that already starts with "[from " is left as it is, so a relayed message is never stamped twice.

# WHICH PANE REALLY HOLDS THIS PROCESS (2026-11-14).
#
# `HERDR_PANE_ID` is inherited by every child a pane's shell starts, so a worker
# launched from the helm's shell carried the HELM's pane id and its report was
# stamped "agent Hœnir (the helm)" — the Allfather read it as the helm speaking.
# A stamp is evidence, so the pane is now PROVED, not trusted: this process's own
# ancestry must contain the pane's shell pid or one of its foreground processes.
#
#   _pane_of_self            the pane that really hosts us (or nothing)
#   _pane_verifies <pane>    0 when <pane> hosts this process
#
# `herdr pane process-info` is the authority: it reports the pane's `shell_pid`
# and its `foreground_processes[].pid`. Walking /proc upward from $$ gives every
# ancestor; a pane whose shell (or foreground agent) is in that set is ours.
_ancestors() {  # prints this process's ancestor pids, one per line (shell included)
  command -v python3 >/dev/null 2>&1 || return 0
  python3 - "$$" <<'PY' 2>/dev/null
import os, sys
pid = sys.argv[1]
seen = []
for _ in range(64):
    try:
        with open("/proc/%s/stat" % pid) as fh:
            # comm may carry spaces and parens; ppid is the field after the last ')'
            ppid = fh.read().rsplit(")", 1)[1].split()[1]
    except (OSError, IndexError):
        break
    seen.append(pid)
    if ppid in ("0", "1") or ppid == pid or ppid in seen:
        break
    pid = ppid
print("\n".join(seen))
PY
}

# The pids a pane claims, one per line: its shell and its foreground processes.
_pane_pids() {  # <pane-id>
  command -v herdr >/dev/null 2>&1 || return 0
  timeout 8 herdr pane process-info --pane "$1" 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
pi=(d.get("result") or {}).get("process_info") or {}
out=[]
if pi.get("shell_pid"): out.append(str(pi["shell_pid"]))
for p in pi.get("foreground_processes") or []:
    if p.get("pid"): out.append(str(p["pid"]))
print("\n".join(out))' 2>/dev/null
}

_pane_verifies() {  # <pane-id> → 0 when that pane hosts this process
  local want pid have
  want="$(_pane_pids "$1")"
  [ -n "$want" ] || return 1
  have="$(_ancestors)"
  for pid in $want; do
    printf '%s\n' "$have" | grep -qx "$pid" && return 0
  done
  return 1
}

# The pane that hosts us. HERDR_PANE_ID is tried first because it is nearly always
# right; when it does NOT verify it is inherited from a parent pane, so every open
# pane is checked before the answer is "no pane" (a worker still gets its own name).
_pane_of_self() {
  command -v herdr >/dev/null 2>&1 || return 0
  local cand have pid found=""
  if [ -n "${HERDR_PANE_ID:-}" ] && _pane_verifies "$HERDR_PANE_ID"; then
    printf '%s' "$HERDR_PANE_ID"; return 0
  fi
  have="$(_ancestors)"
  [ -n "$have" ] || return 1
  # One list, then one process-info per pane: bounded by the panes herdr holds.
  for cand in $(timeout 8 herdr pane list 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: raise SystemExit(0)
for p in (d.get("result") or {}).get("panes") or []:
    if p.get("pane_id"): print(p["pane_id"])' 2>/dev/null); do
    for pid in $(_pane_pids "$cand"); do
      if printf '%s\n' "$have" | grep -qx "$pid"; then found="$cand"; break 2; fi
    done
  done
  [ -n "$found" ] && printf '%s' "$found"
  return 0
}

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
  local who="${YMIR_MSG_FROM:-}" road="" pane=""
  # THE PANE IS PROVED, NEVER ASSUMED (2026-11-14): an inherited HERDR_PANE_ID named
  # the helm for a worker's own report. No verification, no pane in the stamp.
  pane="$(_pane_of_self)"
  if [ -n "$pane" ]; then
    road="herdr pane ${pane}"
    if [ -z "$who" ]; then
      local pa agent name seat
      pa="$(_pane_agent "$pane")"; agent="${pa%%$'\t'*}"; name="${pa#*$'\t'}"; [ "$name" = "$pa" ] && name=""
      if [ -n "$pane" ] && [ "$(_helm_pane)" = "$pane" ]; then
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
  # A caller that handed in a FULL origin ("agent X · herdr pane w39:p0 · heimdall") is
  # taken at its word: appending the road and the machine again printed
  # "… · heimdall · herdr pane w39:p0 · heimdall" (seen 2026-11-14). One road, one machine.
  case "$who" in
    *" · "*) printf '%s' "$who"; return 0 ;;
  esac
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
