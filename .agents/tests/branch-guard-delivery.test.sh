#!/usr/bin/env bash
# Unit tests for bin/gates/guards/branch-guard.sh — Rule 08, the delivery gate.
#
# The defect this test exists for: in hook mode the guard read the pushed refs
# from stdin, but BEFORE the loop it also judged the branch you were *standing
# on*. So with HEAD = main, every push was refused as "a direct push to main" —
# including `git push origin --delete <a-merged-feature-branch>`, which does not
# land on main at all. Deleting a merged branch therefore needed --no-verify, and
# a gate that must be routinely overridden is a gate nobody trusts.
#
# What the law actually says (RULES/08): a push may not LAND on a protected
# branch. So the tests below check the DESTINATION ref, and the delete case.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/bin/gates/guards/branch-guard.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# A scratch repo the guard can root at. `_root()` walks up to a dir holding both
# `.pi` and `RULES`; without them the guard roots at the wrong place and scans
# nothing — so both are created here.
REPO="$TMP/repo"
mkdir -p "$REPO/bin/gates/guards" "$REPO/.pi" "$REPO/RULES"
cp "$GUARD" "$REPO/bin/gates/guards/branch-guard.sh"
chmod +x "$REPO/bin/gates/guards/branch-guard.sh"
git -C "$REPO" init -q -b main
git -C "$REPO" config user.email t@t
git -C "$REPO" config user.name t
ZERO=0000000000000000000000000000000000000000

run_stdin() {  # <refs-line…> -> exit code (stdin mode)
  printf '%s\n' "$@" | bash "$REPO/bin/gates/guards/branch-guard.sh" >/dev/null 2>&1
}

# ── 1. a FEATURE branch pushed while standing on main is ALLOWED ──────────────
# This is the bug: `git push origin my-feature` from main was refused.
if run_stdin "refs/heads/my-feature abc123 refs/heads/my-feature def456"; then
  ok "a feature branch may be pushed while HEAD is main"
else
  bad "pushing a feature branch from main was refused (the pre-check bug)"
fi

# ── 2. a push that LANDS on main is BLOCKED ──────────────────────────────────
if run_stdin "refs/heads/my-feature abc123 refs/heads/main def456"; then
  bad "a push landing on main was allowed"
else
  ok "a push landing on main is blocked"
fi

# ── 3. DELETING a merged feature branch is ALLOWED ───────────────────────────
# The delete line git feeds the hook: local ref "(delete)", local sha all-zero.
if run_stdin "(delete) $ZERO refs/heads/my-feature def456"; then
  ok "deleting a merged feature branch is allowed"
else
  bad "deleting a merged feature branch was refused"
fi

# ── 4. DELETING main is BLOCKED ──────────────────────────────────────────────
if run_stdin "(delete) $ZERO refs/heads/main def456"; then
  bad "deleting main was allowed"
else
  ok "deleting main is blocked"
fi

# ── 5. run by hand, no refs on stdin: judge the current branch ───────────────
# HEAD is main in this scratch repo, so the manual path must still block.
if bash "$REPO/bin/gates/guards/branch-guard.sh" </dev/null >/dev/null 2>&1; then
  bad "a manual run from main was allowed"
else
  ok "a manual run with no refs judges the current branch (main is blocked)"
fi

# ── 6. --branch refuses a protected name and accepts a feature name ──────────
if bash "$REPO/bin/gates/guards/branch-guard.sh" --branch main >/dev/null 2>&1; then
  bad "--branch main was allowed"
else
  ok "--branch main is blocked"
fi
if bash "$REPO/bin/gates/guards/branch-guard.sh" --branch my-feature >/dev/null 2>&1; then
  ok "--branch my-feature is allowed"
else
  bad "--branch my-feature was refused"
fi

printf '\n%s\n' "----------------------------------------"
if [ "$fail" = 0 ]; then printf 'branch-guard-delivery.test.sh: all passed\n'; else printf 'branch-guard-delivery.test.sh: FAILED\n' >&2; fi
exit "$fail"
