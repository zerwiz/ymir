#!/usr/bin/env bash
# cron-one-loop-per-machine.test.sh — the schedule is the MACHINE's, so the loop is too.
#
# The fault this pins (heimdall, 2026-09-28 — the smoke test's `cron-leak`): the
# keep-one-loop guard was keyed on the SEAT's state dir, so five seats on one
# machine started five schedulers, and every ungated job in the machine's schedule
# ran once per scheduler. `--status` then read "running" in every seat while the
# machine was, in truth, running the same crontab five times.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CRON="$ROOT/bin/nornir-cron-start.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/stateA" "$TMP/stateB" "$TMP/machine" "$TMP/config"
printf '%s\n' "$$" >"$TMP/machine/brokk.lock"     # a live session lock, so the loop does not retire

now="$(date +%H:%M)"
cat >"$TMP/config/cron.yaml" <<EOF
$now @dev touch $TMP/ran
EOF

start() {  # <state-dir>
  BROKK_STATE_OVERRIDE="$1" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
  BROKK_CONFIG_OVERRIDE="$TMP/config" BROKK_ROLES=dev BROKK_ROOT_OVERRIDE="$ROOT" \
    bash "$CRON" 2>/dev/null
}

outA="$(start "$TMP/stateA")"
case "$outA" in *"started pid="*) ok "the first seat starts the loop  [$outA]" ;; *) bad "first seat did not start: $outA" ;; esac
sleep 1

outB="$(start "$TMP/stateB")"
case "$outB" in
  *"running pid="*) ok "a SECOND seat reuses the machine's loop, starting nothing  [$outB]" ;;
  *)                bad "a second seat started a duplicate: $outB" ;;
esac

pids="$(pgrep -f "$TMP/config/cron.yaml" 2>/dev/null | wc -l | tr -d ' ')"
[ "$pids" = "1" ] && ok "exactly one loop runs for the machine (1)" || bad "expected 1 loop, found $pids"

# The second seat can stop it, and both seat pid files are cleared.
BROKK_STATE_OVERRIDE="$TMP/stateB" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
BROKK_CONFIG_OVERRIDE="$TMP/config" BROKK_ROLES=dev BROKK_ROOT_OVERRIDE="$ROOT" \
  bash "$CRON" --stop >/dev/null 2>&1 || true
sleep 1
left="$(pgrep -f "$TMP/config/cron.yaml" 2>/dev/null | wc -l | tr -d ' ')"
[ "$left" = "0" ] && ok "--stop from any seat stops the machine's loop" || bad "loop survived --stop ($left)"
[ ! -e "$TMP/machine/cron.pid" ] && ok "the machine pid file is cleared" || bad "machine pid file left behind"

# And a seat still reports "stopped" rather than a phantom pid.
st="$(BROKK_STATE_OVERRIDE="$TMP/stateA" BROKK_MACHINE_STATE_DIR="$TMP/machine" \
      BROKK_CONFIG_OVERRIDE="$TMP/config" BROKK_ROLES=dev BROKK_ROOT_OVERRIDE="$ROOT" \
      bash "$CRON" --status 2>/dev/null)"
case "$st" in *"stopped"*) ok "--status reads stopped after the stop  [$st]" ;; *) bad "--status disagrees: $st" ;; esac

if [ "$fail" = 0 ]; then printf '\nall cron-one-loop-per-machine tests passed\n'
else printf '\ncron-one-loop-per-machine tests FAILED\n' >&2; fi
exit "$fail"
