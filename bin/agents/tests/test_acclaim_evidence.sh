#!/usr/bin/env bash
# test_acclaim_evidence.sh — the Veil, part 1 (plan 350 B1): evidence or no "done".
# A done act with no evidence, or with evidence that fails, ends `unproven`: the status line says
# so, the wake says UNPROVEN, the review is not seated, and the report carries a Veil id the arm
# holder answers. With green evidence it is `done`, and the shelf carries each command and its output.
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
pass=0; fail=0
ok()  { printf '  PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
st="$T/state"; repo="$T/repo"; mkdir -p "$st" "$repo"
git -C "$repo" init -q -b main && git -C "$repo" -c user.email=a@example.org -c user.name=ada commit -q --allow-empty -m base
git -C "$repo" checkout -q -b eindri/t1 && git -C "$repo" -c user.email=a@example.org -c user.name=ada commit -q --allow-empty -m work
printf 'mode=local-only\nworktree=%s\n' "$repo" >"$st/t1.meta"; cp "$st/t1.meta" "$st/t2.meta"; cp "$st/t1.meta" "$st/t3.meta"
A=(env "BROKK_STATE_OVERRIDE=$st" YMIR_AUTO_REVIEW=off YMIR_NO_INJECT=1 VEIL_PR_CHECKS=off "YMIR_ACCLAIM_WELL=$T/no-well"
   "VEIL_TELL_DOOR=$T/none" "VEIL_PANE_DOOR=$T/none" "VEIL_REPLY_DOOR=$T/none" bash "$root/bin/agents/eindri-acclaim.sh")
echo "test_acclaim_evidence"

out="$("${A[@]}" t1 --terminal done --line "fixed the door" 2>&1)"; rc=$?
[ "$rc" = 5 ] && ok "done with no evidence exits 5" || bad "rc=$rc: $out"
tail -n1 "$st/t1.status" | grep -q '^unproven: ' && ok "the status line says unproven, never done" || bad "status: $(tail -n1 "$st/t1.status")"
grep -q 'eindri t1 UNPROVEN' "$st/.wake-queue" && ok "the wake says UNPROVEN" || bad "wake: $(cat "$st/.wake-queue")"
grep -q 'none given' "$st/eindri-reports/t1.md" && ok "the shelf says no evidence was given" || bad "shelf"
grep -q '"kind": "finding"' "$st/veil/ledger.jsonl" 2>/dev/null && ok "the arm holder is told through the Veil (a finding with an id)" || bad "veil ledger: $(cat "$st/veil/ledger.jsonl" 2>/dev/null)"
grep -q 'veil.sh received veil-' "$st/.wake-queue" && ok "the wake carries the id the holder answers with" || bad "no id in wake"

out="$("${A[@]}" t2 --terminal done --evidence "echo 3 passed" --evidence "false" --line "fixed two things" 2>&1)"; rc=$?
[ "$rc" = 5 ] && tail -n1 "$st/t2.status" | grep -q 'evidence 2 exited 1' && ok "a failing evidence command makes it unproven, naming which" || bad "t2: rc=$rc $(tail -n1 "$st/t2.status")"

out="$("${A[@]}" t3 --terminal done --evidence "echo 12 passed, 0 failed" --line "built it" 2>&1)"; rc=$?
[ "$rc" = 0 ] && tail -n1 "$st/t3.status" | grep -q '^done: ' && ok "green evidence: done" || bad "t3: rc=$rc $out"
grep -q '12 passed, 0 failed' "$st/eindri-reports/t3.md" && grep -q '^## Evidence' "$st/eindri-reports/t3.md" \
  && ok "the shelf files the command and its output" || bad "t3 shelf: $(cat "$st/eindri-reports/t3.md")"
grep -q '^## Record' "$st/eindri-reports/t3.md" && ok "the record is still written" || bad "no record"

# the unproven errand proves itself later: done replaces the unproven shelf and wakes again
out="$("${A[@]}" t1 --terminal done --evidence "true" --line "fixed the door, proven" 2>&1)"; rc=$?
[ "$rc" = 0 ] && tail -n1 "$st/t1.status" | grep -q '^done: ' && ok "an unproven errand can prove itself afterwards" || bad "t1 again: rc=$rc"
grep -q '\[unproven' "$st/eindri-reports/t1.md" && bad "the old unproven shelf survived" || ok "the proven shelf replaces the unproven one"
[ "$(grep -c 'eindri t1 ' "$st/.wake-queue")" -ge 2 ] && ok "the proof wakes the helm again" || bad "no second wake"

out="$(VEIL_EVIDENCE=off "${A[@]}" t9 --terminal done --line "overridden" 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'VEIL_EVIDENCE=off' && ok "the override is loud" || bad "override: rc=$rc $out"
echo "test_acclaim_evidence: $pass passed, $fail failed"
[ "$fail" = 0 ]
