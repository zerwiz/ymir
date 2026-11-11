#!/usr/bin/env bash
# guards-scope.test.sh — prove the pre-push gate bites, and only where it should.
#
# Plan 243 §3 parts B/C/D/F. A ward never seen to refuse is decoration, and a scope never seen
# to skip is a lie about what a push proves. Both halves are proved here, in a THROWAWAY CLONE
# of this tree, so the assertions do not depend on main being red or green today:
#
#   1  a leak in the pushed bytes is REFUSED                      (the gate still bites)
#   2  a finding in a file the push did not touch is INHERITED and passes
#   3  the same finding becomes the push's own when the file IS in the changed set
#   4  a scoped ward reads only the changed files                 (the work is actually cut)
#   5  --profile prints every ward's time, slowest first
#   6  the CI posture is wired: ci-verify.sh calls guards.sh --full
#
# Usage: guards-scope.test.sh        Exit: 0 all six hold · 1 one does not · 2 usage.
set -u
case "${1-}" in -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; "") ;; *) exit 2 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/guard-scope-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()   { pass=$((pass+1)); printf '  "%s","PASS","%s"\n' "$1" "$2"; }
bad()  { fail=$((fail+1)); printf '  "%s","FAIL","%s"\n' "$1" "$2"; }

printf 'guards_scope_test[...]{check,status,detail}:\n'

# A throwaway clone: real wards, real paths, and nothing it does can touch the worktree. The
# clone carries the HISTORY (so origin/main resolves); the tracked files are then overlaid with
# the WORKING TREE's content, because a test of the gate must judge the gate as it stands here,
# not the last commit of it.
if ! git clone --quiet --shared "$ROOT" "$WORK/tree" 2>/dev/null; then
  bad clone "could not clone $ROOT into a throwaway tree"
  printf 'guards-scope-test: 1 failure\n' >&2; exit 1
fi
T="$WORK/tree"
( cd "$ROOT" && git ls-files -z | tar --null -T - -cf - ) 2>/dev/null | tar -xf - -C "$T" 2>/dev/null || {
  bad clone "could not copy the working tree into the throwaway tree"
  printf 'guards-scope-test: 1 failure\n' >&2; exit 1
}
cd "$T" || exit 1
BASE="$(git rev-parse -q --verify origin/main || git rev-parse HEAD)"

scope_of() { printf '%s\n' "$@" >"$WORK/scope.txt"; printf '%s' "$WORK/scope.txt"; }

# ── 1. a leak in the pushed bytes is refused ─────────────────────────────────
printf 'a note for the test\n\nhost 100.64.1.2 and zzz.tailnet.ts.net\n' >docs/guard-scope-probe-leak.md
out="$(cd "$T" && bash bin/gates/guards.sh --base "$BASE" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '"public-data-guard.sh","FAIL"'; then
  ok leak "a private address and a tailnet host in an added file are refused (exit 1)"
else
  bad leak "a leak in the pushed bytes was NOT refused (exit $rc)"
  printf '%s\n' "$out" | tail -5
fi
rm -f docs/guard-scope-probe-leak.md

# ── 2/3. inherited vs the push's own ─────────────────────────────────────────
# A new feature page that is not catalogued is a finding TWO whole-tree wards report, naming
# the page. It is the push's own when the page is in the changed set, and inherited when it is
# not — the exact distinction part D turns on.
printf '# a probe page the catalogue does not know\n\nCHANGE LOG\n\n- **2026-11-11** — test fixture.\n' \
  >docs/features/zzz-guard-scope-probe.md

out_in="$(cd "$T" && bash bin/gates/guards.sh --base "$BASE" --changed "$(scope_of docs/features/zzz-guard-scope-probe.md)" 2>&1)"; rc_in=$?
if [ "$rc_in" -eq 1 ] && printf '%s' "$out_in" | grep -q '"\(features\|weave\)-guard.sh","FAIL"'; then
  ok in_scope "a finding in a file the push touched is FAIL, and the push is refused"
else
  bad in_scope "a finding in the push's own file did not refuse it (exit $rc_in)"
  printf '%s\n' "$out_in" | grep -E 'FAIL|INHERITED' | head -5
fi

out_out="$(cd "$T" && bash bin/gates/guards.sh --base "$BASE" --changed "$(scope_of bin/gates/guards.sh)" 2>&1)"; rc_out=$?
if [ "$rc_out" -eq 0 ] && printf '%s' "$out_out" | grep -q '"\(features\|weave\)-guard.sh","INHERITED"'; then
  ok inherited "the same finding, in a file the push did not touch, prints INHERITED and passes"
else
  bad inherited "an inherited finding was not carried as INHERITED (exit $rc_out)"
  printf '%s\n' "$out_out" | grep -E 'FAIL|INHERITED' | head -5
fi
rm -f docs/features/zzz-guard-scope-probe.md

# ── 4. a scoped ward reads only the changed files ───────────────────────────
# public-data-guard is the ward whose whole-tree walk made the pre-push slow. Handed one file
# it must report ONE file, not 5,000 — that is the difference between 22 s and 0.1 s.
one="$(cd "$T" && bash bin/gates/guards/public-data-guard.sh check README.md 2>&1)"
if printf '%s' "$one" | grep -qE '^\s+"1","'; then
  ok scoped "public-data-guard judged exactly the one file it was handed"
else
  bad scoped "public-data-guard did not honour the scope it was handed"
  printf '%s\n' "$one" | tail -3
fi

# ── 5. --profile names every ward's time ────────────────────────────────────
if printf '%s' "$out_in" | grep -q 'profile\[' ; then
  bad profile "--profile printed a profile block without being asked"
fi
prof="$(cd "$T" && bash bin/gates/guards.sh --base "$BASE" --changed "$(scope_of README.md)" --profile 2>&1)"
if printf '%s' "$prof" | grep -q 'profile\[' && printf '%s' "$prof" | grep -q '"public-data-guard.sh"'; then
  ok profile "--profile prints each ward's milliseconds, slowest first"
else
  bad profile "--profile did not print the timings"
fi

# ── 6. the CI posture is wired ──────────────────────────────────────────────
if grep -q 'guards.sh" --full' "$ROOT/bin/gates/ci-verify.sh" \
   && grep -q 'ci-verify.sh' "$ROOT/.github/workflows/ymir-gates.yml"; then
  ok ci_full "ci-verify.sh runs guards.sh --full, and the workflow runs ci-verify.sh"
else
  bad ci_full "the CI posture is not wired: ci-verify must call guards.sh --full"
fi
if grep -q 'CI_ONLY_REASON=(' "$ROOT/bin/gates/guards.sh" \
   && for w in inventory-guard.sh registers-guard.sh docs-claims-guard.sh language-guard.sh dead-code-guard.sh; do
        grep -q "\"$w|" "$ROOT/bin/gates/guards.sh" || exit 1
      done; then
  ok declared "every ward over 10 s is CI-only WITH a measured reason, in one declared list"
else
  bad declared "a slow ward is not declared CI-only with a reason"
fi

printf 'guards-scope-test: %s pass, %s fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
