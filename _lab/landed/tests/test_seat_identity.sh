#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/.." && pwd)"
DOOR="$ROOT/bin/agents/seat-identity.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf 'ok   %s\n' "$1"; }
bad(){ FAIL=$((FAIL+1)); printf 'FAIL %s — %s\n' "$1" "${2-}"; }
check(){ local n=$1; shift; if "$@" >/dev/null 2>&1; then ok "$n"; else bad "$n"; fi; }
refute(){ local n=$1; shift; if "$@" >/dev/null 2>&1; then bad "$n" "expected failure"; else ok "$n"; fi; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"; mkdir -p "$HOME/.pi/agent/extensions"
export YMIR_HOME="$TMP/ymir"; mkdir -p "$YMIR_HOME/hodd/identity" "$YMIR_HOME/hodd/data/agent-cards"
HOST="$(hostname -s)"
cat > "$YMIR_HOME/hodd/identity/seats.yaml" <<YAML
version: 1
seats:
  seat-a: {primary: counsellor, role: counsellor, status: proposed}
  $HOST:  {primary: brokk, role: tester, status: proposed}
YAML

check "list prints a seat" bash -c "'$DOOR' --list | grep -q 'seat-a'"
check "name resolves for any seat" bash -c "[ \"\$('$DOOR' seat-a)\" = counsellor ]"
check "unknown host is refused" bash -c "! '$DOOR' nope"
check "ensure installs this host" bash -c "'$DOOR' --ensure '$HOST' >/dev/null; test -f '$HOME/.pi/agent/extensions/.ymir-seat'"
check "check passes after install" bash -c "'$DOOR' --check '$HOST' | grep -q ok"
refute "set without a name is refused" "$DOOR" set "$HOST"
check "names lists the naming law" bash -c "'$DOOR' --names | grep -qx brokk"
refute "a name outside the naming law is refused" "$DOOR" set "$HOST" NotAGod tester
check "set seals a new name" "$DOOR" set "$HOST" brokk tester
check "set updated the roster" bash -c "grep -q 'sealed' '$YMIR_HOME/hodd/identity/seats.yaml'"
check "render writes the identity" bash -c "'$DOOR' --render '$HOST' >/dev/null; grep -q 'This seat: $HOST' '$HOME/.pi/agent/AGENTS.seat.md'"
check "render includes the shared contract" bash -c "grep -q 'YMIR AGENT OPERATING SYSTEM' '$HOME/.pi/agent/AGENTS.seat.md'"
check "another host is not installed locally" bash -c "'$DOOR' --install seat-a | grep -q skipped"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
