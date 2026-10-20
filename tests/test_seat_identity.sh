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
cat > "$YMIR_HOME/hodd/identity/seats.yaml" <<'YAML'
version: 1
seats:
  heimdall: {primary: brokk, role: counsellor, status: proposed}
YAML

check "list prints the seat" bash -c "'$DOOR' --list | grep -q 'heimdall'"
check "name resolves" bash -c "[ \"\$('$DOOR' heimdall)\" = brokk ]"
check "unknown host is refused" bash -c "! '$DOOR' nope"
check "ensure installs this host only" bash -c "HOSTNAME_SHORT=\$(hostname -s); '$DOOR' --ensure heimdall >/dev/null; test -f '$HOME/.pi/agent/extensions/.ymir-seat'"
check "check passes after install" bash -c "'$DOOR' --check heimdall | grep -q ok"
refute "set without a name is refused" "$DOOR" set heimdall
check "set seals a new name" "$DOOR" set heimdall brokk counsellor
check "set updated the roster" bash -c "grep -q 'sealed' '$YMIR_HOME/hodd/identity/seats.yaml'"
check "render writes the identity" bash -c "'$DOOR' --render heimdall >/dev/null; grep -q 'This seat: heimdall' '$HOME/.pi/agent/AGENTS.seat.md'"
check "render includes the shared contract" bash -c "grep -q 'YMIR AGENT OPERATING SYSTEM' '$HOME/.pi/agent/AGENTS.seat.md'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
