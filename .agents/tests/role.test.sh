#!/usr/bin/env bash
# role.test.sh — declare, read, and validate a machine's role (plan 51 P1).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
R="$ROOT/bin/role.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export YMIR_FLEET_REGISTRY="$TMP/fleet.json"

# set + show
bash "$R" set box1 heart,forge >/dev/null 2>&1
out="$(bash "$R" show box1 2>/dev/null)"
printf '%s' "$out" | grep -q '"box1","heart,forge"' && ok "set + show returns the roles" || bad "show: $out"

# a second host joins; the roster grows
bash "$R" set box2 dev >/dev/null 2>&1
out="$(bash "$R" show 2>/dev/null)"
printf '%s' "$out" | grep -q '"box2","dev"' && ok "roster includes a new host" || bad "roster: $out"

# an unknown role is refused (exit 2)
bash "$R" set box3 wizard >/dev/null 2>&1 && bad "unknown role was accepted" || ok "unknown role refused"

# validate passes for known roles
bash "$R" validate >/dev/null 2>&1 && ok "validate passes for known roles" || bad "validate failed on known roles"

# validate fails when a role is unknown (hand-written registry)
printf '{"heart":"box1","hosts":{"box1":{"roles":["wizard"]}}}\n' >"$TMP/bad.json"
YMIR_FLEET_REGISTRY="$TMP/bad.json" bash "$R" validate >/dev/null 2>&1 && bad "validate accepted an unknown role" || ok "validate rejects an unknown role"

# rm removes a host
bash "$R" rm box2 >/dev/null 2>&1
out="$(bash "$R" show 2>/dev/null)"
printf '%s' "$out" | grep -q '"box2"' && bad "rm left the host" || ok "rm removes a host row"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
