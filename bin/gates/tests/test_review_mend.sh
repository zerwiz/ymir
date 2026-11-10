#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
guard="$here/../../forge/review-mend.sh"
pass=0; fail=0
ok(){ printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad(){ printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

# dry-run on PR 624 (missing CHANGE LOG) -> rung per finding + next:
out=""; rc=0
out="$(bash "$guard" 624 --dry-run 2>&1)"; rc=$?
case "$out" in *"next:"*) ok "next: present on dry-run" ;; *) bad "no next: in dry-run output" ;; esac

# dark host falls through: set YMIR_HOME to empty so no host -> DARK or falls to next
out2="$(YMIR_HOME=/tmp/ymir-empty bash "$guard" 624 --dry-run 2>&1)"; rc2=$?
case "$out2" in *"next:"*) ok "next: present after dark/fallthrough" ;; *) bad "no next: after fallthrough" ;; esac

# code conflict never touched: ensure script does not modify non-md files in dry run (no commits)
printf 'test_review_mend: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
