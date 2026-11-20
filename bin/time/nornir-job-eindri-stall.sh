#!/usr/bin/env bash
# nornir-job-eindri-stall.sh — the arm's ten-minute question: is a WORKING errand still MOVING?
#
# The runbook section "When a worker is stuck — the arm watches, Rödd speaks"
# (`hodd/docs/runbooks/fleet.md`) says the arm checks every working errand about every
# ten minutes. This row is that clock: it runs `bin/agents/eindri-stall.sh sweep`, which
# judges each working errand's pane, keeps a small per-errand record, and — once per
# stall — wakes the helm, steers the worker, and (ten minutes later, if nothing moved)
# sends the operator one message with three buttons.
#
# A clean fleet is SILENT: no stuck errand, no line, one Rune at most. A row that speaks
# on a healthy fleet is a nag, and a nag is muted — which is how the next real stall goes
# unseen.
#
# Exit: 0 the fleet is moving (or nothing was readable to judge) · 3 an errand is stuck
#       (the sweep already woke, steered and, when due, told the operator) · 1 the door failed.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
# The log is the HOUSE's state, resolved the way every other shell tool resolves it
# (bin/vault/hoard-lib.sh) — never a path derived from whichever tree this ran from.
for _hl in "$ROOT/bin/vault/hoard-lib.sh" "$SCRIPT_DIR/../../bin/vault/hoard-lib.sh"; do
  [ -r "$_hl" ] && { . "$_hl"; break; }
done
unset _hl
LOG_STATE="${YMIR_STATE_DIR:-}"
command -v hoard_state_dir >/dev/null 2>&1 && hoard_state_dir LOG_STATE 2>/dev/null
[ -n "${LOG_STATE:-}" ] || LOG_STATE="$ROOT/state"
mkdir -p "$LOG_STATE" 2>/dev/null || true
LOG="$LOG_STATE/eindri-stall.log"

DOOR="$ROOT/bin/agents/eindri-stall.sh"
[ -x "$DOOR" ] || { printf 'eindri-stall-job: the door is missing at %s\n' "$DOOR" >&2; exit 1; }

out="$(timeout 240 "$DOOR" sweep 2>&1)"; rc=$?
total="$(printf '%s\n' "$out" | sed -n 's/^stall\[\([0-9]*\)\].*/\1/p' | head -1)"
working="$(printf '%s\n' "$out" | grep -cE '"(MOVING|SETTLING|STUCK)"' || true)"
stuck="$(printf '%s\n' "$out" | grep -c '"STUCK"' || true)"
# The log keeps a one-line account on a moving fleet and the whole judgement when one is stuck:
# a log that repeats forty IDLE rows every ten minutes is a log nobody reads.
if [ "${stuck:-0}" -gt 0 ]; then
  printf '%s stuck=%s working=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$stuck" "${working:-0}" "$(printf '%s' "$out" | tr '\n' ' ')" >>"$LOG" 2>/dev/null || true
else
  printf '%s clean seats=%s working=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${total:-?}" "${working:-0}" >>"$LOG" 2>/dev/null || true
fi

case "$rc" in
  0) exit 0 ;;
  3) printf '%s\n' "$out"; exit 0 ;;   # handed on: the wake, the steer and Rödd's line already went
  *) printf '%s\n' "$out" >&2; exit 1 ;;
esac
