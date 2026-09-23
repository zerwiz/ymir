#!/usr/bin/env bash
# mcp-config.test.sh — the MCP config is generated from ROLE (plan 51 P3):
# a body addresses the heart; the heart uses loopback.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
M="$ROOT/bin/mcp-config.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat >"$TMP/f.json" <<'EOF'
{"heart":"h1","hosts":{"h1":{"roles":["heart"],"tailnet":"h1.tail.ts.net"},"d1":{"roles":["dev"],"tailnet":"d1.tail.ts.net"}}}
EOF
export YMIR_FLEET_REGISTRY="$TMP/f.json"

# a dev body addresses the heart, never a literal LAN IP
out="$(YMIR_HOST=d1 bash "$M" 2>/dev/null)"
printf '%s' "$out" | grep -q 'h1.tail.ts.net:8317' && ok "body: well points at the heart" || bad "body well: $out"
printf '%s' "$out" | grep -q 'h1.tail.ts.net:8320' && ok "body: tickets point at the heart" || bad "body tickets: $out"

# the heart itself uses loopback
out="$(YMIR_HOST=h1 bash "$M" 2>/dev/null)"
printf '%s' "$out" | grep -q '127.0.0.1:8317' && ok "heart: well is loopback" || bad "heart well: $out"
printf '%s' "$out" | grep -q 'h1.tail.ts.net' && bad "heart should not use its own tailnet name" || ok "heart: no self-addressing"

# the config parses as JSON
YMIR_HOST=d1 bash "$M" 2>/dev/null \
  | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s))' 2>/dev/null \
  && ok "config parses as JSON" || bad "config did not parse"

# no registry -> loopback default, no crash
out="$(YMIR_FLEET_REGISTRY=/nonexistent/f.json bash "$M" 2>/dev/null)"
printf '%s' "$out" | grep -q '127.0.0.1:8317' && ok "no registry -> loopback default" || bad "no registry: $out"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
