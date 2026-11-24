#!/usr/bin/env bash
# test_arm_wake_harness.sh — plan 369 item 1: a tell says honestly how (and whether) the holder is woken.
# Usage: test_arm_wake_harness.sh · Exit: 0 all pass · 1 a failure.
set -u
HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
ROOT="$(readlink -f "$HERE/../../..")"
DOOR="$ROOT/bin/voice/rodd-arm.sh"
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
STATE="$TMP/state"; mkdir -p "$STATE"
export YMIR_STATE_DIR="$STATE" RODD_ARM_LEASE="$STATE/.arm.lease" BROKK_STATE_OVERRIDE="$STATE"
export HERMES_HOME="$TMP/no-hermes"   # never reach the real gateway from a test
st=$(sed 's/.*) //' /proc/$$/stat | awk '{print $20}')
lease() { printf 'pid=%s starttime=%s gen=3 mode=test role=%s session=none heartbeat=%s state=%s\n' "$$" "$st" "$1" "$(date +%s)" "$STATE" >"$RODD_ARM_LEASE"; }
col() { printf '%s\n' "$1" | awk 'NR==2' | awk -F'","' -v n="$2" '{print $n}' | tr -d '"'; }

printf 'test_arm_wake_harness\n'
for r in claude pi; do
  lease "$r"; out=$(bash "$DOOR" tell "hello $r" 2>&1)
  [ "$(col "$out" 9)" = hook ] && ok "$r holder: shown=hook (its own hook raises the wake)" || bad "$r holder: shown=hook" "$out"
done
lease cursor; out=$(bash "$DOOR" tell "hello cursor" 2>&1)
[ "$(col "$out" 9)" = no ] && ok "a harness with no road says shown=no" || bad "no-road harness says shown=no" "$out"
case "$out" in *"nobody was woken"*) ok "and the road names that nobody was woken" ;; *) bad "road names nobody woken" "$out" ;; esac

lease hermes; out=$(bash "$DOOR" tell "hello hermes" 2>&1)
case "$(col "$out" 9)" in posted|no) ok "hermes holder: shown is posted or no, never hook" ;; *) bad "hermes shown value" "$out" ;; esac
: >"$STATE/.wake-queue"
out=$(bash "$ROOT/bin/voice/hermes-arm-wake.sh" --state "$STATE" 2>&1)
case "$out" in *'"none"'*) ok "hermes-arm-wake: empty queue says none" ;; *) bad "empty queue says none" "$out" ;; esac
out=$(bash "$ROOT/bin/voice/hermes-arm-wake.sh" --state /nonexistent 2>&1); rc=$?
[ "$rc" = 1 ] && ok "hermes-arm-wake: no state dir fails, exit 1" || bad "no state dir fails" "rc=$rc $out"
printf 'test_arm_wake_harness: %s passed, %s failed\n' "$pass" "$fail"; [ "$fail" = 0 ]
