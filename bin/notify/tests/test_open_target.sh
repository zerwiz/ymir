#!/usr/bin/env bash
# test_open_target.sh — every kind of target resolves, and every dead one says so (plan 230 §6).
#
# The door under test is the real `bin/notify/open-target.sh`. Nothing is opened and no toast is
# shown: `--dry-run` and `resolve` are the verbs that answer without touching the desktop, which
# is exactly what a headless seat (the heart, a container) can prove.
#
#   bash bin/notify/tests/test_open_target.sh
# Exit: 0 every proof held · 1 a proof failed.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
DOOR="$ROOT/bin/notify/open-target.sh"

FAILED=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s%s\n' "$1" "${2:+ — $2}"; FAILED=1; }

TMP="$(mktemp -d)"; PID=""
cleanup() { [ -n "$PID" ] && kill "$PID" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT

# a gate stand-in, so the yl: kind is proved against something that really answers
GATE_PORT="$(python3 - <<'PY'
import socket
s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()
PY
)"
( cd "$TMP" && exec python3 -m http.server --bind 127.0.0.1 "$GATE_PORT" >/dev/null 2>&1 ) &
PID=$!
for _ in $(seq 1 60); do curl -s -m 1 -o /dev/null "http://127.0.0.1:$GATE_PORT/" && break; sleep 0.05; done

export YMIR_HLIDSKJALF_PORT="$GATE_PORT"
export YMIR_OPEN_TARGET_DRY=1

printf 'a file\n'
: >"$TMP/note.md"
out="$("$DOOR" resolve file "$TMP/note.md" 2>&1)"; rc=$?
[ "$rc" = 0 ] && pass "an existing file resolves" || fail "an existing file exited $rc" "$out"
case "$out" in *"$TMP/note.md"*) pass "it resolves to the path" ;; *) fail "wrong path" "$out" ;; esac

export YMIR_OPEN_TARGET_FILING=1     # do not bother the hotline from a proof
out="$("$DOOR" resolve file "$TMP/nothing-here.md" 2>&1)"; rc=$?
[ "$rc" = 3 ] && pass "a missing file is refused (exit 3)" || fail "a missing file exited $rc"
case "$out" in *"target missing"*) pass "the refusal says target missing" ;; *) fail "no 'target missing'" "$out" ;; esac

printf 'a plan\n'
out="$("$DOOR" resolve plan 231 2>&1)"; rc=$?
[ "$rc" = 0 ] && pass "plan 231 resolves" || fail "plan 231 exited $rc" "$out"
case "$out" in *plans/231-*.md*) pass "it resolves to the ledger file" ;; *) fail "not the ledger" "$out" ;; esac

out="$("$DOOR" resolve plan 99999 2>&1)"; rc=$?
[ "$rc" = 3 ] && pass "a plan that does not exist is refused"; [ "$rc" = 3 ] || fail "plan 99999 exited $rc"

printf 'a pull request\n'
out="$("$DOOR" resolve pr "https://github.com/zerwiz/ymir/pull/599" 2>&1)"; rc=$?
[ "$rc" = 0 ] && pass "a PR url resolves" || fail "a PR url exited $rc" "$out"
out="$("$DOOR" resolve pr "599" 2>&1)"; rc=$?
[ "$rc" = 3 ] && pass "a bare number is not a PR url" || fail "a bare number exited $rc" "$out"

printf 'a Hlidskjalf route\n'
out="$("$DOOR" resolve yl fleet 2>&1)"; rc=$?
[ "$rc" = 0 ] && pass "a route resolves when the gate answers" || fail "yl: exited $rc" "$out"
case "$out" in *"#/fleet"*) pass "the route rides the gate's port" ;; *) fail "wrong url" "$out" ;; esac

out="$(YMIR_HLIDSKJALF_PORT=9 "$DOOR" resolve yl fleet 2>&1)"; rc=$?
[ "$rc" = 4 ] && pass "a gate that is down is named (exit 4)" || fail "gate down exited $rc"

printf 'the title tells the truth\n'
out="$("$DOOR" toast --title "Meeting digest" --body "3 rows" --dry-run 2>&1)"
case "$out" in *"(no link)"*) pass "a message with no target says (no link)" ;; *) fail "no (no link)" "$out" ;; esac
out="$("$DOOR" toast --title "Digest" --body x --target "file:$TMP/gone.md" --dry-run 2>&1)"
case "$out" in *"(target missing)"*) pass "a message with a dead target says (target missing)" ;; *) fail "no (target missing)" "$out" ;; esac
out="$("$DOOR" toast --title "Digest" --body x --target "file:$TMP/note.md" --dry-run 2>&1)"
case "$out" in *"click=$DOOR"*) pass "a good target carries the click" ;; *) fail "no click" "$out" ;; esac

printf 'opening is a verb, not a hope\n'
out="$("$DOOR" file "$TMP/note.md" 2>&1)"; rc=$?
[ "$rc" = 0 ] && pass "a dry open succeeds" || fail "dry open exited $rc" "$out"
case "$out" in *"would open"*) pass "nothing was actually opened" ;; *) fail "an opener ran" "$out" ;; esac

printf '\n'
[ "$FAILED" = 0 ] && { printf 'open-target: every proof held\n'; exit 0; }
printf 'open-target: a proof FAILED\n'; exit 1
