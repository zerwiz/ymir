#!/usr/bin/env bash
# test_fixes_regate.sh — the record gate judges CONTENT, not ceremony (2026-11-16).
#
# A push whose only new commits change no file is a RE-GATE: `git commit --allow-empty` to
# re-trigger the gate, or a branch re-pointed at a tree the gate has already seen. The gate
# demanded a fix note for it, and a green pull request was pushed four times to satisfy a
# gate about content it did not have. This proves both halves of the mend:
#
#   · an empty range passes, and says why;
#   · a range that DOES change a file and carries no note is still refused;
#   · and the note answers the change when it is there.
#
# Exit: 0 every case behaved · 1 a case did not.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

mkdir -p "$T/bin/gates/guards" "$T/RULES" "$T/.pi" "$T/docs/fixes/gate"
cp "$ROOT/bin/gates/guards/fixes-guard.sh" "$T/bin/gates/guards/"
[ -r "$ROOT/bin/gates/guards/branch-guard.sh" ] && cp "$ROOT/bin/gates/guards/branch-guard.sh" "$T/bin/gates/guards/"

cd "$T" || exit 1
git init -q . >/dev/null 2>&1
git symbolic-ref HEAD refs/heads/main
git config user.email "test@example.com"
git config user.name "test"
printf 'one\n' > note.txt
git add note.txt && git commit -qm base

J() { bash "$T/bin/gates/guards/fixes-guard.sh" --check 2>&1; }

# 1 — the empty re-gate
git checkout -q -b eindri/re-gate
git commit -q --allow-empty -m "re-gate: re-run the gate on the same tree"
out="$(J)"; rc=$?
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'empty range'; then
  ok "an empty re-gate passes and says it carries no change"
else
  bad "an empty re-gate was refused (rc=$rc): $out"
fi

# 2 — a real change with no note still refuses
git checkout -q main
git checkout -q -b eindri/real-change
printf 'two\n' >> note.txt
git commit -qam "a real change"
out="$(J)"; rc=$?
if [ "$rc" != 0 ] && printf '%s' "$out" | grep -q 'no fix note'; then
  ok "a real change with no fix note is still refused"
else
  bad "a real change passed without a record (rc=$rc): $out"
fi

# 3 — and the note answers the change
printf '## gate · 2026-11-16 — the change this range makes\n\nA real sentence.\n' > "$T/docs/fixes/gate/2026-11-16-a-real-change.md"
git add docs/fixes/gate/2026-11-16-a-real-change.md
printf 'three\n' >> note.txt
git commit -qam "the change, with its note"
out="$(J)"; rc=$?
if [ "$rc" = 0 ]; then
  ok "a note in the range answers the change"
else
  bad "a correct note was refused (rc=$rc): $out"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
