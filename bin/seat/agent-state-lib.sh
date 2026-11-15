#!/usr/bin/env bash
# agent-state-lib.sh — herdr's own word on where an agent stands, and whether it is READY for input.
#
# WHY (plan 291 row 5, 2026-11-14): `herdr agent start` returns as soon as the pane HOLDS the agent,
# which is not the same as the harness having drawn its input box. Measured that day: two hand-seated
# workers sat idle — their first prompt went to a harness that was still booting, and only a second
# prompt woke them. A launcher that cannot tell `started` from `ready` and `idle` from `working`
# cannot prove it delivered anything, so these two readers are shared, and testable on their own.
#
#   agent_state <ref>   working | idle | done | unknown    — herdr's `agent_status`
#   agent_ready <ref>   0 ready · 1 not (yet)              — `interactive_ready`, or past it
#
# A harness herdr cannot detect as interactive reports no `interactive_ready` at all: readiness is
# answered YES rather than blocking a seat for ever on a field that machine will never set.
# `unknown` (herdr is absent, or answers nothing) is a NO for readiness — a reader that cannot see
# the agent must not claim it is ready.
set -u

# The caller may own the invocation (herdr-run.sh wraps it with a session); otherwise the binary
# named by HDR_BIN/HDR, then PATH. ONE door either way.
_agent_state_hdr() {
  if declare -F hdr >/dev/null 2>&1; then hdr agent "$@"
  else "${HDR_BIN:-${HDR:-herdr}}" agent "$@"; fi
}

agent_state() {  # <ref>
  _agent_state_hdr get "${1-}" 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); r=d.get("result",{}); a=r.get("agent",r)
    print(a.get("agent_status") or a.get("status") or "unknown")
except Exception:
    print("unknown")' 2>/dev/null || printf 'unknown\n'
}

agent_ready() {  # <ref> — 0 ready, 1 not ready
  local line
  line="$(_agent_state_hdr get "${1-}" 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); r=d.get("result",{}); a=r.get("agent",r)
    ready=a.get("interactive_ready")
    status=a.get("agent_status") or ""
    # `working` and `done` are ALREADY PAST needing input, so they win over a stale flag.
    # `idle` does NOT: an idle agent whose box is not drawn is the measured fault, not a ready one.
    if ready is True or status in ("working","done"):
        print("yes")
    elif ready is False:
        print("no")
    else:
        print("nodetect")
except Exception:
    print("unknown")' 2>/dev/null)"
  case "${line:-unknown}" in
    yes|nodetect) return 0 ;;
    *) return 1 ;;
  esac
}
