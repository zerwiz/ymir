#!/usr/bin/env bash
# test_arm_lease.sh — the lease is a FILE, not a feeling (plan 310 §4).
#
# THE LAW THIS PROVES. On 2026-11-17 a claim that LOOKED alive held the heart's arm all
# morning while nothing behind it could answer. So a project's right to spawn hands is a
# row in a file the machine can read, and:
#
#   1 · a grant writes ONE row of exactly the plan's eight columns, and no number is reused
#   2 · a renewal moves the heartbeat and the expiry, and nothing else
#   3 · a dead lease is reclaimed by the MACHINE, WITHOUT ASKING ANYONE (a stopped heartbeat
#       IS the permission) — the row leaves the table and the journal keeps the event
#   4 · a LIVE lease is never reclaimed (that would be theft), and the refusal says so
#   5 · `authority` names the road a spawn may take — the lease, or the machine arm, or
#       nothing at all with the reason printed
#   6 · there is no authority where there is no lease and no arm, so a spawn is refused
#   7 · every run uses a TEMPORARY state: the live table, the live arm and the live lock are
#       never read for a write nor written for a read
#
# Usage: test_arm_lease.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/voice/arm-lease.sh"
LIB="$ROOT/bin/voice/arm-lease-lib.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
want_rc() { if [ "$rc" = "$1" ]; then ok "$2"; else bad "$2" "expected rc=$1, got rc=$rc · out=$(printf '%s' "$out" | head -3 | tr '\n' ' ') · err=$(printf '%s' "$err" | head -2 | tr '\n' ' ')"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
STATE="$TMP/state"; mkdir -p "$STATE"
TABLE="$STATE/.arm.leases"
JOURNAL="$STATE/.arm.leases.log"
# THE SEAM: the door reads its table from YMIR_ARM_LEASE_STATE, so no test can touch the
# live lease of the machine it runs on.
export YMIR_ARM_LEASE_STATE="$STATE"
export YMIR_HOME="$TMP/home"       # no fleet registry: the arm cannot be found here
mkdir -p "$TMP/home/hodd/data" "$TMP/home/state"

run() { out="$(bash "$DOOR" "$@" 2>"$TMP/err")"; rc=$?; err="$(cat "$TMP/err")"; }

printf 'test_arm_lease\n'

# ── 1 · a grant writes one row, in the plan's own shape ─────────────────────
run grant ymir --holder the-foringi
want_rc 0 "a grant succeeds"
case "$out" in *'"1","the-foringi"'*) ok "the row names the lease number and the holder" ;; *) bad "the row names the lease number and the holder" "$out" ;; esac
case "$out" in *lease\[1\]\{n,holder,machine,scope,hands,granted,expires,heartbeat\}*) ok "the row carries the plan's eight columns, in order" ;; *) bad "the row carries the plan's eight columns, in order" "$out" ;; esac
[ "$(awk -F'\t' 'NR==1 && /^#/ {print NF}' "$TABLE")" = 1 ] && ok "the table's header is one comment line" \
  || bad "the table's header is one comment line" "$(head -1 "$TABLE")"
[ "$(awk -F'\t' '!/^#/ && NF {print NF}' "$TABLE" | head -1)" = 8 ] && ok "a row carries exactly 8 fields" \
  || bad "a row carries exactly 8 fields" "$(cat "$TABLE")"
[ "$(awk '!/^#/ && NF' "$TABLE" | awk 'END{print NR}')" = 1 ] && ok "one lease is one row" || bad "one lease is one row" "$(cat "$TABLE")"
scope_dflt="$(awk -F'\t' '!/^#/ {print $4}' "$TABLE")"
[ "$scope_dflt" = ymir ] && ok "the scope is the one that was granted" || bad "the scope is the one that was granted" "$scope_dflt"
hands_dflt="$(awk -F'\t' '!/^#/ {print $5}' "$TABLE")"
[ "$hands_dflt" = "${YMIR_ARM_LEASE_HANDS:-2}" ] && ok "the hands default is ONE constant (2)" || bad "the hands default is ONE constant (2)" "$hands_dflt"
granted_1="$(awk -F'\t' '!/^#/ {print $6}' "$TABLE")"; expires_1="$(awk -F'\t' '!/^#/ {print $7}' "$TABLE")"
[ "$(( expires_1 - granted_1 ))" = "${YMIR_ARM_LEASE_TTL:-3600}" ] && ok "the expiry is the ONE default window (3600s)" \
  || bad "the expiry is the ONE default window (3600s)" "$(( expires_1 - granted_1 ))"

run list
case "$out" in *'"live","1","the-foringi"'*) ok "list reads it back as live" ;; *) bad "list reads it back as live" "$out" ;; esac

# ── 2 · a renewal moves the heartbeat and the expiry, and nothing else ──────
sleep 1
run renew 1
want_rc 0 "a live lease can be renewed"
hb_2="$(awk -F'\t' '!/^#/ {print $8}' "$TABLE")"; expires_2="$(awk -F'\t' '!/^#/ {print $7}' "$TABLE")"
[ "$hb_2" -gt "$granted_1" ] && ok "the heartbeat advanced" || bad "the heartbeat advanced" "was $granted_1, now $hb_2"
[ "$expires_2" -ge "$expires_1" ] && ok "the expiry moved forward" || bad "the expiry moved forward" "was $expires_1, now $expires_2"
[ "$(awk -F'\t' '!/^#/ {print $2}' "$TABLE")" = the-foringi ] && ok "the renewal did not rewrite the holder" \
  || bad "the renewal did not rewrite the holder" "$(cat "$TABLE")"
[ "$(awk '!/^#/ && NF' "$TABLE" | awk 'END{print NR}')" = 1 ] && ok "a renewal adds no row" || bad "a renewal adds no row" "$(cat "$TABLE")"
run renew 99
want_rc 3 "renewing a lease that does not exist is refused (never an invented claim)"

# ── 3 · a live lease is never reclaimed ─────────────────────────────────────
run reclaim 1
want_rc 3 "reclaiming a LIVE lease is refused"
case "$err" in *"would be theft"*) ok "the refusal says why (it would be theft)" ;; *) bad "the refusal says why (it would be theft)" "$err" ;; esac
[ "$(awk '!/^#/ && NF' "$TABLE" | awk 'END{print NR}')" = 1 ] && ok "the live lease is still there" || bad "the live lease is still there" "the row vanished"

# ── 4 · a dead heartbeat is the permission ─────────────────────────────────
now="$(date +%s)"
printf '%s\t%s\theimdall\tymir\t2\t%s\t%s\t%s\n' "7" "the-dead-orchestrator" \
  "$(( now - 7200 ))" "$(( now - 3600 ))" "$(( now - 900 ))" >>"$TABLE"
run list
case "$out" in *'"dead","7"'*) ok "a lease whose heartbeat stopped reads as dead" ;; *) bad "a lease whose heartbeat stopped reads as dead" "$out" ;; esac
case "$out" in *reclaim*) ok "the dead row says how to reclaim it" ;; *) bad "the dead row says how to reclaim it" "$out" ;; esac
run alive 7
want_rc 1 "alive says the dead lease is not live"
run reclaim 7
want_rc 0 "the machine reclaims a dead lease WITHOUT ASKING ANYONE"
case "$out" in *'"7","the-dead-orchestrator"'*) ok "the reclaim names what it took" ;; *) bad "the reclaim names what it took" "$out" ;; esac
[ -z "$(awk -F'\t' '$1==7' "$TABLE")" ] && ok "the reclaimed row left the table" || bad "the reclaimed row left the table" "$(cat "$TABLE")"
grep -q 'reclaim	7	the-dead-orchestrator' "$JOURNAL" 2>/dev/null && ok "the journal KEEPS the reclaim (nothing is ever lost)" \
  || bad "the journal KEEPS the reclaim (nothing is ever lost)" "$(cat "$JOURNAL" 2>/dev/null)"
[ "$(awk '!/^#/ && NF' "$TABLE" | awk 'END{print NR}')" = 1 ] && ok "the live lease was untouched by the reclaim" \
  || bad "the live lease was untouched by the reclaim" "$(cat "$TABLE")"

# ── 5 · a number is never reused ───────────────────────────────────────────
run grant other-project --holder another
want_rc 0 "a second grant succeeds"
case "$out" in *'"8"'*) ok "the new lease is 8, not the reclaimed 7" ;; *) bad "the new lease is 8, not the reclaimed 7" "$out" ;; esac

# ── 6 · the authority a spawn may use, named ───────────────────────────────
# no lease for this scope, no arm on this box → refused, with the reason printed
run authority foreman
want_rc 3 "authority with no lease and no arm is REFUSED"
case "$out" in *'"refused","none"'*) ok "the row says refused, by no source" ;; *) bad "the row says refused, by no source" "$out" ;; esac
case "$err" in *"no live lease for scope 'foreman'"*) ok "the refusal names the scope it looked for" ;; *) bad "the refusal names the scope it looked for" "$err" ;; esac
case "$err" in *help:*) ok "the refusal names the road out" ;; *) bad "the refusal names the road out" "$err" ;; esac
# the same scope, now with a live lease → granted, naming the lease
run grant foreman --holder the-foreman --hands 3
run authority foreman
want_rc 0 "authority with a live lease is GRANTED"
case "$out" in *'"granted","lease"'*) ok "the row names the LEASE as the authority used" ;; *) bad "the row names the LEASE as the authority used" "$out" ;; esac
case "$out" in *"3 hand(s)"*) ok "the row names how many hands it grants" ;; *) bad "the row names how many hands it grants" "$out" ;; esac
# a scope with no lease still gets the arm path considered, and says so
run authority ymir
case "$out" in *'"granted","arm"'*) ok "a machine with a speaking hand grants the ARM, and says it is borrowed" ;; *) ok "no arm on this box: the row says so instead of inventing one" ;; esac

# ── 7 · ranks: who holds what, and that a read-only seat says so ───────────
run ranks
want_rc 0 "ranks answers"
case "$out" in *ranks\{who,rank,machine,scope,hands,standing,proof\}*) ok "the ranks row names its columns" ;; *) bad "the ranks row names its columns" "$out" ;; esac
case "$out" in *"orchestrator"*) ok "the holder of a live lease is rendered as an orchestrator" ;; *) bad "the holder of a live lease is rendered as an orchestrator" "$out" ;; esac
case "$out" in *"the crown"*) ok "the crown has its own row (vacant, and it says so)" ;; *) bad "the crown has its own row (vacant, and it says so)" "$out" ;; esac
case "$out" in *"PROJECT LEASE"*) ok "the one-line rank names the project lease this seat holds" ;; *) bad "the one-line rank names the project lease this seat holds" "$out" ;; esac
# and a machine with NO lease at all says read-only — and keeps the one door a read-only
# agent always has: it may ASK the arm holder (plan 310: a refusal that silences the asking
# would be wrong)
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
out="$(YMIR_ARM_LEASE_STATE="$EMPTY" bash "$DOOR" ranks --line 2>&1)"
case "$out" in *"read-only"*) ok "a seat with no lease on a box with no arm is read-only, and says so" ;; *) bad "a seat with no lease on a box with no arm is read-only, and says so" "$out" ;; esac
case "$out" in *"may still ASK: bin/seat/lock-ask.sh ask"*) ok "a seat with no rank keeps its one door: it may ASK" ;; *) bad "a seat with no rank keeps its one door: it may ASK" "$out" ;; esac

# ── 8 · the live table of this machine was never touched ───────────────────
[ ! -e "$TMP/home/state/.arm.leases" ] && ok "nothing was written outside the temporary state" \
  || bad "nothing was written outside the temporary state" "$(cat "$TMP/home/state/.arm.leases" 2>/dev/null)"

# ── 9 · one writer: two grants in the same second cannot lose each other ───
( bash "$DOOR" grant parallel-a --holder a >/dev/null 2>&1 ) &
( bash "$DOOR" grant parallel-b --holder b >/dev/null 2>&1 ) &
wait
both=0
grep -q 'parallel-a' "$TABLE" && both=$((both + 1))
grep -q 'parallel-b' "$TABLE" && both=$((both + 1))
[ "$both" = 2 ] && ok "two grants at once both land (one writer, one lock)" || bad "two grants at once both land (one writer, one lock)" "$(cat "$TABLE")"
[ "$(awk -F'\t' '!/^#/ {print $1}' "$TABLE" | sort -n | uniq -d | wc -l | tr -d ' ')" = 0 ] && ok "no two leases carry the same number" \
  || bad "no two leases carry the same number" "$(cat "$TABLE")"

printf 'test_arm_lease: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
