#!/usr/bin/env bash
# gate-integrity.test.sh — the two wards that would have caught 2026-10-18.
#
# 1. rules-number-guard: a rule number claimed twice, a rule with no index row, a
#    stale index count — each must FAIL, and a clean tree must pass.
# 2. branch-current: a branch behind its base must FAIL (that is the answer to "did
#    you pull latest"), a current branch must pass, and the loud escape must work.
#
# Both are tested against throwaway trees, never this repository's state.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RNG="$ROOT/bin/gates/guards/rules-number-guard.sh"
BCH="$ROOT/bin/gates/branch-current.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── 1 · rules-number-guard ────────────────────────────────────────────────────
mk_rules_tree() {  # <dir> <dup?>
  local d=$1 dup=${2:-no}
  mkdir -p "$d/RULES" "$d/bin"
  printf '# 20 — the well appends\n' >"$d/RULES/20-the-well-appends.md"
  printf '# 21 — company documents\n' >"$d/RULES/21-company-documents.md"
  if [ "$dup" = yes ]; then printf '# 22 — another rule\n' >"$d/RULES/22-home-layout.md"; fi
  cat >"$d/RULES/README.md" <<'IDX'
# RULES

```
rules_index[2]{file,subject}:
  "20-the-well-appends.md","the well appends"
  "21-company-documents.md","company documents"
```
IDX
}

T="$TMP/clean"; mk_rules_tree "$T" no
YMIR_GUARD_ROOT="$T" bash "$RNG" check >/dev/null 2>&1 && ok "a clean rules tree passes" || bad "clean tree failed"

T="$TMP/dup"; mk_rules_tree "$T" yes
YMIR_GUARD_ROOT="$T" bash "$RNG" check >/dev/null 2>&1 && bad "a duplicate number passed" || ok "a duplicate rule number FAILS"

T="$TMP/dup"; YMIR_GUARD_ROOT="$T" bash "$RNG" check 2>&1 | grep -q 'no index row' && ok "an indexed-but-unnamed rule is caught" || bad "missing index row not caught"

T="$TMP/clean"; printf '# 23 — unlisted\n' >"$T/RULES/23-unlisted.md"
YMIR_GUARD_ROOT="$T" bash "$RNG" check 2>&1 | grep -q 'no index row' && ok "a rule with no README row FAILS" || bad "unlisted rule not caught"

T="$TMP/clean"
YMIR_GUARD_ROOT="$T" bash "$RNG" check 2>&1 | grep -q 'index count is stale' && ok "a stale rules_index count FAILS" || bad "stale count not caught"

# ── 2 · branch-current ────────────────────────────────────────────────────────
REPO="$TMP/repo"; mkdir -p "$REPO" && cd "$REPO" || exit 1
git init -q -b main .; git config user.email t@t; git config user.name t
mkdir -p bin RULES; printf 'x\n' >README.md; git add -A; git commit -qm one
BASE1="$(git rev-parse HEAD)"
printf 'y\n' >second.txt; git add -A; git commit -qm two
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
# a branch that stops at the first commit is BEHIND origin/main
git checkout -q -b feature "$BASE1"
out="$(bash "$BCH" check 2>&1)"; rc=$?
[ "$rc" = 1 ] && ok "a branch behind its base FAILS (the answer to 'did you pull')" || bad "behind branch rc=$rc: $out"
printf '%s' "$out" | grep -q 'behind origin/main' && ok "it says how far behind, and against what" || bad "message: $out"

YMIR_ALLOW_STALE_BRANCH="a long-lived branch by design" bash "$BCH" check >/dev/null 2>&1 \
  && ok "the loud escape is honoured" || bad "escape refused"

# rebased onto the base: current
git rebase -q origin/main >/dev/null 2>&1
bash "$BCH" check >/dev/null 2>&1 && ok "a current branch passes" || bad "current branch failed"

# warn mode never blocks
git checkout -q -B stale "$BASE1"
bash "$BCH" warn >/dev/null 2>&1 && ok "warn mode reports without blocking" || bad "warn mode blocked"

# main itself is never asked to rebase
git checkout -q main
bash "$BCH" check >/dev/null 2>&1 && ok "main is not asked to rebase onto itself" || bad "main was refused"

cd "$ROOT" || exit 1
[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
