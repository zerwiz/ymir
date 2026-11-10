#!/usr/bin/env bash
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../../.." && pwd)
DOOR="$ROOT/bin/seat/roster.sh"
pass=0; fail=0
ok(){ pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad(){ fail=$((fail+1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# clean fixture: one herdr agent, one ps process
cat > "$TMP/herdr.json" <<'JSON'
{"result":{"agents":[{"pane_id":"w1:p1","name":"primary","agent_status":"working","cwd":"/tmp/wt","agent":"pi"}]}}
JSON
cat > "$TMP/ps.txt" <<'PS'
1234 pi pi --session
PS

# line
out=$(ROSTER_HERDR_FIXTURE="$TMP/herdr.json" ROSTER_PS_FIXTURE="$TMP/ps.txt" "$DOOR" line)
echo "$out" | grep -q "roster: 1 seats" && ok "line counts" || bad "line counts" "$out"

# --check clean
ROSTER_HERDR_FIXTURE="$TMP/herdr.json" ROSTER_PS_FIXTURE="$TMP/ps.txt" "$DOOR" --check >/dev/null 2>&1 && ok "clean check exits 0" || bad "clean check exits 0"

# two seats one role -> finding
cat > "$TMP/herdr2.json" <<'JSON'
{"result":{"agents":[{"pane_id":"w1:p1","name":"primary","agent_status":"working","cwd":"/tmp/wt","agent":"pi"},{"pane_id":"w2:p1","name":"primary","agent_status":"idle","cwd":"/tmp/wt2","agent":"pi"}]}}
JSON
if ROSTER_HERDR_FIXTURE="$TMP/herdr2.json" ROSTER_PS_FIXTURE="$TMP/ps.txt" "$DOOR" --check >/dev/null 2>&1; then bad "dup role exits 1"; else ok "dup role exits 1"; fi

# unowned process -> finding
cat > "$TMP/ps2.txt" <<'PS'
1234 pi pi --session
5678 opencode opencode serve
PS
if ROSTER_HERDR_FIXTURE="$TMP/herdr.json" ROSTER_PS_FIXTURE="$TMP/ps2.txt" "$DOOR" --check >/dev/null 2>&1; then bad "unowned exits 1"; else ok "unowned exits 1"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
