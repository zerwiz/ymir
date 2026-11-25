#!/usr/bin/env bash
# hermes-arm-wake.sh — wake a Hermes session that holds the Gná arm, and show it the wakes.
#
# A Claude holder is woken by its Stop hook and a pi holder by its watcher extension. A Hermes
# holder (desktop or terminal) has neither, so a tell sat in the queue unseen. This door posts the
# pending wakes into the holder's Hermes session through the gateway (bin/agents/hermes-tell.sh),
# with the same contract Claude gets: the text, how to answer, how to ack.
#
# Usage: hermes-arm-wake.sh [--state <dir>] [--session <id>] [--dry-run]
# Prints one row: hermes-arm-wake[1]{result,session,wakes,detail}. `posted` only when the gateway
# accepted the line and answered (or on --dry-run); `none` when nothing is pending; otherwise
# `failed` with the reason. It never says `posted` for a line nobody received.
# Exit: 0 posted or nothing pending · 1 failed · 2 usage.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
state=""; session=""; dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --state) state="${2:-}"; shift 2 ;;
    --session) session="${2:-}"; shift 2 ;;
    --dry-run) dry=1; shift ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "hermes-arm-wake: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
row() { printf 'hermes-arm-wake[1]{result,session,wakes,detail}:\n  "%s","%s","%s","%s"\n' "$1" "$2" "$3" "$4"; }
if [ -z "$state" ]; then
  room="$(bash "$HERE/rodd-room.sh" path 2>/dev/null || true)"
  [ -n "$room" ] && state="$(dirname "$(dirname "$room")")"
fi
[ -d "$state" ] || { row failed "$session" 0 "no state dir: no arm is held"; exit 1; }

wakes="$(BROKK_STATE_OVERRIDE="$state" bash "$ROOT/bin/time/saga-wake-drain.sh" drain 2>&1 | head -40)"
count="$(printf '%s\n' "$wakes" | grep -c '^WAKE ' || true)"
if [ "${count:-0}" -eq 0 ]; then row none "$session" 0 "nothing pending"; exit 0; fi

line="YOU HOLD THE ARM. These wakes are owed an answer now: $(printf '%s' "$wakes" | tr '\n' ' ' | tr -s ' ')"
line="$line | Answer Rodd with: bash $ROOT/bin/voice/rodd-room.sh reply \"<text>\" | then drop them with: BROKK_STATE_OVERRIDE=$state bash $ROOT/bin/time/saga-wake-drain.sh ack"
args=(--from "script hermes-arm-wake" --timeout 20)
if [ -n "$session" ]; then args+=(--session "$session"); else args+=(--desktop); fi
[ "$dry" = 1 ] && args+=(--dry-run)

out="$(bash "$ROOT/bin/agents/hermes-tell.sh" "${args[@]}" "$line" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then row posted "$session" "$count" "gateway accepted and answered"; exit 0; fi
detail="$(printf '%s' "$out" | tail -1 | tr '"' "'" | cut -c1-160)"
row failed "$session" "$count" "hermes-tell rc=$rc: $detail"
exit 1
