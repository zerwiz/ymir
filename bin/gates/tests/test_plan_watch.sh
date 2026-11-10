#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
. "$ROOT/bin/vault/hoard-lib.sh" 2>/dev/null || true
[ -n "${YMIR_HOME:-}" ] || ymir_home_root YMIR_HOME
# dry-run prints arithmetic, sends nothing
out=$(bash bin/time/nornir-job-plan-watch.sh --dry-run)
echo "$out" | grep -q "plans:" || { echo "FAIL: no plans line"; exit 1; }
# state file written on real run
bash bin/time/nornir-job-plan-watch.sh >/dev/null 2>&1
[ -f "$YMIR_HOME/state/plan-watch.json" ] || { echo "FAIL: no state file"; exit 1; }
# second run same minute sends no second line
out2=$(bash bin/time/nornir-job-plan-watch.sh)
echo "$out2" | grep -q "plans: unchanged" || { echo "FAIL: not idempotent"; echo "$out2"; exit 1; }
# queue field present and maps red->STALE (verify mapping code)
grep -q '"queue"' "$YMIR_HOME/state/plan-watch.json" || { echo "FAIL: no queue field"; exit 1; }
echo "OK: queue field present"
# install dry-run prints unit+timer
inst=$(bin/time/nornir-job-plan-watch.sh --install --dry-run)
echo "$inst" | grep -q "OnCalendar" || { echo "FAIL: no timer"; exit 1; }
echo "PASS"
