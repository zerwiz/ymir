#!/usr/bin/env bash
# answer.sh — the ONE answer door (plan 365 R2). A worker ends its errand by answering the one who sent it.
#
#   answer.sh <errand> [--actor <name>]   send the answer now; when the sender is busy or away it is QUEUED and retried
#   answer.sh wait <errand> [--timeout S]  block until the handoff lands, print the line, exit (start it in the background)
#   answer.sh retry                       re-send every queued answer (a Nornir tick runs this every minute)
#   answer.sh guard <errand>              exit 0 only when the report is complete AND the answer is sent or queued
#   answer.sh pending                     queued answers, and errands silent past their lease (R4)
#   answer.sh silent [--hours N]          errands with a return address and no report (default 2 h)
#
# It wraps report.sh (the seven-field handoff must exist first) and sends by the kind of the return address
# recorded with the errand (reply-to.sh): hermes → hermes-tell.sh · herdr → eindri-send.sh · seat → fleet-tell.sh ·
# telegram → notify/send.sh · issue → gh issue comment. A refusal ("busy", "mid-turn") is not a loss: the answer stays in
# state/answers/ and `retry` lands it once the sender's turn ends. Sent answers are never resent.
set -u
HERE="$(CDPATH='' command cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${YMIR_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/ymir}"
Q="$STATE/answers"; mkdir -p "$Q" 2>/dev/null
ACTOR="${YMIR_ACTOR:-worker}"
report() { bash "$HERE/report.sh" "$@"; }

line_for() {  # <errand> -> the one line the sender reads
  local id="$1" st
  st="$(report show "$id" 2>/dev/null | grep -m1 -iE '^(\*\*)?state' | sed 's/.*: *//;s/\*//g')"
  printf '[errand %s] %s — read it: bash bin/agents/report.sh show %s' "$id" "${st:-reported}" "$id"
}

send() {  # <address> <line> -> 0 handed, 1 refused/busy (queue it)
  local kind="${1%%:*}" rest="${1#*:}" out
  # the test seam: a command that takes <address> <line> and says what a real door would say
  [ -n "${YMIR_ANSWER_SEND_CMD:-}" ] && { out="$($YMIR_ANSWER_SEND_CMD "$1" "$2" 2>&1)" || return 1; case "$out" in *refused*|*busy*) return 1 ;; esac; return 0; }
  case "$kind" in
    # A line typed into a desktop Hermes session never shows in its chat (measured 2026-11-24: "handed" was false), so
    # a hermes: address is answered by a WAITER the sender started at dispatch (`answer.sh wait <errand>`, a background
    # process that exits with the line, which wakes the sender). No live waiter: the answer stays queued for it.
    hermes)  waiter_alive "$ID_NOW" || return 1; return 0 ;;
    herdr)   out="$(bash "$HERE/eindri-send.sh" --from "agent $ACTOR" "$rest" "$2" 2>&1)" || return 1 ;;
    seat)    out="$(bash "$HERE/../fleet/fleet-tell.sh" --from "$ACTOR" "${rest/\//:}" "$2" 2>&1)" || return 1 ;;
    telegram) out="$(bash "$HERE/../notify/send.sh" --source errand --severity INFO --message "$2" 2>&1)" || return 1 ;;
    issue)   out="$(gh issue comment "${rest##*#}" --repo "${rest%#*}" --body "$2" 2>&1)" || return 1 ;;
    *) return 1 ;;
  esac
  case "$out" in *refused*|*busy*|*"not sent"*|*"mid-turn"*) return 1 ;; esac
  return 0
}

waiter_alive() { local p; p="$(cat "$Q/$1.waiter" 2>/dev/null)"; [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }

deliver() {  # <errand> -> prints sent|queued
  local id="$1" to line tries=0; ID_NOW="$id"
  to="$(bash "$HERE/reply-to.sh" get "$id" 2>/dev/null)" || { echo "refused: $id has no recorded return address (reply-to.sh record)" >&2; return 2; }
  [ -e "$Q/$id.sent" ] && { echo sent; return 0; }
  line="$(line_for "$id")"
  [ -r "$Q/$id.queued" ] && tries="$(sed -n 's/^tries=//p' "$Q/$id.queued")"
  if send "$to" "$line"; then
    : >"$Q/$id.sent"; rm -f "$Q/$id.queued"; echo sent
  else
    printf 'to=%s\nline=%s\ntries=%s\nlast=%s\n' "$to" "$line" "$((tries + 1))" "$(date -Iseconds)" >"$Q/$id.queued"
    echo queued
  fi
}

case "${1-}" in
  ""|-h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
  wait)
    # The sender starts this at dispatch, in the background: `answer.sh wait <errand> &`. It blocks until the worker's
    # handoff lands, prints the answer line and exits — the exit is the wake the sender's harness receives.
    id="${2-}"; [ -n "$id" ] || exit 2; limit="${YMIR_WAIT_SECONDS:-86400}"; [ "${3-}" = --timeout ] && limit="${4:-$limit}"
    printf '%s\n' "$$" >"$Q/$id.waiter"; trap 'rm -f "$Q/$id.waiter"' EXIT
    t0=$(date +%s)
    while ! report check "$id" >/dev/null 2>&1; do
      [ $(( $(date +%s) - t0 )) -ge "$limit" ] && { echo "[errand $id] no answer within ${limit}s — silent: $(bash "$0" silent | grep "$id" | head -1)"; exit 3; }
      sleep "${YMIR_WAIT_POLL:-5}"
    done
    : >"$Q/$id.sent"; rm -f "$Q/$id.queued"
    line_for "$id" ;;
  retry)
    for f in "$Q"/*.queued; do [ -e "$f" ] || continue; id="$(basename "$f" .queued)"; printf '%s: ' "$id"; deliver "$id"; done ;;
  guard)
    id="${2-}"; [ -n "$id" ] || exit 2
    report check "$id" >/dev/null 2>&1 || { echo "no complete handoff yet: bash bin/agents/report.sh write $id --state done|blocked|needs-decision --changed … --verified … --not-verified … --next …" >&2; exit 1; }
    [ -e "$Q/$id.sent" ] || [ -e "$Q/$id.queued" ] || { echo "the answer is not handed: bash bin/agents/answer.sh $id" >&2; exit 1; } ;;
  pending)
    for f in "$Q"/*.queued; do [ -e "$f" ] || continue; printf 'queued %s → %s (%s tries)\n' "$(basename "$f" .queued)" "$(sed -n 's/^to=//p' "$f")" "$(sed -n 's/^tries=//p' "$f")"; done
    bash "$0" silent ;;
  silent)
    hours=2; [ "${2-}" = --hours ] && hours="${3:-2}"
    for f in "$STATE"/*.replyto; do
      [ -e "$f" ] || continue; id="$(basename "$f" .replyto)"
      [ -e "$STATE/eindri-reports/$id.md" ] && continue
      [ -n "$(find "$f" -mmin +$((hours * 60)) 2>/dev/null)" ] || continue
      printf 'silent: %s · asked by %s · last seen %s\n' "$id" "$(cat "$f")" "$(date -r "$f" +%F\ %H:%M)"
    done ;;
  *)
    id="$1"; shift
    while [ $# -gt 0 ]; do case "$1" in --actor) ACTOR="${2-}"; shift ;; esac; shift; done
    report check "$id" >/dev/null 2>&1 || { echo "refused: write the handoff first — bash bin/agents/report.sh write $id --state … --changed … --verified … --not-verified … --next …" >&2; exit 1; }
    deliver "$id" ;;
esac
