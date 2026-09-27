#!/usr/bin/env bash
# eindri-wake-lib.sh — the ONE delivery ledger behind the Eindri push path.
#
# Sourced, never executed. Two roads wake Brokk from a finished errand — the
# poller's action half (bin/eindri-acclaim.sh) and the failsafe sweep
# (bin/eindri-handoff.sh). They must read and write the SAME ground:
#
#   the shelf   $STATE/eindri-reports|eindri-questions/<id>.md  ← the contract
#   the ledger  $STATE/eindri-delivered/<id>.<kind>             ← exactly-once
#   the queue   $STATE/.wake-queue                              ← the wake
#
# Before this, the two roads kept private markers ($STATE/eindri-done/ against
# $STATE/eindri-handoff/), so one finished errand could be delivered twice, and
# a worker that wrote only the status shelf was invisible to the sweep. One
# ledger, one wake per (id, kind), whichever road arrives first.
set -u

# Fill EINDRI_STATE from the caller's STATE, or resolve it exactly as every
# other shell tool does (bin/hoard-lib.sh). Idempotent.
eindri_wake_init() {
  [ -n "${EINDRI_STATE:-}" ] && return 0
  if [ -n "${STATE:-}" ]; then EINDRI_STATE="$STATE"; return 0; fi
  if [ -n "${BROKK_STATE_OVERRIDE:-}" ]; then EINDRI_STATE="$BROKK_STATE_OVERRIDE"; return 0; fi
  local _d _hs
  _d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
    for _c in "$_d/hoard-lib.sh" "$(dirname "$_d")/bin/hoard-lib.sh"; do
      [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
    done
  fi
  if declare -F hoard_state_dir >/dev/null 2>&1 && hoard_state_dir _hs && [ -n "$_hs" ]; then
    EINDRI_STATE="$_hs"
    return 0
  fi
  printf 'eindri-wake-lib: cannot resolve the runtime state dir — call the resolver (bin/hoard-lib.sh)\n' >&2
  return 1
}

# 0 when (id, kind) has already been delivered by EITHER road. The legacy
# markers are honoured so a home that fed the old two-ledger shape never
# re-fires news the operator already saw.
eindri_is_delivered() {  # <id> <kind: report|question>
  local id=$1 kind=$2 d="$EINDRI_STATE"
  [ -f "$d/eindri-delivered/$id.$kind" ] && return 0
  [ -f "$d/eindri-handoff/$id.$kind" ] && return 0
  [ -f "$d/eindri-done/$id.md" ] && return 0
  return 1
}

# Record the delivery once, on the shared ledger. The eindri-done marker is
# kept as a compatibility write: the heartbeat and older readers consult it.
eindri_mark_delivered() {  # <id> <kind>
  local id=$1 kind=$2 d="$EINDRI_STATE"
  mkdir -p "$d/eindri-delivered" "$d/eindri-done" 2>/dev/null || true
  printf '%s %s delivered %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$id" "$kind" >"$d/eindri-delivered/$id.$kind"
  printf '%s %s: delivered %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$id" "$kind" >"$d/eindri-done/$id.md"
}

# The durable wake. This is the act the arm only notifies: once it is here,
# a finished errand reaches Brokk with no poller, no sweep, and no arm.
eindri_queue_wake() {  # <line>
  local line=$1 d="$EINDRI_STATE"
  mkdir -p "$d" 2>/dev/null || true
  printf '%s\n' "$line" >>"$d/.wake-queue"
}
