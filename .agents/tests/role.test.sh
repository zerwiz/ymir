#!/usr/bin/env bash
# role.test.sh — declare, read, and validate a machine's role (plan 51 P1).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
R="$ROOT/bin/skuld/role.sh"
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

# resolve — the read road the install gates on. Registry first...
unset YMIR_ROLE; export YMIR_MACHINES_MD="$TMP/machines.md"
printf '# Machines\n\n| machine | hostname | role |\n|---|---|---|\n' >"$YMIR_MACHINES_MD"
out="$(bash "$R" resolve --host box1 --why 2>/dev/null)"
[ "$out" = "heart,forge$(printf '\t')registry" ] && ok "resolve reads the registry by hostname" || bad "resolve registry: $out"

# ...then the machine card when the registry has no row
bash "$R" rm box1 >/dev/null 2>&1
printf '| `box1` | `box1` | **forge** — the GPU box |\n' >>"$YMIR_MACHINES_MD"
out="$(bash "$R" resolve --host box1 --why 2>/dev/null)"
[ "$out" = "forge$(printf '\t')card" ] && ok "resolve falls back to the machine card" || bad "resolve card: $out"

# a word that merely CONTAINS a role name is not a role
printf '| `box2` | `box2` | primary development |\n' >>"$YMIR_MACHINES_MD"
out="$(bash "$R" resolve --host box2 --why 2>/dev/null)"
[ "$out" = "$(printf '\t')none" ] && ok "'development' is not read as a role" || bad "false positive: $out"

# a host in neither resolves to NOTHING — the caller must ask, never guess
out="$(bash "$R" resolve --host ghost --why 2>/dev/null)"
[ "$out" = "$(printf '\t')none" ] && ok "an undeclared host resolves to nothing" || bad "undeclared: $out"

# an explicit role wins over both, and an unknown one is refused
out="$(YMIR_ROLE=hand bash "$R" resolve --host box1 --why 2>/dev/null)"
[ "$out" = "hand$(printf '\t')env" ] && ok "an explicit \$YMIR_ROLE wins" || bad "env: $out"
YMIR_ROLE=wizard bash "$R" resolve >/dev/null 2>&1 && bad "an unknown \$YMIR_ROLE was accepted" || ok "an unknown \$YMIR_ROLE is refused"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
