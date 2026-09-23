#!/usr/bin/env bash
# fleet-version.test.sh — the verdict logic: in sync · drift (exit 1) · json.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FV="$ROOT/bin/fleet-version.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# the installed version (the real npm global), so we can make the tree MATCH it
inst="$(bash "$FV" --json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("installed") or "")')"

# 1. tree matching the install -> never 'drift' (may be behind/ahead of published)
if [ -n "$inst" ]; then
  mkdir -p "$TMP/sync"; printf '{"name":"@zerwiz/ymir","version":"%s"}\n' "$inst" >"$TMP/sync/package.json"
  out="$(BROKK_ROOT_OVERRIDE="$TMP/sync" bash "$FV" 2>/dev/null)"
  printf '%s' "$out" | grep -q '"verdict","drift"' && bad "matching tree reported drift: $out" || ok "tree == installed -> not drift"
else
  ok "no global install to compare (skipped matching-tree case)"
fi

# 2. tree differing from the install -> drift, check exits 1
mkdir -p "$TMP/drift"; printf '{"name":"@zerwiz/ymir","version":"0.0.1"}\n' >"$TMP/drift/package.json"
out="$(BROKK_ROOT_OVERRIDE="$TMP/drift" bash "$FV" 2>/dev/null)"
printf '%s' "$out" | grep -q '"verdict","drift"' && ok "tree != installed -> drift" || bad "drift: $out"
BROKK_ROOT_OVERRIDE="$TMP/drift" bash "$FV" check >/dev/null 2>&1 && bad "check did not exit 1 on drift" || ok "check exits 1 on drift"

# 3. json parses
BROKK_ROOT_OVERRIDE="$TMP/drift" bash "$FV" --json 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s))' 2>/dev/null \
  && ok "json mode parses" || bad "json mode did not parse"

# 4. a missing package.json degrades cleanly
mkdir -p "$TMP/none"
out="$(BROKK_ROOT_OVERRIDE="$TMP/none" bash "$FV" 2>/dev/null)"
printf '%s' "$out" | grep -q '"verdict","unknown"' && ok "no package.json -> unknown, no crash" || bad "unknown: $out"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
