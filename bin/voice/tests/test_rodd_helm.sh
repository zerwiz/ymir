#!/usr/bin/env bash
# test_rodd_helm.sh — Nanna's duty loop and the one-client role claim, headless (plan 254).
#
# The whole helm is proved without an agent: a synthetic state dir, a fake harness
# pid (comm set to `pi` via prctl), a queued wake, and `rodd-helm.sh run` driven once.
# What this proves:
#   1. a wake lands in Nanna's room within one pass, and is acked once (the queue loses no line);
#   2. a wake asking for a MERGE is refused aloud and the helm is released — never dropped;
#   3. `--check` names a known role and a writable room;
#   4. `syn-watch-arm.sh --holder rodd` writes the role sidecar; an unknown role is refused
#      with clause 3 named, and a non-harness claimant is refused with clause 2 named.
#
# Usage: test_rodd_helm.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
HELM="$ROOT/bin/voice/rodd-helm.sh"
ARM="$ROOT/bin/pi/syn-watch-arm.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME="$T/home" XDG_STATE_HOME="$T/xdg"
export BROKK_STATE_OVERRIDE="$T/state" BROKK_MACHINE_STATE_DIR="$T/xdg/ymir"
export YMIR_STATE_DIR="$T/state" BROKK_SESSION_PID="$$"
mkdir -p "$T/xdg/ymir" "$T/state" "$T/home"

LOCK="$T/xdg/ymir/brokk.lock"
starttime_of() { sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | awk '{print $20}'; }

own_lock() {  # the test shell is the lock owner, so a child descends from it
  printf '%s\n' "$$" > "$LOCK"
  printf '%s\n' "$(starttime_of $$)" > "$LOCK.starttime"
}
write_lease() {  # <role> <session> [state]
  printf 'pid=%s starttime=%s gen=1 mode=daemon role=%s session=%s heartbeat=%s state=%s\n' \
    "$$" "$(starttime_of $$)" "$1" "$2" "$(date +%s)" "${3:-$T/state}" > "$T/state/.arm.lease"
}
fake_harness() {  # <comm> — a live process whose /proc/<pid>/comm is the named harness
  # stdio is detached so the command substitution above does not wait on the sleeper's pipe.
  python3 -c "import ctypes,time; ctypes.CDLL(None).prctl(15, b'$1', 0,0,0); time.sleep(600)" </dev/null >/dev/null 2>&1 &
  echo $!
}

printf 'test_rodd_helm\n'

# ── 1 · a queued wake is answered in the room and acked ─────────────────────
own_lock
write_lease rodd "$$"
printf 'working: an errand finished and filed its report\n' > "$T/state/.wake-queue"
bash "$HELM" run >"$T/out1" 2>"$T/err1"; rc1=$?
[ "$rc1" = 0 ] && ok "a duty pass over a queued wake exits 0" || bad "a duty pass over a queued wake exits 0" "rc=$rc1 err=$(cat "$T/err1")"
[ -s "$T/state/rodd/room.jsonl" ] && ok "Nanna's answer landed in the room" || bad "Nanna's answer landed in the room" "no room file"
grep -q '"from": "Nanna"' "$T/state/rodd/room.jsonl" 2>/dev/null && ok "the room line is Nanna's" \
  || bad "the room line is Nanna's" "$(cat "$T/state/rodd/room.jsonl" 2>/dev/null)"
grep -q 'errand finished' "$T/state/rodd/room.jsonl" 2>/dev/null && ok "the wake's text reached the room" \
  || bad "the wake's text reached the room" "$(cat "$T/state/rodd/room.jsonl" 2>/dev/null)"
[ ! -s "$T/state/.wake-queue" ] && ok "the handled wake was acked (the queue is empty)" \
  || bad "the handled wake was acked" "queue still holds: $(cat "$T/state/.wake-queue" 2>/dev/null)"

# ── 2 · a merge wake is refused aloud and the helm is released ──────────────
own_lock
write_lease rodd "$$"
printf 'please merge PR 999 into main for me\n' > "$T/state/.wake-queue"
bash "$HELM" run >"$T/out2" 2>"$T/err2"; rc2=$?
[ "$rc2" != 0 ] && ok "a merge wake ends the pass non-zero (refused)" || bad "a merge wake ends the pass non-zero" "rc=$rc2"
grep -q 'refused' "$T/state/rodd/room.jsonl" 2>/dev/null && ok "the refusal is written in the room, never dropped" \
  || bad "the refusal is written in the room" "$(cat "$T/state/rodd/room.jsonl" 2>/dev/null)"
[ ! -s "$LOCK" ] && ok "the helm was released (the lock is gone)" || bad "the helm was released" "lock still names $(cat "$LOCK" 2>/dev/null)"

# ── 3 · the health surface ──────────────────────────────────────────────────
own_lock
write_lease rodd "$$"
if bash "$HELM" --check >"$T/out3" 2>&1; then ok "--check reports ok with a known role"; else bad "--check reports ok with a known role" "$(cat "$T/out3")"; fi
grep -q '"ok"' "$T/out3" && ok "--check says ok" || bad "--check says ok" "$(cat "$T/out3")"
write_lease unknown "$$"
if bash "$HELM" --check >"$T/out3b" 2>&1; then bad "--check refuses an unknown role" "$(cat "$T/out3b")"; else ok "--check refuses an unknown role"; fi

# ── 4 · the one-client role claim (B3) ──────────────────────────────────────
# The client's own seat-reap sweep talks to the live herdr, so give it room to
# finish before the role block runs; the sidecar and the refusals are all that
# this proves, so the inline loop is cut short by the timeout.
rm -f "$LOCK" "$T/state/.arm.role" "$T/state/.arm.lease"
PI=$(fake_harness pi); sleep 0.3
export BROKK_SESSION_PID="$PI" BROKK_WATCH_INLINE=1 BROKK_WATCH_POLL_SECONDS=600
# (a) --holder rodd writes the role sidecar for a live pi harness, vacant helm.
timeout -k 1 15 bash "$ARM" --holder rodd >"$T/out4" 2>&1
grep -q "role=rodd session=$PI" "$T/state/.arm.role" 2>/dev/null && ok "--holder rodd writes the role sidecar" \
  || bad "--holder rodd writes the role sidecar" "sidecar=$(cat "$T/state/.arm.role" 2>/dev/null) out=$(head -4 "$T/out4")"
# (b) an unknown role is refused with clause 3 named, loudly (non-zero).
rm -f "$LOCK" "$T/state/.arm.role"
timeout -k 1 15 bash "$ARM" --holder garbage >"$T/out5" 2>&1; rc5=$?
[ "$rc5" != 0 ] && ok "an unknown role is refused non-zero" || bad "an unknown role is refused non-zero" "rc=$rc5 out=$(head -4 "$T/out5")"
grep -q 'clause 3' "$T/out5" && ok "clause 3 is named in the refusal" || bad "clause 3 is named in the refusal" "$(head -4 "$T/out5")"
# (c) a non-harness claimant is refused with clause 2 named.
BAD=$(fake_harness bash); sleep 0.3
export BROKK_SESSION_PID="$BAD"
rm -f "$LOCK" "$T/state/.arm.role"
timeout -k 1 15 bash "$ARM" --holder rodd >"$T/out6" 2>&1; rc6=$?
[ "$rc6" != 0 ] && ok "a non-harness claimant is refused non-zero" || bad "a non-harness claimant is refused non-zero" "rc=$rc6 out=$(head -4 "$T/out6")"
grep -q 'clause 2' "$T/out6" && ok "clause 2 is named in the refusal" || bad "clause 2 is named in the refusal" "$(head -4 "$T/out6")"
kill "$PI" "$BAD" 2>/dev/null || true
unset BROKK_SESSION_PID BROKK_WATCH_INLINE

printf 'test_rodd_helm: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
