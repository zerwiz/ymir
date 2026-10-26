#!/usr/bin/env bash
# mimir-recall-today.sh — drink before you act: the session's opening recall.
#
# Plan 136, item 8. "Every session opens with a recall against the well for the
# task at hand" was a practice, and a practice is the first thing dropped when the
# work is urgent. So the session start ASKS, on its own, and this is the door it
# asks through.
#
# What it asks about, in order:
#   1. a STATED topic — $STATE/.session-topic, one line, written by a keeper or the
#      Allfather (`echo "<the day's work>" > state/.session-topic`); it is not
#      cleared here, because a stated topic usually holds for the whole day.
#   2. the day's own record — the newest heading in today's daily log
#      ($YMIR_HOME/hodd/memory/daily/YYYY-MM-DD.md).
#   3. the newest open forge order in the masterplan.
#   4. nothing: it says so, and prints how to state one. It does NOT invent a topic
#      — a recall for a guessed subject teaches a keeper to distrust the well.
#
# The recall itself is scoped by recency (`--since`, default 14 days) so a lesson
# from two years ago cannot drown the ones that are still warm.
#
# Usage:
#   mimir-recall-today.sh                 # derive the topic, recall, print
#   mimir-recall-today.sh --topic "words" # ask about exactly this
#   mimir-recall-today.sh --k 8 --days 30
#   mimir-recall-today.sh --quiet         # exit 0/1 only (a check, not a report)
#
# Exit: 0 recalled (or nothing to recall) · 1 the well door is missing · 2 usage.
set -u

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do
  [ "$PWD" = / ] && break; cd ..; done; pwd)"

# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _yc in "${ROOT:-}/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh" \
             "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/bin/vault/hoard-lib.sh"; do
    [ -n "$_yc" ] && [ -r "$_yc" ] && { . "$_yc"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _yc
fi
if [ -z "${YMIR_HOME:-}" ] && command -v ymir_home_root >/dev/null 2>&1; then
  ymir_home_root YMIR_HOME
fi
hoard_state_dir _HS 2>/dev/null
STATE="${BROKK_STATE_OVERRIDE:-${_HS:-$YMIR_HOME/state}}"
unset _HS

TOPIC=""; K=5; DAYS=14; QUIET=0
while [ $# -gt 0 ]; do
  case "$1" in
    --topic) TOPIC=${2-}; shift 2 ;;
    --k) K=${2-5}; shift 2 ;;
    --days) DAYS=${2-14}; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'error: unknown flag %s\nhelp: mimir-recall-today.sh [--topic T] [--k N] [--days N] [--quiet]\n' "$1" >&2; exit 2 ;;
  esac
done

MIMIR="$SCRIPT_DIR/mimir.sh"
[ -x "$MIMIR" ] || { [ "$QUIET" = "1" ] || printf 'recall: the memory door is missing (bin/records/mimir.sh)\n'; exit 1; }

if [ -z "$TOPIC" ] && [ -r "$STATE/.session-topic" ]; then
  TOPIC="$(head -n 1 "$STATE/.session-topic" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
fi
if [ -z "$TOPIC" ]; then
  DAYLOG="$YMIR_HOME/hodd/memory/daily/$(date -u +%Y-%m-%d).md"
  [ -r "$DAYLOG" ] || DAYLOG="$(ls -1t "$YMIR_HOME"/hodd/memory/daily/*.md 2>/dev/null | head -1)"
  if [ -n "${DAYLOG:-}" ] && [ -r "$DAYLOG" ]; then
    # The day's shape is in its BULLETS (what was done), not in the headings
    # (which are `<time> — <actor>`); the last bullet is where the day left off.
    TOPIC="$(grep -E '^- ' "$DAYLOG" 2>/dev/null | grep -vE '^- tags:' | tail -1 | sed 's/^- //' | cut -c1-140)"
    if [ -z "$TOPIC" ]; then
      TOPIC="$(grep -E '^## ' "$DAYLOG" 2>/dev/null | tail -1 | sed 's/^## //; s/ — .*//' | cut -c1-120)"
    fi
  fi
fi
if [ -z "$TOPIC" ]; then
  MP="${BROKK_MASTERPLAN:-${YMIR_HOME}/hodd/docs/masterplan.md}"
  [ -r "$MP" ] && TOPIC="$(grep -E '^- ' "$MP" 2>/dev/null | tail -1 | sed 's/^- //' | cut -c1-120)"
fi
if [ -z "$TOPIC" ]; then
  if [ "$QUIET" = "1" ]; then exit 0; fi
  printf 'no topic stated — the well was not asked\n'
  printf 'state one and the next session opens with it: echo "<the day'"'"'s work>" > %s/.session-topic\n' "$STATE"
  exit 0
fi

SINCE=""
if [ "$DAYS" -gt 0 ] 2>/dev/null; then
  # Sól owns the clock in the house, but a `date` that cannot subtract must not
  # abort the recall: unscoped is worse than no answer only in the wrong way, so
  # the fallback is today's date (a recall that finds the day is still a recall).
  SINCE="$(date -u -d "$DAYS days ago" +%Y-%m-%d 2>/dev/null \
        || date -u -v-"${DAYS}"d +%Y-%m-%d 2>/dev/null || true)"
fi

OUT="$("$MIMIR" recall "$TOPIC" --k "$K" ${SINCE:+--since "$SINCE"} 2>/dev/null)"
if [ "$QUIET" = "1" ]; then
  printf '%s\n' "$OUT" | sed -n '1s/recall\[\([0-9]*\)\].*/\1/p' | { read -r n; [ "${n:-0}" -ge 1 ]; }
  exit $?
fi

printf 'topic: %s\n' "$TOPIC"
if [ -n "$OUT" ]; then printf '%s\n' "$OUT"; else printf 'the well says nothing on that yet\n'; fi
printf 'recall is memory, not authority — the code and the Allfather win\n'
exit 0
