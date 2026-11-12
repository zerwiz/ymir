#!/usr/bin/env bash
# test_review_seat_verdict.sh — plan 272 fault 6: a review seat ends in a verdict, or says why it has none.
# Before: an idle review seat was filed as "finished without a terminal word, 0 commits", which names nothing to act on.
# The sweep runs from a copy in a temp home, with a stub `herdr` that reports every pane idle.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

mkdir -p "$T/repo/bin/agents" "$T/repo/bin/vault" "$T/repo/bin/time" "$T/hm/state" "$T/stub" "$T/wt1" "$T/wt2" "$T/wt3"
cp "$ROOT/bin/agents/eindri-handoff.sh" "$ROOT/bin/agents/eindri-wake-lib.sh" "$T/repo/bin/agents/"
cp "$ROOT/bin/vault/hoard-lib.sh" "$T/repo/bin/vault/"; cp "$ROOT/bin/time/sol-lib.sh" "$T/repo/bin/time/"
cat >"$T/stub/herdr" <<'H'
#!/usr/bin/env bash
printf '{"result":{"agents":[{"pane_id":"p1","agent_status":"idle"},{"pane_id":"p2","agent_status":"idle"},{"pane_id":"p3","agent_status":"idle"}]}}\n'
H
chmod +x "$T/stub/herdr"
for n in 1 2 3; do git -C "$T/wt$n" init -q 2>/dev/null; done
S="$T/hm/state"
mk() { printf 'mode=review\nseat_state=working\nworktree=%s\nwindow=%s\n' "$2" "$3" >"$S/$1.meta"; printf 'working: launched\n' >"$S/$1.status"; }
mk r-none "$T/wt1" p1
mk r-file "$T/wt2" p2; printf '# Review\n\nNEEDS-REWORK (3): the gate is red on the new test\n' >"$T/wt2/REVIEW.md"
mk r-stat "$T/wt3" p3; printf 'done: APPROVED: PR #9 — clean\n' >>"$S/r-stat.status"

env -i PATH="$T/stub:$PATH" HOME="$T" YMIR_HOME="$T/hm" BROKK_HOME="$T/repo" bash "$T/repo/bin/agents/eindri-handoff.sh" sweep >/dev/null 2>&1

grep -q 'REVIEW ENDED WITHOUT A VERDICT' "$S/eindri-reports/r-none.md" 2>/dev/null && ok "an idle review seat with nothing is filed as NO VERDICT, not as a generic silent finish" || bad "no-verdict report: $(cat "$S/eindri-reports/r-none.md" 2>&1 | head -3)"
grep -q 'seat the review again' "$S/eindri-reports/r-none.md" 2>/dev/null && ok "the no-verdict report names the next act" || bad "no next act"
grep -qi 'finished without a terminal word' "$S/eindri-reports/r-none.md" 2>/dev/null && bad "still filed as a generic finish" || ok "it is not filed as a generic finish"
grep -q 'NEEDS-REWORK' "$S/eindri-reports/r-file.md" 2>/dev/null && grep -q 'recovered' "$S/eindri-reports/r-file.md" && ok "a verdict the seat left in REVIEW.md is recovered and filed" || bad "file verdict: $(cat "$S/eindri-reports/r-file.md" 2>&1 | head -3)"
grep -q 'APPROVED' "$S/eindri-reports/r-stat.md" 2>/dev/null && ok "a verdict on the status line is recovered and filed" || bad "status verdict"
grep -q 'eindri r-none ' "$S/.wake-queue" 2>/dev/null && ok "the helm is woken for the no-verdict review" || bad "no wake for r-none"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
