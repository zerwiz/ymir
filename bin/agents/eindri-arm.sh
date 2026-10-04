#!/usr/bin/env bash
# eindri-arm.sh — the Eindri's own arm (plan 42, the automation law).
#
# Every errand is ARMED: a watcher cycle beside the worker that IS the handoff
# trigger. The arm polls the task's state and, on the signals that matter,
# performs the close hook — it does not wait for a coordinator to remember.
#
#   completion : the worker (pid recorded in state/<id>.arm) exits, or the
#                worker writes state/<id>.done → the arm files the result,
#                marks the backlog, queues Forseti's verdict, carves a rune.
#   steer      : a message in data/<id>/inbox/ → ack to the worker's pane log
#                (steering does not wait for the worker to look up).
#   timeout    : TTL (default 24h) or the coordinator disarms
#                (state/<id>.arm removed) → the arm retires.
#
# Usage:   eindri-arm.sh <id> [--ttl SECONDS] [--poll SECONDS] [--quiet]
# Env:     BROKK_HOME / BROKK_DATA_OVERRIDE / BROKK_STATE_OVERRIDE (siblings)
# Exit:    0 retired/handled, 1 error, 2 usage.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
BROKK_HOME="${BROKK_HOME:-${BROKK_ROOT_OVERRIDE:-$ROOT}}"
DATA="${BROKK_DATA_OVERRIDE:-$BROKK_HOME/data}"
STATE="${BROKK_STATE_OVERRIDE:-$BROKK_HOME/state}"

ID="${1-}"
[ -n "$ID" ] || { echo "error: task-id required (eindri-arm.sh <id>)" >&2; exit 2; }
TTL=86400
POLL=5
QUIET=0
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --ttl) TTL="${2-}"; shift 2 ;;
    --poll) POLL="${2-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    *) shift ;;
  esac
done

say() { [ "$QUIET" = 1 ] || printf '%s\n' "$*"; }
ARM="$STATE/$ID.arm"
DONE_MARK="$STATE/$ID.done"
INBOX="$DATA/$ID/inbox"

pid_of() {
  [ -f "$ARM" ] || return 1
  awk -F= '$1=="pid"{print $2}' "$ARM" 2>/dev/null | tail -1
}
alive() { kill -0 "$1" 2>/dev/null; }

if [ ! -s "$ARM" ]; then
  # first touch: the arm claims the task (the dispatcher's child); record pid
  mkdir -p "$STATE" "$DATA"
  printf 'pid=%s\ntask=%s\nclaimed=%s\n' "$$" "$ID" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ARM"
  say "arm: claimed task $ID (pid $$)"
fi

start=$(date +%s)
HANDOFF_WAIT=600   # after the worker is done, hold the arm until Brokk's handoff ack (the review verdict)
close_fired=0
while :; do
  now=$(date +%s)
  touch "$STATE/$ID.beat"    # the beat: Brokk sees the arm is alive and watching
  if [ $((now - start)) -gt "$TTL" ]; then
    say "arm: ttl reached for $ID — retiring WITHOUT handoff (coordinator escalation: the work is not with Brokk)"
    rm -f "$ARM"
    exit 1
  fi
  [ -f "$ARM" ] || { say "arm: disarmed ($ID)"; exit 0; }

  # handoff DELIVERED? the review verdict exists = Brokk has the work
  if [ -f "$STATE/$ID.review" ]; then
    say "arm: handoff delivered for $ID (review verdict present) — retiring"
    rm -f "$ARM"
    exit 0
  fi

  # completion (the worker wrote its done marker, or its pid is gone)
  closed=0
  if [ -f "$DONE_MARK" ]; then closed=1
  else
    p=$(pid_of)
    if [ -n "$p" ] && [ "$p" != "$$" ] && ! alive "$p"; then closed=1; fi
  fi
  if [ "$closed" = 1 ] && [ "$close_fired" = 0 ]; then
    close_fired=1
    say "arm: close hook for $ID (worker done) — holding until Brokk's handoff ack"
    if [ -x "$SCRIPT_DIR/eindri-dispatch.sh" ]; then
      BROKK_HOME="$BROKK_HOME" BROKK_DATA_OVERRIDE="$DATA" BROKK_STATE_OVERRIDE="$STATE" \
        "$SCRIPT_DIR/eindri-dispatch.sh" close "$ID" --verdict pass --note "auto-closed by the arm" \
        >/dev/null 2>&1 || say "arm: close hook failed for $ID"
    fi
    # the arm HANDS OFF (mkdir the ack path for the coordinator) and keeps
    # watching: it retires only when state/<id>.review exists (Brokk received)
    mkdir -p "$DATA/$ID"
    printf 'delivered=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DATA/$ID/handoff"
    continue
  fi
  # a dead worker whose close already fired but no verdict yet: hold, do not
  # retire — work is done, handoff is pending (the Allfather's law).
  if [ "$close_fired" = 1 ] && [ $((now - start)) -gt "$HANDOFF_WAIT" ]; then
    say "arm: $ID worker done, handoff still pending after ${HANDOFF_WAIT}s — STILL HOLDING (coordinator, wake up)"
    start=$now   # reset the watchdog; never drop armed work
  fi

  # steer: a message in the inbox is ack'd to the worker's pane log
  if [ -d "$INBOX" ] && ls "$INBOX"/* >/dev/null 2>&1; then
    for m in "$INBOX"/*; do
      [ -f "$m" ] || continue
      say "arm: ack $ID ← $(basename "$m") ($(wc -l < "$m") lines)"
      rm -f "$m"
    done
  fi

  # answer: a Brokk answer for the worker is notified into the arm log
  if [ -d "$DATA/$ID/answers" ] && ls "$DATA/$ID/answers"/*.md >/dev/null 2>&1; then
    if [ ! -f "$STATE/$ID.answers-seen" ]; then
      say "arm: answer delivered for $ID — see data/$ID/answers/"
      touch "$STATE/$ID.answers-seen"
    fi
  else
    rm -f "$STATE/$ID.answers-seen" 2>/dev/null
  fi

  sleep "$POLL"
done