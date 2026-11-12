#!/usr/bin/env bash
# test_eir_mends.sh — the Eir rows that read wrong or looked at the wrong place (2026-11-12).
#   1. the mail desk's default port is the desk's own (8494), not the gimle share port;
#   2. the seats row's detail is one clean sentence, never a half-printed TOON header;
#   3. the claudehooks row names what is stale instead of a fixed sentence when it is red.
# (rodd-arm hold naming the seat and charter is covered in bin/voice/tests/test_rodd_arm.sh.)
# Usage: test_eir_mends.sh      Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
EIR="$HERE/../eir-doctor.sh"
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

grep -q 'GNA_DESK_PORT:-8494' "$EIR" && ok "mail default port is 8494" || bad "mail default port is 8494"
grep -q 'GNA_DESK_PORT:-8490' "$EIR" && bad "no 8490 default remains" || ok "no 8490 default remains"

out="$(bash "$EIR" check 2>/dev/null)"
seats="$(printf '%s\n' "$out" | grep '^  "seats",')"
case "$seats" in
  *'seat-reap['*|*'the seat wireseat'*) bad "the seats detail is clean" "$seats" ;;
  *'the seat wire'*) ok "the seats detail is one clean sentence" ;;
  *) bad "the seats row exists" "$seats" ;;
esac
[ "$(printf '%s\n' "$seats" | wc -l)" = 1 ] && ok "the seats row is one line" || bad "the seats row is one line"
ch="$(printf '%s\n' "$out" | grep '^  "claudehooks",')"
case "$ch" in
  *'"claudehooks","broken","the three Claude hooks'*) bad "a broken claudehooks row names what is stale" "$ch" ;;
  *) ok "claudehooks detail is not the fixed sentence when broken" ;;
esac

printf 'test_eir_mends: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
