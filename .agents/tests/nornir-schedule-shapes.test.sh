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
EOS

run_at() { # <ISO-ish: "YYYY-MM-DD HH:MM">
  PATH="$FAKE:$PATH" FAKE_NOW="$1" BROKK_CRON_ONCE=1 BROKK_CRON_TICK=1 \
    BROKK_STATE_OVERRIDE="$STATE" BROKK_CONFIG_OVERRIDE="$CONF" BROKK_ROLES="dev" \
    bash "$SCHED" >/dev/null 2>>"$WORK/warn.log"
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    sleep 0.3
    # the child writes cron.pid; once its cmdline is gone, the pass is finished
    pid=$(cat "$STATE/cron.pid" 2>/dev/null || true)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && continue
    break
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

expect "an unreadable shape never fires" 0 "$(count never)"
st=$(PATH="$FAKE:$PATH" FAKE_NOW="2026-10-29 00:01" BROKK_STATE_OVERRIDE="$STATE" \
     BROKK_CONFIG_OVERRIDE="$CONF" bash "$SCHED" --status 2>/dev/null)
case "$st" in *"invalid=1"*) say "--status counts the bad line as INVALID" PASS ;;
  *) say "--status counts the bad line as INVALID" "FAIL ($st)"; fails=$((fails+1)) ;; esac
case "$(cat "$WORK/warn.log" 2>/dev/null)" in *"will NOT fire"*) say "the start names the bad line loudly" PASS ;;
  *) say "the start names the bad line loudly" "FAIL (no warning)"; fails=$((fails+1)) ;; esac

if [ "$fails" = 0 ]; then printf 'nornir-schedule-shapes: PASS\n'; exit 0; fi
printf 'nornir-schedule-shapes: %s FAILED\n' "$fails" >&2; exit 1
