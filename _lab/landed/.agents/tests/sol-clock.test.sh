#!/usr/bin/env bash
# sol-clock.test.sh — the clock door gives ONE answer, and it is right across DST.
#
# Deterministic by design: every case pins the instant with --at and the zone with
# --tz, so the test never depends on when it runs. The daylight-saving cases are the
# reason this tool exists: subtracting two zone-aware datetimes is WALL-clock
# arithmetic in Python and silently drops the skipped hour, so the elapsed answer has
# to be measured on the instants.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOL="$ROOT/bin/time/sol.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }
want() {  # <name> <expected> <actual>
  [ "$2" = "$3" ] && ok "$1" || bad "$1 — want [$2], got [$3]"
}

# 1 · one instant, in the zone the house thinks in
want "iso in Europe/Helsinki" "2026-10-18T17:55:04+03:00" \
  "$(bash "$SOL" iso --at 2026-10-18T17:55:04 --tz Europe/Helsinki --plain)"

# 2 · the same instant in UTC
want "utc of the same instant" "2026-10-18T14:55:04Z" \
  "$(bash "$SOL" utc --at 2026-10-18T17:55:04 --tz Europe/Helsinki --plain)"

# 3 · epoch zero is a known instant
want "epoch 0 renders as 1970" "1970-01-01T00:00:00Z" \
  "$(bash "$SOL" utc --at 0 --plain)"
want "stamp of epoch 0" "19700101-000000Z" \
  "$(bash "$SOL" stamp --at 0 --plain)"
want "epoch of a known instant" "1792335304" \
  "$(bash "$SOL" epoch --at 2026-10-18T17:55:04 --tz Europe/Helsinki --plain)"

# 4 · DST SPRING FORWARD — the skipped hour
#   01:00+02:00 → 04:00+03:00 is 2 hours of elapsed time, but 3 hours of calendar.
out="$(bash "$SOL" diff 2026-03-29T01:00:00 2026-03-29T04:00:00 --tz Europe/Helsinki)"
printf '%s' "$out" | grep -q '"seconds","7200"' && ok "diff across spring-forward is 2h ELAPSED" || bad "spring diff: $out"
printf '%s' "$out" | grep -q '"wall","3h"' && ok "…and it says the calendar shows 3h" || bad "wall not reported: $out"

# 5 · DST FALL BACK — adding a day changes the offset, not the elapsed 24h
out="$(bash "$SOL" add +1d --at 2026-10-24T12:00:00 --tz Europe/Helsinki)"
printf '%s' "$out" | grep -q '"local","2026-10-25T11:00:00+02:00"' \
  && ok "add +1d across fall-back lands on 11:00+02:00 (24h elapsed, 23h wall)" || bad "fall-back add: $out"

# 6 · a wall-clock time that never existed is normalised to the real reading
want "a nonexistent 03:30 becomes 04:30" "2026-03-29T04:30:00+03:00" \
  "$(bash "$SOL" iso --at 2026-03-29T03:30:00 --tz Europe/Helsinki --plain)"

# 7 · diff has a direction
out="$(bash "$SOL" diff 2026-10-18T12:00:00 2026-10-18T11:00:00 --tz UTC)"
printf '%s' "$out" | grep -q '"direction","backward"' && ok "a reversed diff says backward" || bad "direction: $out"
printf '%s' "$out" | grep -q '"seconds","-3600"' && ok "a reversed diff is negative" || bad "negative seconds: $out"

# 8 · add composes steps
want "add +1d -2h" "2026-10-19T15:55:04+03:00" \
  "$(bash "$SOL" add +1d -2h --at 2026-10-18T17:55:04 --tz Europe/Helsinki --plain)"

# 9 · the zone is reported with its provenance
out="$(bash "$SOL" tz --tz Europe/Helsinki)"
printf '%s' "$out" | grep -q '"source","--tz"' && ok "tz names where the zone came from" || bad "tz: $out"

# 10 · the context block an agent reads
out="$(bash "$SOL" context --at 2026-10-18T17:55:04 --tz Europe/Helsinki)"
printf '%s' "$out" | grep -q '"stamp","20261018-145504Z"' && ok "context carries a UTC stamp" || bad "context: $out"
printf '%s' "$out" | grep -q '"weekday","Sunday"' && ok "context carries the weekday" || bad "context weekday: $out"

# 11 · the day of the year is the day of the year (not the ISO weekday)
out="$(bash "$SOL" now --at 2026-10-18T12:00:00 --tz Europe/Helsinki)"
printf '%s' "$out" | grep -q '"day_of_year","291"' && ok "day_of_year is 291 on 18 October" || bad "day_of_year: $out"

# 12 · refusals
bash "$SOL" add +1x --at 2026-10-18T00:00:00 >/dev/null 2>&1; [ "$?" = 2 ] && ok "a bad step exits 2" || bad "bad step exit"
bash "$SOL" iso --at not-a-date >/dev/null 2>&1; [ "$?" = 2 ] && ok "a bad instant exits 2" || bad "bad instant exit"
bash "$SOL" nonsense >/dev/null 2>&1; [ "$?" = 2 ] && ok "an unknown command exits 2" || bad "unknown command exit"

# 13 · check answers with the zone and the sync state without crashing
out="$(bash "$SOL" check 2>&1)"; rc=$?
printf '%s' "$out" | grep -q '"zone",' && ok "check reports the zone" || bad "check: $out"
case "$rc" in 0|1) ok "check exits 0 (synced) or 1 (not) — never a crash" ;; *) bad "check exit $rc" ;; esac

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
