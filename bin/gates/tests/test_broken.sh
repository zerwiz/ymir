#!/usr/bin/env bash
set -u
export YMIR_HOME="${YMIR_HOME:-$HOME/Documents/ymirhome}"
F="$YMIR_HOME/hodd/state/broken.md"
rm -f "$F"
BIN="$(cd "$(dirname "$0")/../.." && pwd)/seat/broken.sh"
# add appends
before=0
"$BIN" add --function f1 --shows "cmd1" --state open --closes "proof1" >/dev/null
after=$(wc -l < "$F")
[ "$after" -eq 1 ] || { echo "FAIL: add did not append"; exit 1; }
# close appends, does not rewrite
lines_before=$(wc -l < "$F")
"$BIN" close br-0001 --sha deadbeef >/dev/null
lines_after=$(wc -l < "$F")
[ "$lines_after" -eq $((lines_before+1)) ] || { echo "FAIL: close did not append one line"; exit 1; }
# original line still present
grep -q "^F|br-0001|" "$F" || { echo "FAIL: original finding lost"; exit 1; }
# list --open hides closed
open_out=$("$BIN" list --open)
[ -z "$open_out" ] || { echo "FAIL: list --open shows closed"; exit 1; }
# file never loses a line: total >= 2
[ "$(wc -l < "$F")" -ge 2 ] || { echo "FAIL: line loss"; exit 1; }
rm -f "$F"
echo "PASS: test_broken"