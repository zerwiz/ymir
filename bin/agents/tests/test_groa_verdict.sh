#!/usr/bin/env bash
# test_groa_verdict.sh — plan 278: the last line of an update tells the truth.
#   1. nothing owed and nothing stopped: "whole", exit 0
#   2. a surface still owed: named with its risk and its exact command, exit 4
#   3. a step that hit its limit is a failure in the verdict, not a note
#   4. a surface the operator accepted as owed is still named, but no longer fails the update
#   5. the owed rows are read from Eir's own `owed:` lines, and nothing else
#   6. a fault report is written once per NEW owed set, and not again while it is unchanged
#   7. Gróa mends after the check (fix --safe), re-checks, and the dead update-notes call now runs
# Usage: test_groa_verdict.sh      Exit: 0 all pass · 1 a failure.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/../groa-verdict-lib.sh"
pass=0; fail=0
t() { local name=$1; shift; if "$@"; then printf '  ok   %s\n' "$name"; pass=$((pass+1)); else printf '  FAIL %s\n' "$name"; fail=$((fail+1)); fi; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

# 1
out="$(groa_verdict "" "" "")"; rc=$?
t "whole: exit 0" [ "$rc" -eq 0 ]
t "whole: the line says whole" grep -q '^groa-update: whole — every surface answers$' <<<"$out"

# 2
out="$(groa_verdict "$(printf 'voice ask\nroddhelm never')" "" "")"; rc=$?
t "owed: exit 4" [ "$rc" -eq 4 ]
t "owed: each surface is named with its risk" grep -q 'owed: voice (ask), roddhelm (never);' <<<"$out"
t "owed: the exact command for a mendable surface" grep -q '  voice: bin/agents/eir-doctor.sh fix voice' <<<"$out"
t "owed: a never surface is report-only" grep -q '  roddhelm: report only' <<<"$out"
t "owed: the line never says whole" bash -c '! grep -q "whole — every" <<<"$0"' "$out"

# 3
out="$(groa_verdict "" " bilskirnir" "")"; rc=$?
t "a stopped step fails the verdict (exit 4)" [ "$rc" -eq 4 ]
t "a stopped step is named" grep -q 'steps stopped at their limit: bilskirnir;' <<<"$out"

# 4
out="$(groa_verdict "roddhelm never" "" "roddhelm")"; rc=$?
t "accepted: exit 0" [ "$rc" -eq 0 ]
t "accepted: still named" grep -q 'accepted as owed: roddhelm' <<<"$out"
printf '# reviewed 2026-11-12\nroddhelm   # the arm holder is a declaration\n\n' >"$T/accepted.txt"
t "accepted: the home file is read, comments dropped" [ "$(groa_accepted "$T/accepted.txt")" = roddhelm ]
t "accepted: a missing file is no list" [ -z "$(groa_accepted "$T/none.txt")" ]

# 5
eir="$(printf 'eir[1]{action,root,broken}:\n  "check","/x",2\nowed: mail safe\nowed: voice ask\nowed: bad risky\neir: 2 surface(s) need mending\n')"
t "owed rows come from Eir's owed lines only" [ "$(groa_owed_from "$eir")" = "$(printf 'mail safe\nvoice ask')" ]

# 6
f1="$(groa_fault_report "$T/faults" "$(printf 'voice ask\nmail safe')" "")"
t "a report is written for a new owed set" [ -n "$f1" ] && [ -f "$f1" ]
t "the report names each surface" grep -q '^voice ask$' "$f1"
f2="$(groa_fault_report "$T/faults" "$(printf 'mail safe\nvoice ask')" "")"
t "the same set (any order) writes no second report" [ -z "$f2" ]
sleep 1
f3="$(groa_fault_report "$T/faults" "voice ask" "")"
t "a changed set writes a new report" [ -n "$f3" ] && [ "$f3" != "$f1" ]
t "nothing owed writes nothing" [ -z "$(groa_fault_report "$T/faults" "" "")" ]

# 7 — the wiring in Gróa itself
G="$HERE/../groa-update.sh"
t "Gróa mends the safe surfaces after the check" grep -q 'eir-doctor.sh" fix --safe' "$G"
t "Gróa re-checks after mending" grep -q 'gstep eir-recheck' "$G"
t "Gróa's closing line is the verdict" grep -q 'groa_verdict "\$EIR_OWED" "\$GSTEP_STOPPED"' "$G"
t "the update-notes call is no longer after the final exit" bash -c 'awk "/^exit /{e=1} e && /update-notes.sh/{bad=1} END{exit bad}" "$0"' "$G"

printf 'test_groa_verdict: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
