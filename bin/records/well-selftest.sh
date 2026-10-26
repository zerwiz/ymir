#!/usr/bin/env bash
# well-selftest.sh — prove a keeper can find its own memory, and only its own —
# and that the well says NO when it should (plan 136).
#
# WHY the first four checks. On 2026-10-24 the well was warm and useless in three
# ways (plan 129 §21): recall had no tag, actor or date filter; `--tags` was
# accepted and SILENTLY IGNORED; and an episode written seconds earlier was not
# returned by its own words, because the semantic index lags the store. So a keeper
# asking "what did I do last time" was handed the whole house's episodes, or
# nothing, and could not tell which.
#
# WHY the rest. Plan 136 put a GATE in front of the well: a write that changes no
# behaviour, commits to nothing and decides nothing is dropped — and a well that
# keeps everything cannot be trusted about anything. So this test also proves the
# gate BITES (it drops), that it does not bite the true lesson, that a duplicate is
# refused, that the policy's own self-test passes, and — when the bridge is up —
# that a correction chains to the original and hides it from recall.
#
#   1. observe a lesson under a unique tag                         -> stored
#   2. recall it BY TAG with a query the store holds               -> at least one row
#   3. recall the same query under a DIFFERENT tag                 -> exactly zero
#   4. recall with an unknown flag                                 -> refusal (exit 2)
#   5. observe a write that answers none of the three questions    -> dropped (exit 3)
#   6. observe the same lesson twice                               -> second is a duplicate
#   7. the policy's own self-test                                  -> PASS
#
# Exit: 0 all pass · 1 a check failed · 2 usage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIMIR="$ROOT/bin/records/mimir.sh"
[ -x "$MIMIR" ] || { echo "error: no mimir door at $MIMIR" >&2; exit 2; }

TAG="selftest-$(date +%s)"
PROBE="Well self-test probe $TAG: next time, always tag a keeper's memory with its own namespace so recall stays scoped."
NOSENSE="Well self-test probe $TAG says the sky is blue and the well is deep."
fails=0
say() { printf '  %-40s %s\n' "$1" "$2"; }
check() { # <name> <ok:0|1> <detail>
  if [ "$2" = "0" ]; then say "$1" "PASS"; else say "$1" "FAIL ($3)"; fails=$((fails+1)); fi
}

out=$(bash "$MIMIR" observe "$PROBE" --tags "$TAG,selftest" --source "well-selftest" 2>&1)
case "$out" in *observed*) check "observe under a unique tag" 0 ;; *) check "observe under a unique tag" 1 "$out" ;; esac

n=$(bash "$MIMIR" recall "Well self-test probe" --tag "$TAG" --k 5 2>/dev/null | sed -n '1s/recall\[\([0-9]*\)\].*/\1/p')
[ "${n:-0}" -ge 1 ] && check "recall scoped to its own tag" 0 || check "recall scoped to its own tag" 1 "rows=${n:-0}"

n=$(bash "$MIMIR" recall "Well self-test probe" --tag "never-written-$TAG" --k 5 2>/dev/null | sed -n '1s/recall\[\([0-9]*\)\].*/\1/p')
[ "${n:-1}" = 0 ] && check "a wrong tag returns nothing" 0 || check "a wrong tag returns nothing" 1 "rows=${n:-?}"

if bash "$MIMIR" recall "anything" --nonsense-flag >/dev/null 2>&1; then
  check "an unknown flag is refused" 1 "accepted"
else
  check "an unknown flag is refused" 0
fi

bash "$MIMIR" observe "$NOSENSE" --tags "$TAG,selftest" --source "well-selftest" >/dev/null 2>&1
rc=$?
[ "$rc" = "3" ] && check "a write that answers no question is DROPPED" 0 || check "a write that answers no question is DROPPED" 1 "rc=$rc"

bash "$MIMIR" observe "$PROBE" --tags "$TAG,selftest" --source "well-selftest" >/dev/null 2>&1
rc=$?
[ "$rc" = "3" ] && check "the same lesson twice is a duplicate" 0 || check "the same lesson twice is a duplicate" 1 "rc=$rc"

if bash "$MIMIR" policy --self-test >/dev/null 2>&1; then
  check "the policy's own self-test" 0
else
  check "the policy's own self-test" 1 "mimir.sh policy --self-test"
fi

# The correction chain is NOT tested here: it needs a store to annotate, and this
# test must not leave a correction behind in the live well. It is proved on a
# throwaway store by .agents/tests/well-policy.test.sh — a test of the house, on a
# well of its own.

printf 'well-selftest[1]{fails,state}:\n  %s,"%s"\n' "$fails" "$([ "$fails" = 0 ] && echo PASS || echo FAIL)"
[ "$fails" = 0 ]
