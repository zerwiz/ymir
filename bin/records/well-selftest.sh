#!/usr/bin/env bash
# well-selftest.sh — prove a keeper can find its own memory, and only its own.
#
# WHY: on 2026-10-24 the well was warm and useless in three ways (plan 129 §21): recall had
# no tag, actor or date filter; `--tags` was accepted and SILENTLY IGNORED; and an episode
# written seconds earlier was not returned by its own words, because the semantic index lags
# the store. So a keeper asking "what did I do last time" was handed the whole house's
# episodes, or nothing, and could not tell which.
#
# This test is the guard for all three:
#   1. observe an episode under a unique tag
#   2. recall it BY TAG with a query the store holds            -> expect at least one row
#   3. recall the same query under a DIFFERENT tag               -> expect exactly zero
#   4. recall with an unknown flag                               -> expect refusal (exit 2)
#
# Exit: 0 all pass · 1 a check failed · 2 usage.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIMIR="$ROOT/bin/records/mimir.sh"
[ -x "$MIMIR" ] || { echo "error: no mimir door at $MIMIR" >&2; exit 2; }

TAG="selftest-$(date +%s)"
PROBE="Well self-test probe $TAG: a keeper's memory must be its own namespace."
fails=0
say() { printf '  %-34s %s\n' "$1" "$2"; }

out=$(bash "$MIMIR" observe "$PROBE" --tags "$TAG,selftest" --source "well-selftest" 2>&1)
case "$out" in *observed*) say "observe under a unique tag" "PASS" ;; *) say "observe under a unique tag" "FAIL ($out)"; fails=$((fails+1)) ;; esac

n=$(bash "$MIMIR" recall "Well self-test probe" --tag "$TAG" --k 5 2>/dev/null | sed -n '1s/recall\[\([0-9]*\)\].*/\1/p')
[ "${n:-0}" -ge 1 ] && say "recall scoped to its own tag" "PASS ($n row)" || { say "recall scoped to its own tag" "FAIL (rows=${n:-0})"; fails=$((fails+1)); }

n=$(bash "$MIMIR" recall "Well self-test probe" --tag "never-written-$TAG" --k 5 2>/dev/null | sed -n '1s/recall\[\([0-9]*\)\].*/\1/p')
[ "${n:-1}" = 0 ] && say "a wrong tag returns nothing" "PASS" || { say "a wrong tag returns nothing" "FAIL (rows=${n:-?})"; fails=$((fails+1)); }

if bash "$MIMIR" recall "anything" --nonsense-flag >/dev/null 2>&1; then
  say "an unknown flag is refused" "FAIL (accepted)"
  fails=$((fails+1))
else
  say "an unknown flag is refused" "PASS"
fi

printf 'well-selftest[1]{fails,state}:\n  %s,"%s"\n' "$fails" "$([ "$fails" = 0 ] && echo PASS || echo FAIL)"
[ "$fails" = 0 ]
