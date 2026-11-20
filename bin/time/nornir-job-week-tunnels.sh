#!/usr/bin/env bash
# nornir-job-week-tunnels.sh — the week's tunnel uptime: how many Gimlé surfaces answer, how many fail?
#
# His word (2026-11-14): *"everything for gimle must be up on the tunnels. We need to know that."*
# Knowing is a habit, not an assertion: every surface that declares a public URL is probed on its
# road, its DNS and its answer by ONE door (`bin/records/gimle-tunnels-check.sh`), and this job keeps
# the weekly number so a slow rot — a certificate, a record, a container — is a falling line instead
# of a stranger's report.
#
#   nornir-job-week-tunnels.sh              measure, append the row, speak only when not clean
#   nornir-job-week-tunnels.sh --report     measure and print; write nothing, send nothing
#   nornir-job-week-tunnels.sh --door PATH  call another tunnels door (a fixture)
#   nornir-job-week-tunnels.sh --from FILE  read a captured door answer instead of running it
#   nornir-job-week-tunnels.sh --rc N       the exit code that captured answer carries
#   nornir-job-week-tunnels.sh --now ISO    the instant the row carries (a fixture)
#
# WHAT IT WRITES: one row in <home>/state/tunnels-week.jsonl — {at,value,detail} — where `value`
# is the number of surfaces that answered, and `detail` carries "7 up · 0 failing" and the names of
# any that did not. Appended, never rewritten (bin/time/week-pass-lib.sh owns that law for all three
# weekly passes).
#
# CLEAN means every declared surface answers (the door's exit 0). This pass measures the same facts
# the house publishes, so the numbers in the row and the door's own summary are the same numbers.
#
# Exit: 0 measured (clean or not) · 2 the door could not answer.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"
# shellcheck source=bin/time/week-pass-lib.sh
. "$ROOT/bin/time/week-pass-lib.sh"

DOOR="$ROOT/bin/records/gimle-tunnels-check.sh"
NOW=""; FROM=""; FROM_RC=0; REPORT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --report)  REPORT=1; shift ;;
    --now)     NOW="${2:-}"; shift 2 ;;
    --door)    DOOR="${2:-}"; shift 2 ;;
    --from)    FROM="${2:-}"; shift 2 ;;
    --rc)      FROM_RC="${2:-0}"; shift 2 ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'usage: %s [--report] [--now ISO] [--door PATH] [--from FILE] [--rc N]\n' "${0##*/}" >&2; exit 2 ;;
  esac
done
[ -n "$NOW" ] && YMIR_WEEK_NOW="$NOW"
week_pass_init tunnels

# ── the door ──────────────────────────────────────────────────────────────────
if [ -n "$FROM" ]; then
  [ -r "$FROM" ] || { week_pass_unmeasured "the fixture $FROM cannot be read"; exit 2; }
  answer="$(cat "$FROM")"
elif [ -r "$DOOR" ]; then
  # The TABLE, not --quiet: the summary carries the counts and the table carries the names, and a
  # weekly line that says "2 failing" without naming them sends the reader looking for them.
  answer="$(bash "$DOOR" 2>&1)"; FROM_RC=$?
else
  week_pass_unmeasured "no tunnels door at $DOOR"
  exit 2
fi

case "$FROM_RC" in
  0|1) : ;;
  2) week_pass_unmeasured "the tunnels door could not resolve the home" ; exit 2 ;;
  *) week_pass_unmeasured "the tunnels door exited $FROM_RC: $(printf '%s' "$answer" | tail -n 1 | cut -c1-160)"; exit 2 ;;
esac

# ── the count ─────────────────────────────────────────────────────────────────
# The door's own summary is the number: `<n> up · <m> failing`. A run that published a table and no
# summary has not answered the question, and is reported as unmeasured, never as zero.
summary="$(printf '%s\n' "$answer" | sed -n 's/^\([0-9][0-9]*\) up · \([0-9][0-9]*\) failing$/\1 \2/p' | tail -n 1)"
up="${summary%% *}"; failing="${summary##* }"
[ -n "$summary" ] || { week_pass_unmeasured "the door printed no summary line — cannot tell what answered"; exit 2; }
case "$up" in ''|*[!0-9]*) week_pass_unmeasured "the door's summary carries no count: $summary"; exit 2 ;; esac
case "$failing" in ''|*[!0-9]*) week_pass_unmeasured "the door's summary carries no fault count: $summary"; exit 2 ;; esac

# The failing surfaces, by name. The table's STATE column is the sixth field (SURFACE · HOSTNAME ·
# ROAD · DNS · HTTP · STATE · WHY); a hostname never carries a space, so the field holds.
names="$(printf '%s\n' "$answer" | awk '$6 == "FAIL" { printf "%s%s", (n++ ? ", " : ""), $1 }')"

detail="$up up · $failing failing"
[ "$failing" = 0 ] || detail="$detail ($names)"

if [ "$failing" = 0 ]; then clean=0; else clean=1; fi

if [ "$REPORT" = 1 ]; then
  [ "$clean" = 0 ] && printf 'week-tunnels: clean — %s\n' "$detail" || printf 'week-tunnels: NOT CLEAN — %s\n' "$detail"
  exit 0
fi

if [ "$clean" = 0 ]; then
  week_pass_verdict 0 "$up" "$detail" ""
else
  week_pass_verdict 1 "$up" "$detail" "tunnels: $detail"
fi
exit $?
