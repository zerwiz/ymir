#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
DOOR="$ROOT/bin/agents/name-registry.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf 'FAIL %s — %s\n' "$1" "${2-}"; }
check(){ local n=$1; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }
refute(){ local n=$1; shift; if "$@" >/dev/null 2>&1; then bad "$n" "expected refusal"; else ok "$n"; fi; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export YMIR_HOME="$TMP/home"; mkdir -p "$YMIR_HOME/hodd/identity"
printf 'mimir\nsnotra\n' > "$YMIR_HOME/hodd/identity/reserved-names.txt"
printf 'seats:\n  seat-a: {primary: counsellor, role: t, status: proposed}\n' > "$YMIR_HOME/hodd/identity/seats.yaml"
check "scan builds the registry" "$DOOR" scan
check "a reserved subsystem is refused as a seat persona" bash -c "! '$DOOR' check mimir --as seat-persona"
check "a persona is accepted" bash -c "'$DOOR' check brokk --as seat-persona"
check "a host is refused as a persona" bash -c "! '$DOOR' check seat-a --as seat-persona"
check "list works" bash -c "'$DOOR' list | grep -q brokk"
check "collisions reports" bash -c "'$DOOR' collisions | grep -q collisions"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
