#!/usr/bin/env bash
# seat-wake.sh — the seat's word to the ARM, not to a desktop.
#
# The Allfather, 2026-11-10: *"when a seat fails to prove after the 60 s wait, the
# holder of the Gná arm MUST be notified"* — and *"today only the shell path calls
# bin/notify/send.sh, which is not the arm; the engine path notifies nothing."*
#
# A `notify/send.sh` line is a desktop note. The ARM is the durable wake queue the
# helm-holding session drains at every turn (`state/.wake-queue`), the same road
# `bin/agents/eindri-acclaim.sh` writes through `eindri_queue_wake`. A seat that
# failed to prove must reach that queue, or the session keeps believing a worker is
# running while a bare shell sits in its pane.
#
# ONE door for both roads (the shell spawner and the Python engine), so the two can
# never disagree about the grammar or the home they write to.
#
# Usage:
#   seat-wake.sh <errand-id> failed   [--pane P] [--worktree W] [--why TEXT] [--settle N]
#   seat-wake.sh <errand-id> adopted  [--pane P] [--worktree W] [--why TEXT]
#
# Exit: 0 written (or already written) · 2 usage. It never blocks a seat.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
BROKK_HOME="${BROKK_HOME:-$ROOT}"

# The queue is the operator's home, resolved the way every door resolves it
# (RULES/07): BROKK_STATE_OVERRIDE first, then the hoard, then the tree.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
STATE="${BROKK_STATE_OVERRIDE:-}"
if [ -z "$STATE" ]; then
  _hs=""
  command -v hoard_state_dir >/dev/null 2>&1 && hoard_state_dir _hs 2>/dev/null
  STATE="${_hs:-$BROKK_HOME/state}"
  unset _hs
fi
QUEUE="$STATE/.wake-queue"

ID="${1-}"; KIND="${2-}"
[ -n "$ID" ] && [ -n "$KIND" ] || {
  printf 'error: usage: seat-wake.sh <errand-id> <failed|adopted> [--pane P] [--worktree W] [--why TEXT]\n' >&2
  exit 2
}
shift 2 || true
case "$KIND" in failed|adopted) ;; *) printf 'error: kind must be failed or adopted\n' >&2; exit 2 ;; esac

PANE=""; WT=""; WHY=""; SETTLE="${YMIR_SEAT_SETTLE:-60}"
while [ $# -gt 0 ]; do
  case "$1" in
    --pane) PANE="${2-}"; shift 2 ;;
    --worktree) WT="${2-}"; shift 2 ;;
    --why) WHY="${2-}"; shift 2 ;;
    --settle) SETTLE="${2-}"; shift 2 ;;
    *) shift ;;
  esac
done

# Exactly once per (errand, kind): the same ledger bin/agents/eindri-wake-lib.sh
# uses, so a retry of a failed launch cannot ring the arm twice.
LEDGER="$STATE/eindri-delivered"
mkdir -p "$LEDGER" 2>/dev/null || true
if [ -f "$LEDGER/$ID.seat-$KIND" ]; then
  printf 'seat-wake[1]{id,kind,state}:\n  "%s","%s","already written"\n' "$ID" "$KIND"
  exit 0
fi

case "$KIND" in
  failed)
    LINE="eindri $ID SEAT FAILED: pane ${PANE:-unknown}, worktree ${WT:-unknown} — $([ -n "$WHY" ] && printf '%s' "$WHY" || printf 'no agent stood there after %ss (the errand is not running; do not steer it)' "$SETTLE")" ;;
  adopted)
    LINE="eindri $ID SEAT ADOPTED: pane ${PANE:-unknown}, worktree ${WT:-unknown} — $([ -n "$WHY" ] && printf '%s' "$WHY" || printf 'a late boot; the record was corrected and the watch armed')" ;;
esac

mkdir -p "$STATE" 2>/dev/null || true
printf '%s\n' "$LINE" >>"$QUEUE"
printf '%s %s seat-wake %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$ID" "$KIND" >"$LEDGER/$ID.seat-$KIND"
printf 'seat-wake[1]{id,kind,state}:\n  "%s","%s","written to %s"\n' "$ID" "$KIND" "$QUEUE"
