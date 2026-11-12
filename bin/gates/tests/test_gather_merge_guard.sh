#!/usr/bin/env bash
# test_gather_merge_guard.sh — plan 272 fault 9: a gathered batch that landed as one parent is named.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
G="$ROOT/bin/gates/guards/gather-merge-guard.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
git -C "$T" init -q -b main; git -C "$T" config user.email t@example.test; git -C "$T" config user.name t
echo a >"$T/a"; git -C "$T" add a; git -C "$T" commit -qm base
echo b >"$T/b"; git -C "$T" add b; git -C "$T" commit -qm "gather: 5 errands in one batch (gather-20261112-131856) (#694)"
SQUASH=$(git -C "$T" rev-parse HEAD)
git -C "$T" checkout -q -b batch HEAD~1; echo c >"$T/c"; git -C "$T" add c; git -C "$T" commit -qm "errand one"
git -C "$T" checkout -q main; git -C "$T" merge -q --no-ff batch -m "gather: 2 errands (gather-20261112-140000)"
MERGED=$(git -C "$T" rev-parse HEAD)
export GATHER_GUARD_REPO="$T"
out="$(bash "$G" check "$SQUASH" 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'ONE parent' && ok "a squashed batch is named" || bad "squash not named: $out"
bash "$G" check "$MERGED" >/dev/null 2>&1 && ok "a batch merged with a merge commit is fine" || bad "merge commit refused"
bash "$G" check "$(git -C "$T" rev-parse HEAD~1)" >/dev/null 2>&1;
git -C "$T" commit -q --allow-empty -m "ordinary change (#700)"; bash "$G" check HEAD >/dev/null 2>&1 && ok "an ordinary single-parent commit is fine" || bad "ordinary refused"
bash "$G" range "$SQUASH~1..$SQUASH" >/dev/null 2>&1; [ $? = 1 ] && ok "a range containing a squashed batch fails" || bad "range"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
