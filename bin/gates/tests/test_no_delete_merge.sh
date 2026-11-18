#!/usr/bin/env bash
# test_no_delete_merge.sh — a merge is not blamed for a deletion the merged-in side made (fix 2026-11-18).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; GUARD="$HERE/../../no-delete-guard.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT; fail=0
mkdir -p "$T/bin" "$T/.pi" "$T/RULES"; cp "$GUARD" "$T/bin/"; cd "$T" || exit 1
g() { git -c core.hooksPath=/dev/null -c user.email=t@example.org -c user.name=t "$@"; }
git init -q -b main . && echo a >x && echo b >y && git add . && g commit -qm base
git checkout -q -b side && git checkout -q main && git rm -q x && g commit -qm "main removes x"
git checkout -q side && echo s >w && git add w && g commit -qm side
git merge --no-commit --no-ff main >/dev/null 2>&1
out="$(bash bin/no-delete-guard.sh --staged 2>&1)"
case "$out" in *clear*) echo "ok   main's own deletion is not the merge's" ;; *) echo "FAIL main's deletion blamed on the merge: $out"; fail=1 ;; esac
git rm -q y
out="$(bash bin/no-delete-guard.sh --staged 2>&1)"
case "$out" in *REFUSED*) echo "ok   a deletion the merge itself makes is still refused" ;; *) echo "FAIL an own deletion slipped through: $out"; fail=1 ;; esac
exit "$fail"
