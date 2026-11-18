#!/usr/bin/env bash
# nornir-schedule-shapes.test.sh — the clock can say hourly, and a shape it cannot
# read is named instead of going silently dead (plan 140).
#
# Why: the Allfather asked for an hourly memory sync (2026-10-28) and Nornir could not
# say it — the matcher was an exact `date +%H:%M` compare with a PER-DAY stamp, so
# "hourly" meant 24 literal rows and any of them could rot unread.
#
# No waiting: a fake `date` sets the clock, BROKK_CRON_TICK=1 makes the loop tight, and
# BROKK_CRON_ONCE=1 makes it run one pass and exit.
#
# Exit: 0 all pass · 1 a check failed · 2 usage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHED="$ROOT/bin/time/nornir-cron-start.sh"
[ -x "$SCHED" ] || { printf 'error: no scheduler at %s\n' "$SCHED" >&2; exit 2; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
STATE="$WORK/state"; CONF="$WORK/conf"; FAKE="$WORK/bin"; LOCKD="$WORK/lock"
mkdir -p "$STATE" "$CONF" "$FAKE" "$LOCKD"
MARK="$WORK/fired"
printf '%s\n' "$$" >"$LOCKD/brokk.lock"
printf '%s\n' "$LOCKD/brokk.lock" >"$STATE/.lock-path"

cat >"$FAKE/date" <<'EOS'
#!/usr/bin/env bash
case "$*" in
  "+%H:%M") printf '%s\n' "${FAKE_NOW#* }" ;;
  "+%Y-%m-%d") printf '%s\n' "${FAKE_NOW%% *}" ;;
  "+%Y-%m-%dT%H") printf '%s\n' "$(printf '%s' "${FAKE_NOW%% *}")T$(printf '%s' "${FAKE_NOW#* }" | cut -d: -f1)" ;;
  "+%a") printf '%s\n' "$(python3 -c 'import datetime,sys
print(datetime.date.fromisoformat(sys.argv[1]).strftime("%a"))' "${FAKE_NOW%% *}" 2>/dev/null || printf Mon)" ;;
  "-u +%Y-%m-%dT%H:%M:%SZ") printf '%s\n' "$(printf '%s' "${FAKE_NOW%% *}")T$(printf '%s' "${FAKE_NOW#* }"):00Z" ;;
  *) printf '%s\n' "${FAKE_NOW:-1970-01-01 00:00}" ;;
esac
EOS
chmod +x "$FAKE/date"

cat >"$CONF/cron.yaml" <<EOS
# test schedule
@hourly printf 'hourly\n' >> $MARK
@hourly:07 printf 'min7\n' >> $MARK
@daily printf 'daily\n' >> $MARK
03:00 printf 'at3\n' >> $MARK
@heart @hourly:00 printf 'gated\n' >> $MARK
@bogus-shape printf 'never\n' >> $MARK
Mon 09:15 printf 'mon915\n' >> $MARK
@dev Tue,Fri 09:15 printf 'tuefri\n' >> $MARK
Funday 09:15 printf 'funday\n' >> $MARK
EOS

run_at() { # <ISO-ish: "YYYY-MM-DD HH:MM">
  local prev="" cur quiet=0
  PATH="$FAKE:$PATH" FAKE_NOW="$1" BROKK_CRON_ONCE=1 BROKK_CRON_TICK=1 \
    BROKK_STATE_OVERRIDE="$STATE" BROKK_CONFIG_OVERRIDE="$CONF" BROKK_ROLES="dev" \
    bash "$SCHED" >/dev/null 2>>"$WORK/warn.log"
  # WAIT ON THE MARK, NOT ON THE PID (2026-11-18). The loop runs each row in a BACKGROUND subshell
  # (`( run_row ) &`) and then exits on BROKK_CRON_ONCE, so `cron.pid` is gone — or holds a previous
  # pass's pid — while the row this pass fired is still writing. Counting on the pid therefore
  # counted too early under a loaded runner and CI saw `0` where the row fired a moment later
  # (PR #817: "a day gate fires on its own day — want 1, got 0", while the very next count saw it).
  # The mark file is the one fact that settles: wait until it has been unchanged for 2 seconds.
  for _ in $(seq 1 100); do
    sleep 0.25
    cur="$(wc -c <"$MARK" 2>/dev/null || echo 0) $(wc -l <"$MARK" 2>/dev/null || echo 0)"
    if [ -n "$prev" ] && [ "$cur" = "$prev" ]; then
      quiet=$((quiet + 1))
      [ "$quiet" -ge 8 ] && break
    else
      quiet=0
    fi
    prev="$cur"
  done
}

count() { # <word> -> how many times it was written
  local n
  n=$(grep -c "^$1\$" "$MARK" 2>/dev/null)
  printf '%s' "${n:-0}"
}
fails=0
say() { printf '  %-52s %s\n' "$1" "$2"; }
expect() { # <name> <expected> <actual>
  if [ "$2" = "$3" ]; then say "$1" PASS; else say "$1" "FAIL (want $2, got $3)"; fails=$((fails+1)); fi
}

run_at "2026-10-28 03:00"
expect "@hourly fires at :00" 1 "$(count hourly)"
expect "HH:MM row fires at its minute" 1 "$(count at3)"
expect "@daily does not fire at 03:00" 0 "$(count daily)"
expect "@hourly:07 does not fire at :00" 0 "$(count min7)"
expect "role gate before a shape still gates" 0 "$(count gated)"

run_at "2026-10-28 03:00"
expect "nothing re-fires in the same minute/day" 1 "$(count hourly)"
expect "the daily row still fires only once" 1 "$(count at3)"

run_at "2026-10-28 03:07"
expect "@hourly:07 fires at its own minute" 1 "$(count min7)"
expect "@hourly does not fire twice in the hour" 1 "$(count hourly)"

run_at "2026-10-28 04:00"
expect "@hourly fires again in the next hour" 2 "$(count hourly)"

run_at "2026-10-29 00:00"
expect "@daily fires at midnight" 1 "$(count daily)"
expect "@hourly fires in the new hour" 3 "$(count hourly)"
expect "the 03:00 row does not fire at 00:00" 1 "$(count at3)"

# ── the DAY gate (plan 305, appended 2026-11-17) ────────────────────────────────────
# The weekly draft sweep asked for `@heart Mon 09:15 …`, and a shape the scheduler cannot
# read is a row that never fires while it still looks declared. 2026-11-17 was a Tuesday.
run_at "2026-11-16 09:15"   # Monday
expect "a day gate fires on its own day" 1 "$(count mon915)"
expect "a day list does not fire on another day" 0 "$(count tuefri)"

run_at "2026-11-16 09:15"
expect "a day-gated row fires once on that day" 1 "$(count mon915)"

run_at "2026-11-16 09:16"
expect "a day-gated row waits for its minute" 1 "$(count mon915)"

run_at "2026-11-17 09:15"   # Tuesday
expect "Monday's row does not fire on Tuesday" 1 "$(count mon915)"
expect "the day list fires on a listed day" 1 "$(count tuefri)"

run_at "2026-11-20 09:15"   # Friday
expect "the day list fires on its second day" 2 "$(count tuefri)"
expect "an unreadable day never fires" 0 "$(count funday)"

expect "an unreadable shape never fires" 0 "$(count never)"
st=$(PATH="$FAKE:$PATH" FAKE_NOW="2026-10-29 00:01" BROKK_STATE_OVERRIDE="$STATE" \
     BROKK_CONFIG_OVERRIDE="$CONF" bash "$SCHED" --status 2>/dev/null)
case "$st" in *"invalid=2"*) say "--status counts both bad lines as INVALID" PASS ;;
  *) say "--status counts both bad lines as INVALID" "FAIL ($st)"; fails=$((fails+1)) ;; esac
case "$(cat "$WORK/warn.log" 2>/dev/null)" in *"will NOT fire"*) say "the start names the bad line loudly" PASS ;;
  *) say "the start names the bad line loudly" "FAIL (no warning)"; fails=$((fails+1)) ;; esac

if [ "$fails" = 0 ]; then printf 'nornir-schedule-shapes: PASS\n'; exit 0; fi
printf 'nornir-schedule-shapes: %s FAILED\n' "$fails" >&2; exit 1
