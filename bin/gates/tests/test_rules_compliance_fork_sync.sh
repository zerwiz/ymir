#!/usr/bin/env bash
# test_rules_compliance_fork_sync.sh — plan 272 fault 7.
# A fork merges upstream's default branch: every file it "adds" that is byte-identical to upstream's is upstream's,
# and the pusher is not charged for it. A file the pusher wrote himself is still judged.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
G="$T/fork/bin/gates/guards/rules-compliance-guard.sh"
mkdir -p "$T/up" && git -C "$T/up" init -q -b main
git -C "$T/up" config user.email t@example.test; git -C "$T/up" config user.name t
mkdir -p "$T/up/docs"; printf '# A page with no history section\n' >"$T/up/docs/legacy.md"
git -C "$T/up" add . && git -C "$T/up" commit -qm base
git clone -q "$T/up" "$T/fork"; git -C "$T/fork" remote rename origin upstream
git -C "$T/fork" config user.email t@example.test; git -C "$T/fork" config user.name t
git -C "$T/fork" checkout -q -b main2
# the fork's own base is an empty-ish root; upstream's files arrive as an "add"
git -C "$T/fork" checkout -q --orphan forkmain; git -C "$T/fork" rm -rqf . ; printf 'x\n' >"$T/fork/readme.txt"
git -C "$T/fork" add . && git -C "$T/fork" commit -qm forkbase; git -C "$T/fork" branch -q -M forkmain
git -C "$T/fork" update-ref refs/remotes/origin/main HEAD
git -C "$T/fork" checkout -q -b sync && git -C "$T/fork" checkout -q upstream/main -- docs
git -C "$T/fork" add . && git -C "$T/fork" commit -qm sync
mkdir -p "$T/fork/bin/gates/guards"; cp "$ROOT/bin/gates/guards/rules-compliance-guard.sh" "$G"
# the guard locates its repo from its own path, so seat it as the fork's own file but keep it out of the range
out="$(cd "$T/fork" && bash "$G" check origin/main HEAD 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "a sync of upstream's files is not charged to the pusher" || bad "sync judged as the pusher's: $out"
printf '%s' "$out" | grep -q 'upstream' && ok "it says what it subtracted" || bad "silent subtraction"
printf '# my own page\n' >"$T/fork/docs/mine.md"; git -C "$T/fork" add docs/mine.md; git -C "$T/fork" commit -qm mine
out="$(cd "$T/fork" && bash "$G" check origin/main HEAD 2>&1)"; rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'docs/mine.md' && ok "a page the pusher wrote himself is still judged" || bad "own page not judged: $out"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
