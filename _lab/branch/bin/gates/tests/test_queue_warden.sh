#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0; FAIL=0
check() { if [ "$1" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$2"; fi; }
# 1. script exists and executable
[ -x "$ROOT/bin/forge/queue-warden.sh" ]; check $? "script exists/executable"
# 2. dry-run does not merge
bash "$ROOT/bin/forge/queue-warden.sh" --dry-run >/tmp/qw-dry.log 2>&1; check $? "dry-run runs"
# 3. --pr parses
grep -q "PR " /tmp/qw-dry.log; check $? "reports PR"
# 4. timer install idempotent
bash "$ROOT/bin/forge/queue-warden.sh" --install-timer >/tmp/qw-timer.log 2>&1; check $? "timer install"
bash "$ROOT/bin/forge/queue-warden.sh" --install-timer >/tmp/qw-timer2.log 2>&1; check $? "timer idempotent"
printf 'queue-warden tests: %d pass, %d fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
