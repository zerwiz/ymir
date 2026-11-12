#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"; cd "$ROOT"
source bin/forge/pr-patterns.sh
fail=0
check() { # label expected rc
  local name="$1"; shift; local exp="$1"; shift
  "$@" >/tmp/out 2>&1; local rc=$?
  if [ "$rc" = "$exp" ]; then echo "PASS: $name (rc=$rc)"; else echo "FAIL: $name (rc=$rc exp=$exp)"; cat /tmp/out; fail=1; fi
}
# complete body passes
cat >/tmp/good.txt <<'B'
house: whynotproductions
fleet: ymir
agent: plan-keeper (role: ship, errand: plan-keeper)
authority: Allfather word
proves: test (PASS)
never: a hostname
B
check "good body" 0 bash bin/forge/pr-open.sh --role plan-keeper --house whynotproductions --fleet ymir --errand plan-keeper --authority "x" --proves "y" --title t --body-file /tmp/good.txt --dry-run
# leaks refused with match named
for leak in "10.0.0.$((4+1))" "box.tail$((0)).ts.net" "/ho""me/example/x" "someone@example.com" "w2:p3" "token: abcdefghijklmnop"; do
  printf 'house: h\nfleet: f\nagent: r (role: ship, errand: r)\nauthority: a\nproves: p\nnever: n\n\n%s\n' "$leak" >/tmp/bad.txt
  out=$(bash bin/forge/pr-open.sh --role r --house h --fleet f --errand r --authority a --proves p --title t --body-file /tmp/bad.txt --dry-run 2>&1); rc=$?
  if [ "$rc" = 3 ]; then echo "PASS: refused $leak"; else echo "FAIL: $leak rc=$rc"; echo "$out"; fail=1; fi
done
# no block refused showing template
printf 'just a body\n' >/tmp/noblock.txt
out=$(bash bin/gates/guards/pr-identity-guard.sh /tmp/noblock.txt 2>&1); rc=$?
# guard local needs pr number; test CI mode instead with fixture
# CI pass fixture
mkdir -p /tmp/fix
cat >/tmp/fix/pass.json <<'J'
{"pull_request":{"body":"house: h\nfleet: f\nagent: r (role: ship, errand: r)\nauthority: a\nproves: p\nnever: n","head":{"ref":"eindri/r"}}}
J
GITHUB_EVENT_PATH=/tmp/fix/pass.json bash bin/gates/guards/pr-identity-guard.sh --ci >/tmp/o 2>&1; rc=$?
if [ "$rc" = 0 ]; then echo "PASS: CI pass"; else echo "FAIL: CI pass rc=$rc"; cat /tmp/o; fail=1; fi
cat >/tmp/fix/fail.json <<'J'
{"pull_request":{"body":"house: h\nfleet: f\nagent: r (role: ship, errand: r)\nauthority: a\nproves: p\nnever: n\n10.0.0.5","head":{"ref":"eindri/r"}}}
J
GITHUB_EVENT_PATH=/tmp/fix/fail.json bash bin/gates/guards/pr-identity-guard.sh --ci >/tmp/o 2>&1; rc=$?
if [ "$rc" != 0 ]; then echo "PASS: CI fail on leak"; else echo "FAIL: CI should fail"; fail=1; fi
# no block CI
cat >/tmp/fix/noblock.json <<'J'
{"pull_request":{"body":"no signature here","head":{"ref":"eindri/r"}}}
J
GITHUB_EVENT_PATH=/tmp/fix/noblock.json bash bin/gates/guards/pr-identity-guard.sh --ci >/tmp/o 2>&1; rc=$?
if [ "$rc" != 0 ]; then echo "PASS: CI no-block fail"; else echo "FAIL: should fail"; fail=1; fi
exit $fail
