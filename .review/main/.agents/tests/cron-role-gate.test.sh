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
# The role gate AFTER the time — the parsed shape the loop always accepted.
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

# The role gate BEFORE the time — the shape the home's config/cron.yaml writes
# (@heart 06:00 bin/...). The 2026-09-24 fault: only the after-time shape
# parsed, so every role-first line was silently DEAD while still counted as
# declared. Both orders are the one gate now (plan 54).
rm -f "$TMP"/*.ran
cat >"$TMP/config/cron.yaml" <<EOF
@heart $now touch $TMP/rolefirst-heart.ran
@dev $now touch $TMP/rolefirst-dev.ran
$now touch $TMP/rolefirst-any.ran
EOF

BROKK_STATE_OVERRIDE="$TMP/state2" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  BROKK_CONFIG_OVERRIDE="$TMP/config" BROKK_ROLES=dev BROKK_ROOT_OVERRIDE="$ROOT" \
  timeout 8 bash "$CRON" >/dev/null 2>&1
sleep 6

[ -f "$TMP/rolefirst-dev.ran" ] && ok "a role-first dev job runs on a dev box" || bad "role-first dev job did not run"
[ -f "$TMP/rolefirst-any.ran" ] && ok "a role-first ungated job runs on any role" || bad "role-first ungated job did not run"
[ ! -f "$TMP/rolefirst-heart.ran" ] && ok "a role-first @heart job does NOT run on a dev box" || bad "a role-first @heart job RAN on a dev box"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
