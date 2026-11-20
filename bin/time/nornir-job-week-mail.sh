#!/usr/bin/env bash
# nornir-job-week-mail.sh — the week's mail balance: how many conversations wait on US?
#
# His question, once a week: not "how much mail arrived" but "whose word is last, and how long have we
# left it there". The desk records every message; the join lives in ONE door
# (`bin/mail/threads.sh --json`), and this job does nothing but read that answer, keep the
# conversations older than a fortnight, and say so once.
#
# WHICH CONVERSATIONS COUNT, and why it is not simply "every inbound tail". The door already judges
# an inbound tail: a notice, an invoice, a bulk sender or a calendar machine owes nothing and sits in
# its `closed` lane. Counting those would put a number in the hundreds in front of the Allfather every
# week, and a weekly line that is always red teaches him to stop reading it. So `value` is the
# conversations whose last word is theirs, older than a fortnight, and which the door still says OWE
# AN ANSWER (`needs-you`); the detail names the wider count beside it, so nothing is hidden.
#
#   nornir-job-week-mail.sh                 measure, append the row, speak only when not clean
#   nornir-job-week-mail.sh --report        measure and print; write nothing, send nothing
#   nornir-job-week-mail.sh --now ISO       judge the ages against this instant (a fixture)
#   nornir-job-week-mail.sh --store PATH    read another mail store (a fixture)
#   nornir-job-week-mail.sh --door PATH     call another threads door (a fixture)
#   nornir-job-week-mail.sh --from FILE     read a captured door answer instead of running it
#   nornir-job-week-mail.sh --rc N          the exit code that captured answer carries
#
# WHAT IT WRITES: one row in <home>/state/mail-week.jsonl — {at,value,detail} — where `value` is
# the number of conversations whose last word is theirs and older than 14 days. Appended, never
# rewritten (bin/time/week-pass-lib.sh owns that law for all three weekly passes).
#
# CLEAN means zero such conversations: the row is still written, a no-op Rune is carved, and nothing
# is sent. A weekly cron that speaks every week is a cron nobody reads.
#
# Exit: 0 measured (clean or not) · 2 the door could not answer.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF_DIR/../.." && pwd)"
# shellcheck source=bin/time/week-pass-lib.sh
. "$ROOT/bin/time/week-pass-lib.sh"

STALE_DAYS=14
DOOR="$ROOT/bin/mail/threads.sh"
STORE=""; NOW=""; FROM=""; FROM_RC=0; REPORT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --report)  REPORT=1; shift ;;
    --now)     NOW="${2:-}"; shift 2 ;;
    --store)   STORE="${2:-}"; shift 2 ;;
    --door)    DOOR="${2:-}"; shift 2 ;;
    --from)    FROM="${2:-}"; shift 2 ;;
    --rc)      FROM_RC="${2:-0}"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'usage: %s [--report] [--now ISO] [--store PATH] [--door PATH] [--from FILE] [--rc N]\n' "${0##*/}" >&2; exit 2 ;;
  esac
done
[ -n "$NOW" ] && YMIR_WEEK_NOW="$NOW"
week_pass_init mail

# ── the door ──────────────────────────────────────────────────────────────────
if [ -n "$FROM" ]; then
  [ -r "$FROM" ] || { week_pass_unmeasured "the fixture $FROM cannot be read"; exit 2; }
  answer="$(cat "$FROM")"
elif [ -r "$DOOR" ]; then
  args=(--json)
  [ -n "$STORE" ] && args+=(--store "$STORE")
  [ -n "$NOW" ] && args+=(--now "$NOW")
  answer="$(bash "$DOOR" "${args[@]}" 2>&1)"; FROM_RC=$?
else
  week_pass_unmeasured "no threads door at $DOOR"
  exit 2
fi
if [ "$FROM_RC" != 0 ]; then
  week_pass_unmeasured "the threads door exited $FROM_RC: $(printf '%s' "$answer" | tail -n 1 | cut -c1-160)"
  exit 2
fi

# ── the balance ───────────────────────────────────────────────────────────────
read -r count inbound oldest lead <<<"$(printf '%s' "$answer" | STALE_DAYS="$STALE_DAYS" python3 -c '
import json, os, sys
stale = int(os.environ["STALE_DAYS"])
try:
    doc = json.load(sys.stdin)
except Exception as exc:
    print("ERR not JSON from the threads door: " + exc.__class__.__name__); raise SystemExit(0)
threads = doc.get("threads") or []
def theirs(t):
    # THEIR WORD LAST: the tail of the conversation came from them, not from us.
    return (t.get("last_direction") or "") == "in"
def age(t):
    return int(t.get("unanswered_days") or t.get("age_days") or 0)
inbound_old = [t for t in threads if theirs(t) and age(t) > stale]
owed = [t for t in inbound_old if (t.get("lane") or "") == "needs-you"]
oldest = max((age(t) for t in owed), default=0)
lead = "-"
if owed:
    first = sorted(owed, key=lambda t: -age(t))[0]
    who = (first.get("correspondent") or first.get("subject") or "unknown").strip().replace(" ", "-")
    lead = who + "/" + str(oldest) + "d"
print(" ".join([str(len(owed)), str(len(inbound_old)), str(oldest), lead]))
' 2>&1)"

case "${count:-}" in
  ERR) week_pass_unmeasured "the join could not be read: ${inbound:-} ${oldest:-} ${lead:-}"; exit 2 ;;
  ''|*[!0-9]*) week_pass_unmeasured "the join gave no count: ${count:-} ${inbound:-} ${oldest:-} ${lead:-}"; exit 2 ;;
esac

if [ "$count" = 0 ]; then
  clean=0
  detail="no conversation whose last word is theirs waits on us longer than ${STALE_DAYS} days"
else
  clean=1
  detail="$count conversation(s) whose last word is theirs still owe a reply after ${STALE_DAYS} days (of ${inbound} inbound tails that age; oldest ${oldest} d)"
fi

if [ "$REPORT" = 1 ]; then
  [ "$clean" = 0 ] && printf 'week-mail: clean — %s\n' "$detail" || printf 'week-mail: NOT CLEAN — %s\n' "$detail"
  exit 0
fi

week_pass_verdict "$clean" "$count" "$detail" "mail: $detail"
exit $?
