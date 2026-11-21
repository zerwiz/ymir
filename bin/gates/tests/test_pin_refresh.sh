#!/usr/bin/env bash
# test_pin_refresh.sh — the pin refresher, and the sentence a failed row gets (plan 292).
#
# The two faults mended on 2026-11-15 are the two this test proves able to fail:
#   1. the heart's pinned runtime stood 75 commits behind main, and the ONLY thing that could refresh it
#      was a copy of itself — so the refresher must refuse when it lives inside the pin;
#   2. a row that was never found (rc 127) and a row that ran and said nothing produced the same words
#      ("no output"), so the sentence must name the path the shell looked for.
#
# Everything runs in a throwaway temp dir with a bare "origin" — no network, no real pin, no systemd.
# Test seams: YMIR_HOME (the config), YMIR_STATE_DIR (the log), YMIR_CRON_FAIL_LIB.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PASS=0; FAIL=0
check() { if [ "$1" = "0" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$2"; fi; }

DOOR="$ROOT/bin/engine/pin-refresh.sh"
LIB="$ROOT/bin/time/cron-fail-lib.sh"
[ -x "$DOOR" ]; check $? "bin/engine/pin-refresh.sh exists and is executable"
[ -r "$LIB" ]; check $? "bin/time/cron-fail-lib.sh exists"

W="$(mktemp -d "${TMPDIR:-/tmp}/pin-refresh-test.XXXXXX")"
trap 'rm -rf "$W"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export YMIR_HOME="$W/home" YMIR_STATE_DIR="$W/state"
mkdir -p "$YMIR_HOME/config" "$YMIR_STATE_DIR"

# ── a tiny world: a bare origin, the pin (a clone of it), and a working tree ─────────────────
git init -q --bare "$W/origin.git"
git clone -q "$W/origin.git" "$W/seed" 2>/dev/null
( cd "$W/seed" && printf 'one\n' > f.txt && git add f.txt && git commit -qm one && git push -q origin HEAD:main )
git --git-dir="$W/origin.git" symbolic-ref HEAD refs/heads/main
git clone -q "$W/origin.git" "$W/pin" 2>/dev/null
git clone -q "$W/origin.git" "$W/tree" 2>/dev/null
printf 'YMIR_RUNTIME_DIR="%s"\nYMIR_RUNTIME_BRANCH="main"\n' "$W/pin" >"$YMIR_HOME/config/runtime.env"

# the door is exercised from the WORKING TREE's copy of itself: copy the two doors it needs there
mkdir -p "$W/tree/bin/engine" "$W/tree/bin/vault"
cp "$DOOR" "$W/tree/bin/engine/pin-refresh.sh"
cp "$ROOT/bin/vault/hoard-lib.sh" "$W/tree/bin/vault/hoard-lib.sh" 2>/dev/null || true
( cd "$W/tree" && git add -A && git commit -qm "the door arrives" )

# 1 · current: exit 0, says so
out="$("$W/tree/bin/engine/pin-refresh.sh" --check --quiet 2>&1)"; rc=$?
[ "$rc" = 0 ]; check $? "a pin at origin/main is current (rc=$rc: $out)"

# 2 · origin moves ahead: --check exits 3 and names the distance
( cd "$W/seed" && printf 'two\n' >>f.txt && git commit -qam two && git push -q origin HEAD:main )
out="$("$W/tree/bin/engine/pin-refresh.sh" --check --quiet 2>&1)"; rc=$?
[ "$rc" = 3 ]; check $? "a pin behind main is red on --check (rc=$rc)"
case "$out" in *behind*) check 0 "the check says how far behind" ;; *) check 1 "the check names the distance: $out" ;; esac

# 3 · the refusal: the same door, run from inside the pin, must not refresh it
mkdir -p "$W/pin/bin/engine"
cp "$W/tree/bin/engine/pin-refresh.sh" "$W/pin/bin/engine/pin-refresh.sh"
out="$( cd "$W/pin" && YMIR_HOME="$YMIR_HOME" YMIR_STATE_DIR="$YMIR_STATE_DIR" bash bin/engine/pin-refresh.sh --quiet 2>&1 )"; rc=$?
[ "$rc" = 4 ]; check $? "the refresher refuses when it lives inside the pin (rc=$rc)"
case "$out" in *inside\ the\ pin*) check 0 "the refusal names the fault" ;; *) check 1 "the refusal explains itself: $out" ;; esac
[ "$(git -C "$W/pin" rev-parse --short HEAD)" = "$(git -C "$W/pin" rev-parse --short origin/main~1)" ] \
  ; check $? "the refused run left the pin where it was"
rm -rf "$W/pin/bin"   # the seated copy goes again: the next checks are about the pin proper

# 3b · THE SCHEDULE'S ROAD (2026-11-20): the scheduler runs FROM the pin, so --auto-tree resolves a tree that
# is not the pin and re-execs ITS copy. Without this the refresher could never be scheduled at all — which is
# why the pin was 182 commits behind while a weekly job measured the distance and nobody moved it.
mkdir -p "$W/pin/bin/engine"
cp "$W/tree/bin/engine/pin-refresh.sh" "$W/pin/bin/engine/pin-refresh.sh"
out="$( cd "$W/pin" && YMIR_HOME="$YMIR_HOME" YMIR_STATE_DIR="$YMIR_STATE_DIR" YMIR_SOURCE_TREE="$W/tree" \
        bash bin/engine/pin-refresh.sh --auto-tree --quiet 2>&1 )"; rc=$?
[ "$rc" = 0 ]; check $? "--auto-tree refreshes from a tree that is not the pin (rc=$rc: $out)"
[ "$(git -C "$W/pin" rev-parse --short HEAD)" = "$(git -C "$W/seed" rev-parse --short HEAD)" ]
check $? "--auto-tree moved the pin to origin/main"
out="$( cd "$W/pin" && YMIR_HOME="$YMIR_HOME" YMIR_STATE_DIR="$YMIR_STATE_DIR" \
        bash bin/engine/pin-refresh.sh --from-tree "$W/pin" --quiet 2>&1 )"; rc=$?
[ "$rc" = 4 ]; check $? "naming the pin itself as the source tree is refused (rc=$rc)"
rm -rf "$W/pin/bin"   # the seated copy goes again

# 4 · the working tree's copy brings it home, once, and logs the move
"$W/tree/bin/engine/pin-refresh.sh" --quiet >"$W/refresh.out" 2>&1; rc=$?
[ "$rc" = 0 ]; check $? "the working tree refreshes the pin (rc=$rc: $(cat "$W/refresh.out"))"
[ "$(git -C "$W/pin" rev-parse --short HEAD)" = "$(git -C "$W/seed" rev-parse --short HEAD)" ] \
  ; check $? "the pin now stands where origin/main stands"
grep -q 'pin-refresh: main' "$YMIR_STATE_DIR/pin-refresh.log" 2>/dev/null
check $? "the move is logged (append-only)"
out="$("$W/tree/bin/engine/pin-refresh.sh" --check --quiet 2>&1)"; rc=$?
[ "$rc" = 0 ]; check $? "and it is current afterwards (rc=$rc)"

# 5 · local edits are reported and never pre-empted, because a seat renders its own agent cards into the
#     tree it runs from — but they are never OVERWRITTEN by a schedule either, and git is the judge of that
printf 'local edit\n' >>"$W/pin/f.txt"          # an edit the incoming commits do not touch
( cd "$W/seed" && printf 'three\n' > g.txt && git add g.txt && git commit -qm three && git push -q origin HEAD:main )
out="$("$W/tree/bin/engine/pin-refresh.sh" --quiet 2>&1)"; rc=$?
[ "$rc" = 0 ]; check $? "an untouched local edit does not block the fast-forward (rc=$rc: $out)"
grep -qx 'local edit' "$W/pin/f.txt"; check $? "…and the local edit survives it"

# 6 · an edit the incoming commits WOULD overwrite: git refuses, the door says so, and nothing is lost
( cd "$W/seed" && printf 'four\n' >>f.txt && git commit -qam four && git push -q origin HEAD:main )
out="$("$W/tree/bin/engine/pin-refresh.sh" --quiet 2>&1)"; rc=$?
[ "$rc" = 5 ]; check $? "a conflicting local edit stops the refresh with rc 5 (rc=$rc)"
grep -qx 'local edit' "$W/pin/f.txt"; check $? "…and the local edit is still there, never overwritten"

# 6 · the sentence a failed row gets
# shellcheck disable=SC1090
. "$LIB"
out="$(cron_fail_detail "$W/home" "bin/records/gimle-tunnels-check.sh --quiet" 127 "")"
case "$out" in *not\ found*"$W/home/bin/records/gimle-tunnels-check.sh"*stale*) check 0 "rc 127 names the path the shell looked for and the tree" ;;
  *) check 1 "rc 127 detail: $out" ;; esac
mkdir -p "$W/home/bin/x"; printf '#!/bin/sh\n' >"$W/home/bin/x/quiet.sh"
out="$(cron_fail_detail "$W/home" "bin/x/quiet.sh" 127 "")"
case "$out" in *not\ found*) check 0 "rc 127 still says not-found when the file appears afterwards" ;; *) check 1 "rc 127 later: $out" ;; esac
out="$(cron_fail_detail "$W/home" "bin/x/quiet.sh" 126 "")"
case "$out" in *not\ executable*) check 0 "rc 126 says not-executable, not not-found" ;; *) check 1 "rc 126: $out" ;; esac
out="$(cron_fail_detail "$W/home" "bin/time/x.sh" 1 "boom: the well is dry")"
case "$out" in *"boom: the well is dry"*) check 0 "a real failure keeps the log's last line" ;; *) check 1 "rc 1: $out" ;; esac
out="$(cron_fail_detail "$W/home" "bin/time/x.sh" 9 "")"
case "$out" in *"no output"*"exited 9"*) check 0 "silent failure names the exit code instead of claiming 'no output'" ;; *) check 1 "silent: $out" ;; esac

# 9 · A PIN THAT IS A LINK TO A RELEASE IS NEVER MERGED IN PLACE (2026-11-20): the dev machine's releases/abefc4f06932 was
# fast-forwarded to 149f38ebd by this door, so the seat ran code its proof never saw under a name that lied.
( cd "$W/seed" && printf 'r\n' >>f.txt && git commit -qam r && git push -q origin HEAD:main )
rsha="$(git --git-dir="$W/origin.git" rev-parse main)"
git clone -q "$W/origin.git" "$W/rel/${rsha:0:12}" 2>/dev/null
ln -s "$W/rel/${rsha:0:12}" "$W/relpin"
printf 'YMIR_RUNTIME_DIR="%s"\nYMIR_RUNTIME_BRANCH="main"\n' "$W/relpin" >"$YMIR_HOME/config/runtime.env"
( cd "$W/seed" && printf 's\n' >>f.txt && git commit -qam s && git push -q origin HEAD:main )
out="$("$W/tree/bin/engine/pin-refresh.sh" --quiet 2>&1)"; rc=$?
[ "$rc" = 6 ]; check $? "a release pin behind main is refused the in-place merge (rc=$rc: $out)"
[ "$(git -C "$W/relpin" rev-parse HEAD)" = "$rsha" ]; check $? "the release still carries the sha it is named for"
git -C "$W/relpin" merge -q --ff-only origin/main
out="$("$W/tree/bin/engine/pin-refresh.sh" --check --quiet 2>&1)"; rc=$?
case "$rc:$out" in 3:*moved-in-place*) check 0 "a release carrying code it is not named for is named moved-in-place" ;; *) check 1 "moved in place: rc=$rc $out" ;; esac

printf 'pin-refresh tests: %d pass, %d fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
