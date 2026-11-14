#!/usr/bin/env bash
# test_gate_directory.sh — plan 295 fix S1: the gate list is a DIRECTORY, so two branches that add
# two gates add two files and merge without a conflict — and the run is never weaker for it.
#
# The fault this fences (measured by the heart, 2026-11-14): every open pull request conflicted
# with every other in ONE file, bin/gates/ci-verify.sh, because each branch appended its gate line
# there. Fourteen sound PRs could not merge, and the queue never drained.
#
# What is proved here, in a throwaway repository with the REAL driver copied into it:
#   1. two branches, each adding one gate file, MERGE with no conflict and both gates run
#   2. the rows come out in file order, so one run reads one way for every hand
#   3. a gate FILE that fails FAILS THE RUN — a file is a gate, not a decoration
#   4. a gate file that cannot LOAD is a FAIL, never a silent skip
#   5. an EMPTY gate directory refuses, loudly and non-zero (an empty list is not a green)
#   6. the real gate list carries no gate line in ci-verify.sh — adding a gate is adding a file
#
# Everything lives under a temporary HOME and a temporary repository: the real tree, the pin and
# this machine's home are never read or written.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL %s\n' "$1"; }

# ── a repository that carries the REAL driver, and nothing else ──────────────
R="$T/repo"; mkdir -p "$R/bin/gates/checks.d" "$R/.pi" "$R/RULES"
git init -q -b main "$R"
git -C "$R" config user.email t@example.test
git -C "$R" config user.name t
cp "$ROOT/bin/gates/ci-verify.sh" "$R/bin/gates/ci-verify.sh"
chmod +x "$R/bin/gates/ci-verify.sh"
: >"$R/.pi/keep"; : >"$R/RULES/keep"
cat >"$R/bin/gates/checks.d/0010-base.sh" <<'GATE'
gate base "the gate a checkout already had" bash -c 'exit 0'
GATE
git -C "$R" add -A
git -C "$R" commit -qm "the gate driver and one gate"

run_driver() {  # <checks-dir> -> prints the run, exits with the driver's code
  ( cd "$R" && YMIR_GATE_CHECK_DIR="$1" YMIR_CI_VERDICT="$T/verdict.txt" \
      bash "$R/bin/gates/ci-verify.sh" ) 2>&1
}

# ── 1. two branches, two gates: git merges them, no conflict ─────────────────
git -C "$R" checkout -q -b eindri/gate-a
cat >"$R/bin/gates/checks.d/0100-gate-a.sh" <<'GATE'
gate gate-a "the gate branch A brought" bash -c 'exit 0'
GATE
git -C "$R" add bin/gates/checks.d/0100-gate-a.sh
git -C "$R" commit -qm "gate A: add one file"

git -C "$R" checkout -q main
git -C "$R" checkout -q -b eindri/gate-b
cat >"$R/bin/gates/checks.d/0110-gate-b.sh" <<'GATE'
gate gate-b "the gate branch B brought" bash -c 'exit 0'
GATE
git -C "$R" add bin/gates/checks.d/0110-gate-b.sh
git -C "$R" commit -qm "gate B: add one file"

if git -C "$R" merge --no-ff -q eindri/gate-a -m "merge gate A" 2>"$T/merge.err" \
   && git -C "$R" merge --no-ff -q eindri/gate-b -m "merge gate B" 2>>"$T/merge.err"; then
  ok "two branches adding two gates merge with no conflict"
else
  bad "the two gate branches conflicted: $(tr '\n' ' ' <"$T/merge.err")"
fi
[ -f "$R/bin/gates/checks.d/0100-gate-a.sh" ] && [ -f "$R/bin/gates/checks.d/0110-gate-b.sh" ] \
  && ok "both gate files survive the merge" || bad "a gate file was lost in the merge"

# ── 2. every gate runs, and the rows follow the file order ───────────────────
out="$(run_driver "$R/bin/gates/checks.d")"; rc=$?
[ "$rc" -eq 0 ] && ok "the merged run is green (exit 0)" || bad "the merged run exited $rc"
printf '%s\n' "$out" | grep -q '"gate-a","PASS"' && ok "branch A's gate ran" || bad "branch A's gate did not run"
printf '%s\n' "$out" | grep -q '"gate-b","PASS"' && ok "branch B's gate ran" || bad "branch B's gate did not run"
printf '%s\n' "$out" | grep -q '"base","PASS"'   && ok "the gate already there still ran" || bad "a pre-existing gate was dropped"
order="$(printf '%s\n' "$out" | grep -oE '"(base|gate-a|gate-b)"' | tr -d '"' | tr '\n' ' ')"
[ "$order" = "base gate-a gate-b " ] \
  && ok "the rows follow the files' order (C order is numeric order)" \
  || bad "the rows came out as: $order"

# ── 3. a gate file that fails, fails the run ────────────────────────────────
D="$T/checks-fail"; mkdir -p "$D"
cat >"$D/0010-good.sh" <<'GATE'
gate good "a gate that holds" bash -c 'exit 0'
GATE
cat >"$D/0020-bad.sh" <<'GATE'
gate bad "a gate that refuses" bash -c 'echo the fault it found; exit 1'
GATE
out="$(run_driver "$D")"; rc=$?
[ "$rc" -eq 1 ] && ok "a failing gate file fails the run (exit 1)" || bad "a failing gate exited $rc, not 1"
printf '%s\n' "$out" | grep -q '"bad","FAIL"' && ok "the failing gate prints its FAIL row" || bad "no FAIL row for the failing gate"
printf '%s\n' "$out" | grep -q 'the fault it found' && ok "the failing gate's own output is printed" || bad "the failing gate's output was swallowed"
grep -q '^bad' "$T/verdict.txt" && ok "the failing gate is written to the verdict file (one door for a red main)" || bad "the verdict file does not name the failing gate"

# ── 4. a gate file that cannot load is a FAIL, not a skip ───────────────────
D="$T/checks-broken"; mkdir -p "$D"
cat >"$D/0010-good.sh" <<'GATE'
gate good "a gate that holds" bash -c 'exit 0'
GATE
printf 'this is not shell: then\n' >"$D/0020-broken.sh"
out="$(run_driver "$D")"; rc=$?
[ "$rc" -eq 1 ] && ok "an unloadable gate file fails the run (exit 1)" || bad "an unloadable gate file exited $rc, not 1"
printf '%s\n' "$out" | grep -q '"0020-broken.sh","FAIL"' && ok "the unloadable gate is named as a FAIL row" || bad "an unloadable gate was silently skipped"

# ── 5. an empty gate directory is not a green ───────────────────────────────
D="$T/checks-empty"; mkdir -p "$D"
out="$(run_driver "$D")"; rc=$?
[ "$rc" -ne 0 ] && ok "an empty gate directory refuses (exit $rc, never 0)" || bad "an empty gate directory exited 0 — a false green"
printf '%s\n' "$out" | grep -qi 'no gate' && ok "it says the list is empty, aloud" || bad "an empty directory said nothing"
out="$( cd "$R" && YMIR_GATE_CHECK_DIR="$T/does-not-exist" bash "$R/bin/gates/ci-verify.sh" 2>&1 )"; rc=$?
[ "$rc" -ne 0 ] && ok "a missing gate directory refuses (exit $rc)" || bad "a missing gate directory exited 0"

# ── 6. the real tree: a gate is a FILE, never a line in the driver ──────────
if grep -qE '^\s*gate\s+[a-z0-9-]+' "$ROOT/bin/gates/ci-verify.sh"; then
  bad "ci-verify.sh still carries a gate line — the conflict point is back"
else
  ok "ci-verify.sh carries no gate line: adding a gate is adding a file"
fi
n_gates="$(grep -hcE '^\s*gate\s+[a-z0-9-]+' "$ROOT"/bin/gates/checks.d/*.sh 2>/dev/null | awk '{s+=$1} END {print s+0}')"
[ "${n_gates:-0}" -ge 40 ] \
  && ok "the real gate list holds $n_gates gates, one file each" \
  || bad "the real gate directory holds only ${n_gates:-0} gates — the list has shrunk"

printf 'gate-directory-test: %s pass, %s fail\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
