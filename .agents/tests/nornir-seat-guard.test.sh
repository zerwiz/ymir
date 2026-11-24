#!/usr/bin/env bash
# nornir-seat-guard.test.sh — a worker seat never starts or stops the house clock; a missing lock dir is named.
set -u
ROOT="$(CDPATH='' command cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CRON="$ROOT/bin/time/nornir-cron-start.sh"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# a dead notify sink: the scheduler reaches send.sh and events-append.sh under its ROOT, so ROOT is a fake
# tree whose send.sh only records the call — this test can never page anyone.
mkdir -p "$W/root/bin/notify" "$W/root/bin/records"
printf '#!/bin/sh\necho "$@" >>"%s/sink"\n' "$W" >"$W/root/bin/notify/send.sh"; chmod +x "$W/root/bin/notify/send.sh"
mkdir -p "$W/seat" "$W/conf" "$W/helm" "$W/xdg/ymir" "$W/st2"
printf '06:00 true\n' >"$W/conf/cron.yaml"
fails=0
chk() { if [ "$2" = "$3" ]; then printf '  %-52s PASS\n' "$1" ; else printf '  %-52s FAIL (want %s got %s)\n' "$1" "$2" "$3"; fails=$((fails+1)); fi; }
seat() { BROKK_ROOT_OVERRIDE="$W/root" XDG_STATE_HOME="$W/xdg" BROKK_MACHINE_STATE_DIR="$W/seat" BROKK_STATE_OVERRIDE="$W/seat" BROKK_CONFIG_OVERRIDE="$W/conf" BROKK_ROLES=dev bash "$CRON" "$@" 2>&1; }
out="$(seat)"
chk "a seat start is refused with a named line" 1 "$(printf '%s' "$out" | grep -c 'worker seat does not start')"
chk "no scheduler pid is written for a seat" 0 "$([ -e "$W/seat/cron.pid" ] && echo 1 || echo 0)"
out="$(seat --stop)"
chk "a seat stop is refused" 1 "$(printf '%s' "$out" | grep -c 'worker seat does not start or stop')"
out="$(BROKK_ROOT_OVERRIDE="$W/root" XDG_STATE_HOME="$W/xdg" BROKK_MACHINE_STATE_DIR="$W/nosuch" BROKK_STATE_OVERRIDE="$W/state" BROKK_CONFIG_OVERRIDE="$W/conf" bash "$CRON" 2>&1)"
chk "a missing lock dir is refused with its reason" 1 "$(printf '%s' "$out" | grep -c 'does not exist')"
chk "and no scheduler is started for it" 0 "$([ -e "$W/state/cron.pid" ] && echo 1 || echo 0)"
out="$(seat --status)"
chk "status is still readable from a seat" 1 "$(printf '%s' "$out" | grep -c '^cron: ')"
# the scheduler body: retiring with no lock must name the lock and never trip on an unset `today`
BROKK_ROOT_OVERRIDE="$W/root" BROKK_CRON_LOCK_GRACE=0 BROKK_CRON_ONCE=1 BROKK_STATE_OVERRIDE="$W/st2" BROKK_MACHINE_STATE_DIR="$W/helm" \
  BROKK_CONFIG_OVERRIDE="$W/conf" BROKK_ROLES=dev bash -c "set -u; bash '$CRON'" >/dev/null 2>&1
sleep 2
chk "a retirement names the lock" 1 "$(grep -c 'cron retired - no live session lock' "$W/st2/cron.log" 2>/dev/null)"
chk "and never says unbound variable" 0 "$(grep -c 'unbound variable' "$W/st2/cron.log" 2>/dev/null)"
chk "the retirement alert hit the dead sink only" 1 "$([ -s "$W/sink" ] && echo 1 || echo 0)"
[ "$fails" = 0 ] && { echo "nornir-seat-guard: PASS"; exit 0; }; echo "nornir-seat-guard: $fails FAILED" >&2; exit 1
