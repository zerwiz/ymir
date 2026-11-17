#!/usr/bin/env bash
# test_arm_send.sh — a tell carries a deadline, and an unacked tell escalates (plan 310 §4).
#
# THE LAW THIS PROVES. A question with no end waits for ever, and an arm that never answered
# looks exactly like an arm that answered late — which is how the heart's tell sat unanswered
# all morning while its arm read `held`. So:
#
#   1 · every tell is stamped with the instant it expires, and the stamp travels INSIDE the
#       line the holder reads (not in a ledger nobody on the far machine opens)
#   2 · the tell is written to the door's own ledger, with its deadline
#   3 · `--pending` shows it while it stands, `--expired` shows it once the deadline passes,
#       and `--expired` exits non-zero — the report IS the escalation
#   4 · `--ack <tell>` closes it, and an acked tell never escalates
#   5 · a tell nobody can take writes NO deadline (nothing was handed over, so nothing is owed)
#   6 · every run uses a TEMPORARY state: the live ledger and the live arm are untouched
#
# Usage: test_arm_send.sh
# Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/fleet/arm-send.sh"

pass=0; fail=0
ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
want_rc() { if [ "$rc" = "$1" ]; then ok "$2"; else bad "$2" "expected rc=$1, got rc=$rc · out=$(printf '%s' "$out" | tail -3 | tr '\n' ' ')"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"
export YMIR_STATE_DIR="$TMP/state"
export YMIR_TELL_DEADLINE=1800
mkdir -p "$YMIR_HOME/hodd/data" "$TMP/state"
printf '{"hosts":{"heimdall":{"user":"probe","tailnet":"probe"}}}\n' >"$YMIR_HOME/hodd/data/fleet.json"
LEDGER="$TMP/state/arm-tells.tsv"
THIS="$(hostname -s)"

run() { out="$(bash "$DOOR" "$@" 2>"$TMP/err")"; rc=$?; err="$(cat "$TMP/err")"; }

printf 'test_arm_send\n'

# ── 1 · a tell nobody can take writes no deadline ──────────────────────────
run "$THIS" "is the desk up?"
want_rc 3 "a tell to a machine with no arm is REFUSED"
case "$out" in *"nobody holds the arm"*) ok "the refusal says nobody holds the arm" ;; *) bad "the refusal says nobody holds the arm" "$out" ;; esac
[ ! -s "$LEDGER" ] && ok "a refused tell writes no ledger row (nothing was handed, nothing is owed)" \
  || bad "a refused tell writes no ledger row" "$(cat "$LEDGER")"

# ── 2 · a tell that lands carries its deadline, inside the line ────────────
printf 'pid=%s starttime=%s gen=1 mode=test session=none heartbeat=%s state=%s\n' \
  "$$" "$(sed 's/.*) //' "/proc/$$/stat" 2>/dev/null | awk '{print $20}')" "$(date +%s)" "$TMP/state" \
  >"$TMP/state/.arm.lease"
run "$THIS" "is the desk up?"
want_rc 0 "a tell to this machine's own arm lands"
case "$out" in *arm-send-tell\[1\]\{tell,deadline*) ok "the door prints the tell's id and its deadline" ;; *) bad "the door prints the tell's id and its deadline" "$out" ;; esac
case "$out" in *'"1800"'*) ok "the deadline is the ONE default window (1800s)" ;; *) bad "the deadline is the ONE default window (1800s)" "$out" ;; esac
[ -s "$LEDGER" ] && ok "the tell is written to the door's own ledger" || bad "the tell is written to the door's own ledger" "no ledger"
[ "$(awk -F'\t' 'NF>=7 {print NF}' "$LEDGER" | head -1)" = 7 ] && ok "a ledger row carries its 7 fields" \
  || bad "a ledger row carries its 7 fields" "$(cat "$LEDGER")"
tell_id="$(awk -F'\t' 'NR==1{print $1}' "$LEDGER")"
deadline="$(awk -F'\t' 'NR==1{print $5}' "$LEDGER")"
[ -n "$deadline" ] && ok "the ledger row carries the deadline" || bad "the ledger row carries the deadline" "$(cat "$LEDGER")"
# the stamp travelled INSIDE the line the holder reads
wake="$TMP/state/.wake-queue"
grep -q "DEADLINE" "$wake" 2>/dev/null && ok "the deadline is stamped in the line the holder reads" \
  || bad "the deadline is stamped in the line the holder reads" "$(cat "$wake" 2>/dev/null)"
grep -q "$tell_id" "$wake" 2>/dev/null && ok "the line carries the tell id, so the answer is one command" \
  || bad "the line carries the tell id" "$(cat "$wake" 2>/dev/null)"

# ── 3 · pending while it stands ────────────────────────────────────────────
run --pending
want_rc 0 "--pending exits 0 while the tell stands"
case "$out" in *'"pending","'"$tell_id"'"'*) ok "--pending names the standing tell" ;; *) bad "--pending names the standing tell" "$out" ;; esac
run --expired
want_rc 0 "--expired exits 0 when nothing has expired"
case "$out" in *'"none"'*) ok "--expired says there is nothing to escalate" ;; *) bad "--expired says there is nothing to escalate" "$out" ;; esac

# ── 4 · past its deadline, it is EXPIRED and the report escalates ──────────
now="$(date +%s)"
awk -F'\t' -v OFS='\t' -v past="$(( now - 60 ))" 'NF>=7 { $5=past } { print }' "$LEDGER" >"$TMP/l" && mv "$TMP/l" "$LEDGER"
run --expired
want_rc 1 "--expired exits non-zero when a tell went unanswered (the escalation)"
case "$out" in *'"EXPIRED","'"$tell_id"'"'*) ok "the tell is reported as EXPIRED, by name" ;; *) bad "the tell is reported as EXPIRED, by name" "$out" ;; esac
case "$out" in *"ESCALATE to the Allfather"*) ok "the summary says what to do with it" ;; *) bad "the summary says what to do with it" "$out" ;; esac
run --pending
case "$out" in *"$tell_id"*) bad "--pending does not show an expired tell as pending" "$out" ;; *) ok "--pending no longer counts an expired tell" ;; esac

# ── 5 · an ack closes it ───────────────────────────────────────────────────
run --ack "$tell_id"
want_rc 0 "--ack on a standing tell succeeds"
case "$out" in *answered*) ok "the ack says it will not escalate" ;; *) bad "the ack says it will not escalate" "$out" ;; esac
[ "$(awk -F'\t' -v id="$tell_id" '$1==id {print $6}' "$LEDGER")" != "-" ] && ok "the ledger records the ack's instant" \
  || bad "the ledger records the ack's instant" "$(cat "$LEDGER")"
run --expired
want_rc 0 "an acked tell never escalates, even past its deadline"
run --ack no-such-tell
want_rc 3 "--ack of a tell that does not exist is refused"

printf 'test_arm_send: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
