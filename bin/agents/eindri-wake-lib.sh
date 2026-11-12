#!/usr/bin/env bash
# eindri-wake-lib.sh — the ONE delivery ledger behind the Eindri push path.
#
# Sourced, never executed. Two roads wake Brokk from a finished errand — the
# poller's action half (bin/agents/eindri-acclaim.sh) and the failsafe sweep
# (bin/agents/eindri-handoff.sh). They must read and write the SAME ground:
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

# The helm's state — where everything FOR THE HELM is written (the wake queue,
# the report and question shelves, the delivery ledger, the status files).
# A worker runs with its own seat dir in BROKK_MACHINE_STATE_DIR and
# BROKK_STATE_OVERRIDE (its private working state). That override must never
# redirect what is for the helm: a wake filed in a seat's queue is a wake nobody
# reads (plan 272, fault 1). Any OTHER override (a test's temp dir, a deliberate
# redirect) is honoured.  Usage: eindri_helm_state <result-var> <default-state>
eindri_helm_state() {
  local _rv=$1 _def=$2 _ov="${BROKK_STATE_OVERRIDE:-}"
  if [ -n "$_ov" ] && [ "$_ov" = "${BROKK_MACHINE_STATE_DIR:-}" ]; then _ov=""; fi
  printf -v "$_rv" '%s' "${BROKK_HELM_STATE:-${_ov:-$_def}}"
}

# Fill EINDRI_STATE from the caller's STATE, or resolve it exactly as every
# other shell tool does (bin/vault/hoard-lib.sh). Idempotent.

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
