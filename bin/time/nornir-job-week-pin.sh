#!/usr/bin/env bash
# nornir-job-week-pin.sh — the week's pin distance: how far is the PINNED runtime from main?
#
# Every Ymir unit and app runs from the pin (`~/ymir-runtime`, plan 269). A pin that freezes is a
# silent thing: on 2026-11-15 the heart's pin stood 75 commits behind main and sixteen cron rows
# answered 127 for 28 days. Nothing was broken that day; the pin was simply old. So once a week the
# distance is a NUMBER in a series, not a hope.
#
# The measurement is not taken here: `bin/engine/pin-refresh.sh --check` owns it (it knows the pin,
# the branch, the fetch, and the refusals). This job reads that answer, keeps the distance, and says
# so once.
#
#   nornir-job-week-pin.sh                  measure, append the row, speak only when not clean
#   nornir-job-week-pin.sh --report         measure and print; write nothing, send nothing
#   nornir-job-week-pin.sh --door PATH      call another pin door (a fixture)
#   nornir-job-week-pin.sh --from FILE      read a captured door answer instead of running it
#   nornir-job-week-pin.sh --rc N           the exit code that captured answer carries
#   nornir-job-week-pin.sh --now ISO        the instant the row carries (a fixture)
#
# WHAT IT WRITES: one row in <home>/hodd/state/pin-week.jsonl — {at,value,detail} — where `value` is
# the distance in commits behind main, and `null` when there is no pin to measure. Appended, never
# rewritten (bin/time/week-pass-lib.sh owns that law for all three weekly passes).
#
# CLEAN means the pin is AT main (the door's exit 0). Behind, absent, diverged, or a pin that cannot
# be read is not clean, and the one line names which of those it is.
#
# Exit: 0 measured (clean or not) · 2 the door could not answer.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"
# shellcheck source=bin/time/week-pass-lib.sh
. "$ROOT/bin/time/week-pass-lib.sh"

DOOR="$ROOT/bin/engine/pin-refresh.sh"
NOW=""; FROM=""; FROM_RC=0; REPORT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --report)  REPORT=1; shift ;;
    --now)     NOW="${2:-}"; shift 2 ;;
    --door)    DOOR="${2:-}"; shift 2 ;;
    --from)    FROM="${2:-}"; shift 2 ;;
    --rc)      FROM_RC="${2:-0}"; shift 2 ;;
    -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'usage: %s [--report] [--now ISO] [--door PATH] [--from FILE] [--rc N]\n' "${0##*/}" >&2; exit 2 ;;
  esac
done
[ -n "$NOW" ] && YMIR_WEEK_NOW="$NOW"
week_pass_init pin

# ── the door ──────────────────────────────────────────────────────────────────
if [ -n "$FROM" ]; then
  [ -r "$FROM" ] || { week_pass_unmeasured "the fixture $FROM cannot be read"; exit 2; }
  answer="$(cat "$FROM")"
elif [ -r "$DOOR" ]; then
  # NOT --quiet: the door's own TOON block is its machine face, and a prose line would have to be
  # parsed with a regex that breaks the first time the wording moves.
  answer="$(bash "$DOOR" --check 2>&1)"; FROM_RC=$?
else
  week_pass_unmeasured "no pin door at $DOOR"
  exit 2
fi

fact() { printf '%s' "$answer" | sed -n "s/^ *\"$1\",\"\(.*\)\"\$/\1/p" | head -n 1; }
state="$(fact state)"; behind="$(fact behind)"; head="$(fact head)"; detail_door="$(fact detail)"

case "$FROM_RC" in
  0)
    clean=0
    value=0
    detail="${detail_door:-the pin is at main${head:+ at $head}}"
    ;;
  2)
    week_pass_unmeasured "the pin door refused its own arguments (rc=2): $(printf '%s' "$answer" | tail -n 1 | cut -c1-160)"
    exit 2
    ;;
  *)
    # 3 = behind / absent / not-a-checkout / unreadable · 4 = refused · 5 = diverged or a failed
    # fast-forward. The STATE decides the sentence, never the presence of a `behind` fact: the door
    # reports `behind 0` for a pin that is not there at all, and "0 commits behind" would be a
    # measurement of something that does not exist.
    clean=1
    label="${state:-unreadable}"
    case "$label" in
      behind|diverged|ff-failed)
        case "$behind" in ''|*[!0-9]*) value="" ;; *) value="$behind" ;; esac
        case "$value" in
          "") detail="$label${detail_door:+: $detail_door}" ;;
          *)  detail="$value commit(s) behind main${head:+ at $head}${label#behind}" ;;
        esac
        case "$label" in
          diverged|ff-failed) detail="$value commit(s) behind main${head:+ at $head} — the pin $label" ;;
        esac
        ;;
      *)
        value=""
        detail="$label${detail_door:+ — $detail_door}" ;;
    esac
    ;;
esac

if [ "$REPORT" = 1 ]; then
  [ "$clean" = 0 ] && printf 'week-pin: clean — %s\n' "$detail" || printf 'week-pin: NOT CLEAN — %s\n' "$detail"
  exit 0
fi

if [ "$clean" = 0 ]; then
  week_pass_verdict 0 "$value" "$detail" ""
else
  week_pass_verdict 1 "$value" "$detail" "pin: $detail"
fi
exit $?
