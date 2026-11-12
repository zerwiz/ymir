#!/usr/bin/env bash
# test_fixes_validate.sh — plan 272 fault 10: the fix-note validator judges what a reader needs.
# Before: it demanded the first-ever header shape and a Files section, and called 595 good notes invalid.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
mkdir -p "$T/bin/gates" "$T/RULES" "$T/.pi" "$T/docs/fixes/anycomponent" "$T/docs/fixes/runtime"
cp "$ROOT/bin/gates/fixes.sh" "$T/bin/gates/"
V() { bash "$T/bin/gates/fixes.sh" validate 2>&1; }
printf '# A plain titled note\n\nBody.\n' >"$T/docs/fixes/anycomponent/2026-11-12-plain.md"
printf '\n## runtime · 0.1.1 · 2026-11-12 — a record-shape note without Files\n' >"$T/docs/fixes/runtime/0.1.1-x.md"
printf '**Correction (2026-11-12) —** appended.\n' >"$T/docs/fixes/runtime/2026-11-12-correction.md"
V | grep -q '"valid",3' && ok "a component directory outside the old list, a blank first line, a bold correction and a note with no Files are all valid" || bad "good notes: $(V)"
: >"$T/docs/fixes/runtime/empty.md"
V | grep -q 'no heading' && ok "an empty note is still refused" || bad "empty note accepted"
printf 'just prose, no heading\n' >"$T/docs/fixes/runtime/prose.md"
V | grep -q 'prose.md' && ok "a note with no title is still refused" || bad "untitled accepted"
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
