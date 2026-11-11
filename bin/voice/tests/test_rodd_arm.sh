#!/usr/bin/env bash
# test_rodd_arm.sh — Rödd may knock on the arm, and only on a LIVE arm: the whole point of
# the door is that it refuses when nobody is holding (plan 223).
#
# The laws this proves, each with a command:
#
#   1. no lease            → `tell` refuses with exit 3 and writes NOTHING (the false green
#                            this house keeps paying for: a voice that says "sent" to nobody)
#   2. a dead pid          → still no arm; a leftover lease cannot be mistaken for a holder
#   3. a stale heartbeat   → still no arm; freshness is the watcher's own threshold
#   4. a live lease        → the wake lands in the LEASE's queue (never a hardcoded state),
#                            one line per message, text intact, key `rodd-<epoch>`
#   5. a state dir the lease does not name → refused, never created
#   6. hear                → reads the arm's own room, advances a cursor, deletes nothing
#
# The door's own `--self-test` covers the same ground with a synthetic seat; this file is the
# independent judge, run by CI (`bin/gates/ci-verify.sh`), so a door that lies to itself is
# caught by a caller that does not share its assumptions.
#
# Usage: test_rodd_arm.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/voice/rodd-arm.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
want_rc() { if [ "$rc" = "$1" ]; then ok "$2"; else bad "$2" "expected rc=$1, got rc=$rc · out=$(printf '%s' "$out" | head -2 | tr '\n' ' ') · err=$(printf '%s' "$err" | head -1)"; fi; }
starttime_of() { sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | awk '{print $20}'; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
STATE="$TMP/state"
LEASE="$STATE/.arm.lease"
mkdir -p "$STATE"
export YMIR_STATE_DIR="$STATE"
export RODD_ARM_LEASE="$LEASE"
export BROKK_WATCH_HEARTBEAT_STALE_SECONDS="${BROKK_WATCH_HEARTBEAT_STALE_SECONDS:-60}"

run() { out="$(bash "$DOOR" "$@" 2>"$TMP/err")"; rc=$?; err="$(cat "$TMP/err")"; }
write_lease() {  # <pid> <heartbeat> [state]
  printf 'pid=%s starttime=%s gen=3 mode=test session=none heartbeat=%s state=%s\n' \
    "$1" "$(starttime_of "$1")" "$2" "${3:-$STATE}" >"$LEASE"
}

printf 'test_rodd_arm\n'

# ── 1 · no lease ──────────────────────────────────────────────────────────────
run who
want_rc 3 "who with no lease exits 3"
case "$out" in *"no arm is held"*) ok "who with no lease says 'no arm is held'" ;; *) bad "who with no lease says 'no arm is held'" "$out" ;; esac

run tell "the window is too wide"
want_rc 3 "tell REFUSES with no lease"
[ ! -e "$STATE/.wake-queue" ] && ok "a refused tell writes no queue" || bad "a refused tell writes no queue" "$(cat "$STATE/.wake-queue")"

# ── 2 · a lease naming a dead process ─────────────────────────────────────────
write_lease 999999 "$(date +%s)"
run tell "nobody home"
want_rc 3 "a dead pid is not an arm"

# ── 3 · a stale heartbeat ─────────────────────────────────────────────────────
write_lease "$$" "$(( $(date +%s) - 3600 ))"
run who
want_rc 3 "a stale heartbeat is not an arm"

# ── 4 · a live arm: the queue the LEASE names ─────────────────────────────────
write_lease "$$" "$(date +%s)"
run who
want_rc 0 "a live lease exits 0"
case "$out" in *"$STATE"*) ok "who names the lease's state dir" ;; *) bad "who names the lease's state dir" "$out" ;; esac

run tell "$(printf 'hand this\ton\nwith a tab')"
want_rc 0 "tell hands the message over"
[ -s "$STATE/.wake-queue" ] && ok "the wake landed in the lease's queue" || bad "the wake landed in the lease's queue" "no queue at $STATE/.wake-queue"
if [ -s "$STATE/.wake-queue" ]; then
  line="$(cat "$STATE/.wake-queue")"
  [ "$(awk 'END{print NR}' "$STATE/.wake-queue")" = 1 ] && ok "one wake is one line" || bad "one wake is one line" "$line"
  [ "$(printf '%s' "$line" | awk -F'\t' '{print NF}')" = 5 ] && ok "the message's tabs did not become fields" \
    || bad "the message's tabs did not become fields" "$(printf '%s' "$line" | cat -A)"
  [ "$(printf '%s' "$line" | cut -f3)" = signal ] && ok "the wake's kind is signal" || bad "the wake's kind is signal" "$line"
  case "$(printf '%s' "$line" | cut -f4)" in rodd-*) ok "the wake's key is rodd-<epoch>" ;; *) bad "the wake's key is rodd-<epoch>" "$line" ;; esac
  case "$(printf '%s' "$line" | cut -f5)" in *Rödd*) ok "the wake names Rödd" ;; *) bad "the wake names Rödd" "$line" ;; esac
  case "$(printf '%s' "$line" | cut -f5)" in *"hand this on with a tab"*) ok "the text survives, flattened" ;; *) bad "the text survives, flattened" "$line" ;; esac
fi
run tell "and a second"
[ "$(awk 'END{print NR}' "$STATE/.wake-queue")" = 2 ] && ok "a second tell does not overwrite the first" \
  || bad "a second tell does not overwrite the first" "$(cat "$STATE/.wake-queue")"

# ── 5 · a state dir the lease does not name ───────────────────────────────────
write_lease "$$" "$(date +%s)" "$TMP/not-there"
run tell "nowhere"
want_rc 3 "a state dir the lease does not name is refused"
[ ! -d "$TMP/not-there" ] && ok "the door invented no state dir" || bad "the door invented no state dir" "$TMP/not-there exists"
write_lease "$$" "$(date +%s)"

# ── 6 · hear: the arm's room, a cursor, and nothing deleted ───────────────────
run hear
want_rc 0 "hear with no replies yet exits 0"
[ ! -s "$STATE/rodd/room.jsonl" ] && ok "hear created no room of its own" || bad "hear created no room of its own" "a room appeared"

mkdir -p "$STATE/rodd"
printf '%s\n' '{"ts":"2026-11-08T21:20:00Z","from":"hoenir","text":"narrow it, then re-run"}' >"$STATE/rodd/room.jsonl"
before="$(cksum <"$STATE/rodd/room.jsonl")"
run hear
want_rc 0 "hear reads the arm's reply"
case "$out" in *"narrow it, then re-run"*) ok "the reply's text is readable" ;; *) bad "the reply's text is readable" "$out" ;; esac
[ "$(cksum <"$STATE/rodd/room.jsonl")" = "$before" ] && ok "reading changed nothing in the room" || bad "reading changed nothing in the room" "the room was modified"
[ -s "$STATE/rodd/.cursor" ] && ok "the cursor was advanced" || bad "the cursor was advanced" "no cursor file"
run hear
case "$out" in *"narrow it, then re-run"*) bad "a heard reply is not repeated" "$out" ;; *) ok "a heard reply is not repeated" ;; esac
[ "$(awk 'END{print NR}' "$STATE/rodd/room.jsonl")" = 1 ] && ok "the reply is still in the room" || bad "the reply is still in the room" "the room lost a line"

# ── 7 · the door's own word on itself ─────────────────────────────────────────
if out="$(bash "$DOOR" --self-test 2>&1)"; then ok "the door's --self-test passes"
else bad "the door's --self-test passes" "$(printf '%s' "$out" | grep -E '^  (FAIL|rodd-arm self-test)' | head -5 | tr '\n' ' ')"; fi

# ── 8 · the lease names the holder's role (plan 254 B1) ──────────────────────
printf 'pid=%s starttime=%s gen=3 mode=test role=rodd session=none heartbeat=%s state=%s\n' \
  "$$" "$(starttime_of "$$")" "$(date +%s)" "$STATE" >"$LEASE"
run who
want_rc 0 "who with a role=rodd lease exits 0"
case "$out" in *'"rodd"'*) ok "who reads the role from the lease" ;; *) bad "who reads the role from the lease" "$out" ;; esac
run --check
case "$out" in *'"rodd"'*) ok "--check reads the role too" ;; *) bad "--check reads the role too" "$out" ;; esac
write_lease "$$" "$(date +%s)"
run who
case "$out" in *'"unknown"'*) ok "who reads role=unknown when the lease carries none" ;; *) bad "who reads role=unknown when the lease carries none" "$out" ;; esac

# ── 9 · hold and release (plan 254 B5) ────────────────────────────────────────
export BROKK_MACHINE_STATE_DIR="$TMP/lockdir" BROKK_SESSION_PID="$$"
mkdir -p "$BROKK_MACHINE_STATE_DIR"
run_hold() { out="$(bash "$DOOR" hold 2>"$TMP/err")"; rc=$?; err="$(cat "$TMP/err")"; }
run_release() { out="$(bash "$DOOR" release 2>"$TMP/err")"; rc=$?; err="$(cat "$TMP/err")"; }

run_hold
want_rc 0 "hold on a vacant helm exits 0"
[ -s "$BROKK_MACHINE_STATE_DIR/brokk.lock" ] && ok "hold took the lock" || bad "hold took the lock" "no lock at $BROKK_MACHINE_STATE_DIR"
grep -q 'role=rodd session=' "$STATE/.arm.role" 2>/dev/null && ok "hold wrote the role sidecar" \
  || bad "hold wrote the role sidecar" "$(cat "$STATE/.arm.role" 2>/dev/null)"
grep -q 'hold: Rödd takes the helm' "$STATE/rodd/room.jsonl" 2>/dev/null && ok "hold announced the handover in the room" \
  || bad "hold announced the handover in the room" "$(cat "$STATE/rodd/room.jsonl" 2>/dev/null)"

run_release
want_rc 0 "release gives the helm back"
[ ! -s "$BROKK_MACHINE_STATE_DIR/brokk.lock" ] && ok "release dropped the lock" || bad "release dropped the lock" "lock still names $(cat "$BROKK_MACHINE_STATE_DIR/brokk.lock" 2>/dev/null)"
[ ! -e "$STATE/.arm.role" ] && ok "release cleared the role sidecar" || bad "release cleared the role sidecar" "sidecar still present"
grep -q 'release: Rödd gives the helm back' "$STATE/rodd/room.jsonl" 2>/dev/null && ok "release announced the handover" \
  || bad "release announced the handover" "$(cat "$STATE/rodd/room.jsonl" 2>/dev/null)"

bash -c 'sleep 600' & other=$!
printf '%s\n' "$other" > "$BROKK_MACHINE_STATE_DIR/brokk.lock"
run_hold
want_rc 3 "hold on a live holder refuses with the holder named"
case "$err" in *"held by another live session"*) ok "the refusal names the holder" ;; *) bad "the refusal names the holder" "$err" ;; esac
kill "$other" 2>/dev/null || true
unset BROKK_MACHINE_STATE_DIR BROKK_SESSION_PID

printf 'test_rodd_arm: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
