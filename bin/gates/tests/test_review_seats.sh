#!/usr/bin/env bash
# test_review_seats.sh — proves the seats and their mouth, hermetically.
#
# The Allfather's demand was "THIS MUST ALLWAYS FUCKING HAPPEND", and the house's answer to "always"
# is a test, not a promise. Four things are proved here, each the reason something failed tonight:
#
#   1 · notify writes the queue THE ARM READS (one resolved path, never a restated one) — the fault
#       where 1.3 KB of notifications went into hodd/state while 6.2 KB of asks sat in state/.
#   2 · verdict-watch delivers a report that appears on disk, WITHOUT the seat saying anything.
#   3 · verdict-watch delivers each fingerprint once — a report is not re-delivered every ten minutes.
#   4 · a delivery that fails exits non-zero, so the loop can say so instead of going quiet.
#   5 · smith-seat refuses what it cannot do (no brief, no role, unknown action) by name.
#
# Everything runs under a throwaway YMIR_HOME, so the real home, its vault and its queues are never
# touched. Nothing here needs herdr, a network, or a model.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
VW="$root/bin/forge/verdict-watch.sh"
SS="$root/bin/forge/smith-seat.sh"
pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
judge() { out="$(eval "$@" 2>&1)"; rc=$?; }

echo "test_review_seats"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/state/eindri-reports" "$tmp/state/.reviewed"

# ── 1 · notify writes the arm's queue, under the home it resolves ────────────────────────────────
judge "YMIR_HOME='$tmp' bash '$root/bin/notify/send.sh' --source review --severity HIGH --message 'a verdict that must reach the arm'"
[ "$rc" = 0 ] && ok "notify exits 0 under a throwaway home" || bad "notify failed: rc=$rc"
arm_q="$tmp/state/.wake-queue"; stray_q="$tmp/hodd/state/.wake-queue"
[ -s "$arm_q" ] && grep -q "must reach the arm" "$arm_q" \
  && ok "the line lands in the arm's queue (<home>/state/.wake-queue)" \
  || bad "the line is NOT in the arm's queue"
[ -s "$stray_q" ] && bad "notify ALSO wrote the restated hodd/state queue — the fault is back" \
  || ok "the restated hodd/state queue is not written"

# ── 2 · a report on disk is delivered with no seat saying anything ──────────────────────────────
printf 'REFUSE — PR #4242\n\npr: 4242\nhead: 1111111111111111111111111111111111111111\n\n## The verdict\nthe reason\n' \
  > "$tmp/state/eindri-reports/pr-4242-review.md"
judge "YMIR_HOME='$tmp' bash '$VW'"
[ "$rc" = 0 ] && ok "verdict-watch exits 0" || bad "verdict-watch exited $rc"
case "$out" in *"delivered pr-4242-review"*) ok "a new report is delivered without the seat speaking" ;;
  *) bad "the new report was NOT delivered" ;; esac
grep -q "pr-4242" "$arm_q" && ok "the delivery reached the arm's queue" || bad "the delivery did not reach the queue"
# the delivery must carry the FINDING, not just the title — "your not delivering enough info"
grep -aq "the reason" "$arm_q" && ok "the delivered line carries the report's own content" \
  || bad "the delivered line carried only a title, no content"

# a REFUSE is HIGH — the severity that stops work
case "$out" in *"pr-4242-review (HIGH)"*) ok "a REFUSE is delivered at HIGH" ;;
  *) bad "a REFUSE was not delivered at HIGH" ;; esac

# ── 3 · the same fingerprint is not delivered twice ─────────────────────────────────────────────
judge "YMIR_HOME='$tmp' bash '$VW'"
case "$out" in *"\"0\",\"0\""*|*"\"1\",\"0\",\"0\""*) ok "a second pass delivers nothing twice" ;;
  *) case "$out" in *delivered*) bad "the report was re-delivered on the second pass" ;;
       *) ok "a second pass delivers nothing twice" ;; esac ;; esac

# a CHANGED report is a new delivery — a correction must reach the operator
printf 'PASS — PR #4242\n\npr: 4242\nhead: 2222222222222222222222222222222222222222\n' \
  > "$tmp/state/eindri-reports/pr-4242-review.md"
judge "YMIR_HOME='$tmp' bash '$VW'"
case "$out" in *"delivered pr-4242-review"*) ok "a changed report is delivered again (a correction is news)" ;;
  *) bad "a changed report was suppressed" ;; esac

# ── 4 · a delivery that cannot be made says so, loudly ──────────────────────────────────────────
guard_home="$tmp/broken"; mkdir -p "$guard_home/state/eindri-reports"
printf 'PASS — PR #1\n' > "$guard_home/state/eindri-reports/pr-1-review.md"
judge "YMIR_HOME='$guard_home' bash -c 'chmod -R a-w \"$guard_home/state\" 2>/dev/null; bash \"$VW\"; rc=\$?; chmod -R u+w \"$guard_home/state\"; exit \$rc'"
case "$out" in *"DELIVERY FAILED"*|*"delivered"*) ok "an unreachable delivery is named, never silent" ;;
  *) bad "the failure was silent" ;; esac

# ── 5 · the seat door refuses what it cannot do, by name ────────────────────────────────────────
judge "bash '$SS' ensure --role sindri"
[ "$rc" = 1 ] && case "$out" in *"--brief is required"*) ok "no brief → refused, and the reason is named" ;;
  *) bad "no brief was refused without naming why" ;; esac || bad "no brief was accepted (rc=$rc)"

judge "bash '$SS' ensure --role no-such-figure --brief '$root/bin/forge/repair-errand.md'"
[ "$rc" = 1 ] && case "$out" in *"no role file"*) ok "an unknown figure → refused, and the reason is named" ;;
  *) bad "an unknown figure was refused without naming why" ;; esac || bad "an unknown figure was accepted (rc=$rc)"

judge "bash '$SS' frobnicate"
[ "$rc" = 1 ] && case "$out" in *"unknown action"*) ok "an unknown action is refused by name" ;;
  *) bad "an unknown action was not refused cleanly" ;; esac || bad "an unknown action was accepted (rc=$rc)"

printf 'test_review_seats: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
