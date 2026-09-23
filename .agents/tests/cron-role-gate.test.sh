#!/usr/bin/env bash
# cron-role-gate.test.sh — a machine runs only the jobs its ROLES own.
# Plan 51 P4: the record jobs belong to the heart, the model jobs to the forge,
# and a dev body runs neither — the leak that left 8 orphan seat schedulers.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CRON="$ROOT/bin/nornir-cron-start.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/state" "$TMP/machine" "$TMP/config"
printf '%s\n' "$$" >"$TMP/machine/brokk.lock"      # a live session lock, so the loop does not retire

now="$(date +%H:%M)"
cat >"$TMP/config/cron.yaml" <<EOF
$now @heart touch $TMP/heart.ran
$now @forge touch $TMP/forge.ran
$now @dev touch $TMP/dev.ran
$now touch $TMP/any.ran
EOF

BROKK_STATE_OVERRIDE="$TMP/state" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  BROKK_CONFIG_OVERRIDE="$TMP/config" BROKK_ROLES=dev BROKK_ROOT_OVERRIDE="$ROOT" \
  timeout 8 bash "$CRON" >/dev/null 2>&1
sleep 6

[ -f "$TMP/dev.ran" ] && ok "a dev job runs on a dev box" || bad "dev job did not run"
[ -f "$TMP/any.ran" ] && ok "an ungated job runs on any role" || bad "ungated job did not run"
[ ! -f "$TMP/heart.ran" ] && ok "a @heart job does NOT run on a dev box" || bad "a @heart job RAN on a dev box"
[ ! -f "$TMP/forge.ran" ] && ok "a @forge job does NOT run on a dev box" || bad "a @forge job RAN on a dev box"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
