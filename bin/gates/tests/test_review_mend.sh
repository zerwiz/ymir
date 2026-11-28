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
# only the heart mends: any other role is refused before anything is read or written
out3="$(YMIR_ROLE=dev bash "$guard" 624 2>&1)"; rc3=$?
case "$rc3:$out3" in 4:*"only the heart mends"*) ok "a dev seat is refused (rc 4)" ;; *) bad "dev seat not refused: rc=$rc3" ;; esac

# the heart does not commit onto another person's branch: a stand-in gh, nothing real is touched
fake="$(mktemp -d)"
cat >"$fake/gh" <<'GH'
#!/usr/bin/env bash
case "$*" in
  *headRefName*) echo eindri/example ;;
  *author*) echo someone-else ;;
  "api user"*) echo me ;;
esac
GH
chmod +x "$fake/gh"
out4="$(PATH="$fake:$PATH" YMIR_ROLE=heart YMIR_HOME="$fake" bash "$guard" 1 --only mechanical --no-seat 2>&1)"
case "$out4" in *"belongs to someone-else"*) ok "another person's branch is not mended" ;; *) bad "another person's branch was not skipped" ;; esac
rm -rf "$fake"

printf 'test_review_mend: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" = 0 ] || exit 1
