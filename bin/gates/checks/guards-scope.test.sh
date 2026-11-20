#!/usr/bin/env bash
# guards-scope.test.sh — prove the pre-push gate bites, and only where it should.
#
# Plan 243 §3 parts B/C/D/F. A ward never seen to refuse is decoration, and a scope never seen
# to skip is a lie about what a push proves. Both halves are proved here, in a THROWAWAY CLONE
# of this tree, so the assertions do not depend on main being red or green today:
#
#   1  a finding in a file the push did not touch is INHERITED, and the push proceeds
#   2  a leak in the pushed bytes is still REFUSED                  (security is not traded)
#   3  a finding in a file the push DID touch is FAIL, and it refuses
#   4  a scoped ward reads only the changed files                   (the work is really cut)
#   5  --profile prints every ward's time, slowest first
#   6  the CI posture is wired, and every slow ward is declared CI-only WITH a reason
#
# Usage: guards-scope.test.sh        Exit: 0 all hold · 1 one does not · 2 usage.
set -u
case "${1-}" in -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; "") ;; *) exit 2 ;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/guard-scope-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ok()  { pass=$((pass+1)); printf '  "%s","PASS","%s"\n' "$1" "$2"; }
bad() { fail=$((fail+1)); printf '  "%s","FAIL","%s"\n' "$1" "$2"; }
die() { bad "$1" "$2"; printf 'guards-scope-test: %s pass, %s fail\n' "$pass" "$fail" >&2; exit 1; }

printf 'guards_scope_test[...]{check,status,detail}:\n'

# A throwaway clone: the real HISTORY (so origin/main resolves) plus the WORKING TREE's content
# for every tracked file — a test of the gate must judge the gate as it stands here, not as its
# last commit left it.
git clone --quiet --shared "$ROOT" "$WORK/tree" 2>/dev/null \
  || die clone "could not clone $ROOT into a throwaway tree"
T="$WORK/tree"
( cd "$ROOT" && git ls-files -z | tar --null -T - -cf - ) 2>/dev/null | tar -xf - -C "$T" 2>/dev/null \
  || die clone "could not copy the working tree into the throwaway tree"
cd "$T" || exit 1
git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false \
    -c advice.detachedHead=false checkout -q -B probe HEAD 2>/dev/null || true

# THE PLANTED FAULT, committed in the clone so it is part of its main — a feature page the
# catalogue does not know. Two whole-tree wards (features, weave) name it. It is therefore the
# perfect probe for part D: inherited when the push does not touch it, ours when it does.
printf '# a probe page the catalogue does not know\n\nCHANGE LOG\n\n- **2026-11-11** — test fixture.\n' \
  >docs/features/zzz-guard-scope-probe.md
git add docs/features/zzz-guard-scope-probe.md >/dev/null 2>&1
git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false \
    commit -q -m "test fixture: an uncatalogued feature page" >/dev/null 2>&1 \
  || die planted "could not commit the planted fault in the throwaway tree"
BASE="$(git rev-parse HEAD)"
scope() { printf '%s\n' "$@" >"$WORK/scope.txt"; printf '%s' "$WORK/scope.txt"; }

# ── 1 and 5. inherited passes, and --profile names every ward's time ─────────
out_inh="$(bash bin/gates/guards.sh --base "$BASE" --changed "$(scope bin/gates/guards.sh)" --profile 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out_inh" | grep -qE '"(features|weave)-guard.sh","INHERITED"'; then
  ok inherited "a finding in a file the push did not touch prints INHERITED and the push proceeds"
else
  bad inherited "an inherited finding was not carried as INHERITED (exit $rc)"
  printf '%s\n' "$out_inh" | grep -E 'FAIL|INHERITED' | head -5
fi
if printf '%s' "$out_inh" | grep -q 'profile\[' \
   && printf '%s' "$out_inh" | grep -q '"public-data-guard.sh"'; then
  ok profile "--profile prints each ward's milliseconds, slowest first"
else
  bad profile "--profile did not print the timings"
fi

# ── 2 and 3. the same finding in scope is FAIL, and a leak is still refused ──
# The refused shapes are BUILT, not written: a test fixture that spells a real topology shape is
# itself a RULES/04 finding (measured 2026-11-11: this file was refused by public-data-guard for
# naming one). The fixture is synthetic; the ward is the thing under test.
leak_line="$(printf 'host 100.64.1.2 and zzz.%s.ts.net' tailnet)"
printf 'a note for the test\n\n%s\n' "$leak_line" >docs/guard-scope-probe-leak.md
out_own="$(bash bin/gates/guards.sh --base "$BASE" \
             --changed "$(scope docs/features/zzz-guard-scope-probe.md docs/guard-scope-probe-leak.md)" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out_own" | grep -qE '"(features|weave)-guard.sh","FAIL"'; then
  ok in_scope "the same finding, in a file the push touched, is FAIL and the push is refused"
else
  bad in_scope "a finding in the push's own file did not refuse it (exit $rc)"
  printf '%s\n' "$out_own" | grep -E 'FAIL|INHERITED' | head -5
fi
if [ "$rc" -eq 1 ] && printf '%s' "$out_own" | grep -q '"public-data-guard.sh","FAIL"'; then
  ok leak "a private address and a tailnet host in the pushed bytes are still REFUSED"
else
  bad leak "a leak in the pushed bytes was not refused"
  printf '%s\n' "$out_own" | grep -E 'public-data' | head -3
fi
rm -f docs/guard-scope-probe-leak.md

# ── 4. a scoped ward reads only the changed files ───────────────────────────
# public-data-guard is the ward whose whole-tree walk made the pre-push slow. Handed one file it
# must report ONE file, not 5,000 — the difference between 22 s and 0.1 s.
one="$(bash bin/gates/guards/public-data-guard.sh check README.md 2>&1)"
if printf '%s' "$one" | grep -qE '^ +"1","'; then
  ok scoped "public-data-guard judged exactly the one file it was handed"
else
  bad scoped "public-data-guard did not honour the scope it was handed"
  printf '%s\n' "$one" | tail -3
fi

# ── 6. the CI posture is wired, and the slow wards are declared ─────────────
if grep -q 'guards.sh" --full' "$ROOT/bin/gates/ci-verify.sh" \
   && grep -q 'ci-verify.sh' "$ROOT/.github/workflows/ymir-gates.yml" \
   && grep -q 'main-red-issue.sh --apply' "$ROOT/.github/workflows/ymir-gates.yml"; then
  ok ci_full "CI runs guards.sh --full for every PR and main, and files one issue when main is red"
else
  bad ci_full "the CI posture is not wired: ci-verify must call guards.sh --full, and the workflow must file the red-main issue"
fi
declared=1
for w in inventory-guard.sh registers-guard.sh docs-claims-guard.sh language-guard.sh dead-code-guard.sh; do
  grep -q "\"$w|" "$ROOT/bin/gates/guards.sh" || declared=0
done
if [ "$declared" -eq 1 ]; then
  ok declared "every ward over 10 s is CI-only WITH a measured reason, in one declared list"
else
  bad declared "a slow ward is not declared CI-only with a reason"
fi

printf 'guards-scope-test: %s pass, %s fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
