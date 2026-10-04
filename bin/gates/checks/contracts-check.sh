#!/usr/bin/env bash
# contracts-check.sh — the typed surfaces' proof, in one command.
#
# Plan 58 Phase 6. ONE typed A2A/agent-card contract (packages/contracts) is
# imported by two consumers — the A2A server (packages/a2a/ratatoskr) and
# Hlidskjalf (apps/hlidskjalf). This gate proves it:
#
#   · the contract tests pass (node --test; a deliberately mismatched card must
#     be refused, naming the field)
#   · the contract type-checks on its own
#   · the A2A server's card module type-checks against it (the server consumer)
#   · Hlidskjalf type-checks against it (the UI consumer), when its deps are present
#
# The tsc legs SKIP loudly when tsc (or Hlidskjalf's node_modules) is absent: CI
# checks out without an install, and a gate that cannot run must say so, never
# fail the push.
#
# Usage: bin/contracts-check.sh [--version]
# Exit: 0 pass · 1 fail · 2 usage.
set -u
VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_root() {
  local d; d="$(cd "$SCRIPT_DIR" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/.pi" ] && [ -d "$d/RULES" ] && { printf '%s' "$d"; return 0; }
    d="$(dirname "$d")"
  done
  printf '%s' "$(cd "$SCRIPT_DIR/../.." && pwd)"
}
ROOT="${BROKK_ROOT_OVERRIDE:-$(_root)}"
cd "$ROOT" || exit 2

case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "") ;;
  *) printf 'error: unknown flag %s\n' "${1-}" >&2; exit 2 ;;
esac

fail=0
say() { printf '%s\n' "$*"; }

say 'contracts_check[4]{leg,status,detail}:'

# 1. the contract tests — no dependencies, always runnable.
#    The GLOB is load-bearing: `node --test <dir>` is not a stable contract across
#    node majors. Node 24 resolves the argument as a module entry point and dies
#    with "Cannot find module .../test" (MODULE_NOT_FOUND); node 26 treats it as a
#    directory and passes. Passing the FILES (the shell expands the glob) is
#    correct on every version this repo supports, so the gate's verdict cannot
#    depend on which node the room happens to have.
if out="$(node --test packages/contracts/test/*.test.ts 2>&1)"; then
  say "  \"tests\",\"PASS\",\"$(printf '%s' "$out" | grep -oE 'pass [0-9]+' | tail -1) · a mismatched card is refused\""
else
  say "  \"tests\",\"FAIL\",\"node --test packages/contracts/test/*.test.ts\""
  printf '%s\n' "$out" | tail -12 | sed 's/^/    /'
  fail=1
fi

# tsc: from the tree or PATH; a missing tsc is a loud SKIP, never a false FAIL.
TSC=""
if command -v tsc >/dev/null 2>&1; then
  TSC="tsc"
elif command -v npx >/dev/null 2>&1 && npx --no-install tsc --version >/dev/null 2>&1; then
  TSC="npx --no-install tsc"
fi

tsc_leg() {  # <name> <project>
  local name="$1" proj="$2"
  if [ -z "$TSC" ]; then
    say "  \"$name\",\"SKIP\",\"tsc not found on this machine\""
    return 0
  fi
  # The gate's own rule, applied to EVERY tsc leg: CI checks out without an
  # install, so a project with no node_modules cannot resolve its type
  # definitions. That is a gate that cannot run — say so, never fail the push.
  # (The contract and the A2A server were the two legs that forgot this, and
  #  they failed CI with TS2688 "Cannot find type definition file for 'node'"
  #  on a checkout that had never been installed.)
  if ! modules_present; then
    say "  \"$name\",\"SKIP\",\"no node_modules — run npm install to type-check $proj\""
    return 0
  fi
  if out="$($TSC --noEmit -p "$proj" 2>&1)"; then
    say "  \"$name\",\"PASS\",\"$proj\""
  else
    say "  \"$name\",\"FAIL\",\"$proj\""
    printf '%s\n' "$out" | head -12 | sed 's/^/    /'
    fail=1
  fi
}

# 3. Hlidskjalf — the UI consumer. Its project needs node_modules to resolve
#    react/etc.; without them the leg is skipped, not failed. A worktree may
#    borrow its primary checkout's node_modules up-tree, so search upward.
#    Defined before every tsc_leg call: bash resolves at CALL time, so a leg
#    that asked earlier would have found no such command and skipped itself.
modules_present() {
  local d="$ROOT"
  for _ in 1 2 3 4; do
    [ -d "$d/node_modules" ] && return 0
    d="$(dirname "$d")"
  done
  return 1
}

tsc_leg contract packages/contracts/tsconfig.json
tsc_leg a2a-server packages/a2a/ratatoskr/tsconfig.json
if modules_present; then
  tsc_leg hlidskjalf apps/hlidskjalf/tsconfig.json
else
  say "  \"hlidskjalf\",\"SKIP\",\"no node_modules — run npm install to check the UI consumer\""
fi

if [ "$fail" = 0 ]; then
  say 'contracts-check: PASS — one contract, two consumers, and a mismatched card refused.'
  exit 0
fi
printf 'contracts-check: a leg failed — see the FAIL row above\n' >&2
exit 1
