#!/usr/bin/env bash
# topology.test.sh — the resolver answers the three questions correctly:
# attached (heart reachable), detached (network, no heart), standalone (no heart).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$ROOT/bin/topology.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

# attached: 127.0.0.1 always answers
out="$(YMIR_HOST=testbox YMIR_HEART=127.0.0.1 YMIR_LINK_TIMEOUT=1 bash "$T")"
printf '%s' "$out" | grep -q '"link","attached"' && ok "reachable heart -> attached" || bad "attached: $out"

# detached: a name that cannot resolve or answer
out="$(YMIR_HOST=testbox YMIR_HEART=no-such-host-xyz-12345.invalid YMIR_LINK_TIMEOUT=1 bash "$T")"
printf '%s' "$out" | grep -q '"link","detached"' && ok "unreachable heart -> detached" || bad "detached: $out"

# standalone: no heart configured
out="$(YMIR_HOST=testbox YMIR_HEART=none bash "$T")"
printf '%s' "$out" | grep -q '"link","standalone"' && ok "no heart -> standalone" || bad "standalone: $out"

# a missing registry degrades cleanly (role dev, no crash)
out="$(YMIR_HOST=testbox YMIR_FLEET_REGISTRY=/nonexistent/fleet.json YMIR_HEART=none bash "$T")"
printf '%s' "$out" | grep -q '"roles","dev"' && ok "missing registry -> default role dev" || bad "no registry: $out"

# json mode parses
out="$(YMIR_HOST=testbox YMIR_HEART=none bash "$T" --json)"
printf '%s' "$out" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s))' 2>/dev/null \
  && ok "json mode parses" || bad "json: $out"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
