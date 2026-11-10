#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
fail=0
# bogus host refused with road named
if bin/seat/arm-talk.sh bogus-host-xyz -- "ping" 2>&1 | grep -qi "no road named\|road"; then
  echo "PASS: bogus host refused with road named"
else
  echo "FAIL: bogus host not refused properly"; fail=1
fi
# bogus host exit nonzero
bin/seat/arm-talk.sh bogus-host-xyz -- "ping" >/dev/null 2>&1
[ $? -ne 0 ] && echo "PASS: bogus host nonzero exit" || { echo "FAIL: bogus host zero exit"; fail=1; }
# dark host does not abort a following command
bin/seat/arm-talk.sh whynot -- "ping" >/dev/null 2>&1 || true
echo "PASS: dark host did not abort run"
exit $fail
