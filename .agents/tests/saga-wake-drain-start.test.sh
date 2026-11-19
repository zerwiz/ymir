#!/usr/bin/env bash
# saga-wake-drain.sh start — the session start drains what was owed (2026-11-19).
#
# Measured: 31 wakes sat in the queue from 2026-11-17 to 2026-11-19 because the session start only
# counted them. The helm's start now presents every owed wake, writes each to the append-only ledger,
# acknowledges exactly what it presented, and reports. Fenced state: never the operator's queue.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOOR="$ROOT/bin/time/saga-wake-drain.sh"
pass=0; fail=0
ok() { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n       %s\n' "$1" "${2-}"; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export BROKK_STATE_OVERRIDE="$T/state" BROKK_MACHINE_STATE_DIR="$T/machine"
mkdir -p "$BROKK_STATE_OVERRIDE" "$BROKK_MACHINE_STATE_DIR"
Q="$BROKK_STATE_OVERRIDE/.wake-queue"

for i in $(seq 1 31); do printf '17950%05d\t%s\tsignal\tprobe-%s\tsynthetic wake %s\n' "$i" "$i" "$i" "$i" >>"$Q"; done

out="$(bash "$DOOR" start 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "start exits 0" || bad "start exits 0" "rc=$rc"
case "$out" in *"drain: 31 wake(s) were owed at session start"*) ok "the drain line names what was owed" ;;
  *) bad "the drain line names what was owed" "$(printf '%s' "$out" | head -3)" ;; esac
[ "$(printf '%s\n' "$out" | grep -c '^WAKE ')" = 8 ] && ok "eight wakes are shown, the rest are counted" \
  || bad "eight wakes are shown, the rest are counted" "$(printf '%s\n' "$out" | grep -c '^WAKE ')"
case "$out" in *"… and 23 more in the ledger"*) ok "the remainder points at the ledger" ;; *) bad "the remainder points at the ledger" "$out" ;; esac
case "$out" in *"wake queue after the drain: 0 pending"*) ok "the queue is empty after the drain" ;; *) bad "the queue is empty after the drain" "$out" ;; esac
[ ! -s "$Q" ] && ok "the queue file holds nothing" || bad "the queue file holds nothing" "$(wc -l <"$Q")"
[ "$(grep -c '^WAKE ' "$BROKK_STATE_OVERRIDE/wake-ledger.log")" = 31 ] && ok "every presented wake is in the ledger" \
  || bad "every presented wake is in the ledger" "$(grep -c '^WAKE ' "$BROKK_STATE_OVERRIDE/wake-ledger.log" 2>/dev/null)"

# A second start finds nothing owed and says so, and the ledger only grows.
out="$(bash "$DOOR" start 2>&1)"
case "$out" in *"drain: nothing was owed at session start — wake queue: 0 pending"*) ok "a second start owes nothing" ;;
  *) bad "a second start owes nothing" "$out" ;; esac
[ "$(grep -c '^WAKE ' "$BROKK_STATE_OVERRIDE/wake-ledger.log")" = 31 ] && ok "the ledger is never rewritten" || bad "the ledger is never rewritten"

# A wake that lands AFTER the presentation is never eaten by the ack (the ack race).
printf '1795099999\t99\tsignal\tlate\ta late wake\n' >"$Q"
bash "$DOOR" drain >/dev/null 2>&1
printf '1795100000\t100\tsignal\tlater\tan even later wake\n' >>"$Q"
bash "$DOOR" ack >/dev/null 2>&1
grep -q 'an even later wake' "$Q" && ok "a wake after the presentation survives the ack" || bad "a wake after the presentation survives the ack" "$(cat "$Q" 2>/dev/null)"

printf 'saga-wake-drain-start: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
