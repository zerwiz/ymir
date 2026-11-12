#!/usr/bin/env bash
# test_launcher_worktree_guard.sh — the four launchers run in place in the main tree, and a worktree's copy
# re-runs main's copy at the SAME relative path (2026-11-12: the guard compared root with scripts/, so every
# icon on the pin re-ran "<root>/electron.sh", a file that does not exist, and no app opened).
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }
FILES="scripts/electron.sh scripts/raise.sh scripts/start.sh bin/desktop/sessrumnir-launch.sh"
M="$T/main"; W="$T/wt"
git init -q "$M"
mkdir -p "$M/bin/desktop" "$M/scripts"
cp "$REPO/bin/desktop/main-tree.sh" "$M/bin/desktop/"
for f in $FILES; do
  # the real guard block from the repo, then one line that says where the script ran from
  sed -n '/^if \[ -z "\${YMIR_ALLOW_WORKTREE_RUNTIME:-}" \]; then$/,/^fi$/p' "$REPO/$f" > "$M/$f"
  printf '%s\n' 'printf "RAN %s\n" "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"' >> "$M/$f"
done
git -C "$M" add -A >/dev/null
git -C "$M" -c user.email=t@t -c user.name=t commit -qm base
git -C "$M" worktree add -q "$W" -b wt >/dev/null 2>&1
for f in $FILES; do
  got="$(bash "$M/$f" 2>/dev/null)"
  [ "$got" = "RAN $M/$f" ] && ok "$f runs in place in the main tree" || bad "$f in the main tree: '$got'"
  got="$(bash "$W/$f" 2>/dev/null)"
  [ "$got" = "RAN $M/$f" ] && ok "$f in a worktree re-runs main's copy" || bad "$f from a worktree: '$got'"
done
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
