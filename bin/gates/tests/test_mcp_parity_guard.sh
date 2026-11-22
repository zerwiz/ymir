#!/usr/bin/env bash
# test_mcp_parity_guard.sh — a door in the register with no MCP tool fails the ward; a waiting door does not.
set -uo pipefail
HERE="$(readlink -f "${BASH_SOURCE[0]%/*}")"
ROOT="$(dirname "$(dirname "$(dirname "$HERE")")")"
fail=0; ok() { printf 'ok   %s\n' "$1"; }; bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }
G="$ROOT/bin/gates/guards/mcp-parity-guard.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin/mcp" "$T/bin/x"; : > "$T/bin/x/door.sh"
cat > "$T/bin/mcp/ymir-mcp.py" <<'PY'
@mcp.tool()
def ymir_have(a: str = "") -> str:
    return a
PY
printf 'doors:\n  - {door: bin/x/door.sh, tool: ymir_have, what: a}\n' > "$T/bin/mcp/doors.yaml"
"$G" --repo "$T" >/dev/null && ok "a door with its tool passes" || bad "a door with its tool passes"
printf '  - {door: bin/x/door.sh, tool: ymir_missing, what: b}\n' >> "$T/bin/mcp/doors.yaml"
out="$("$G" --repo "$T")" && bad "a door with no tool fails" || { echo "$out" | grep -q ymir_missing && ok "a door with no tool fails, and names it" || bad "names the tool"; }
printf 'doors:\n  - {door: bin/x/nope.sh, tool: ymir_have, what: c}\n' > "$T/bin/mcp/doors.yaml"
"$G" --repo "$T" >/dev/null && bad "a door not in the tree fails" || ok "a door not in the tree fails"
printf 'doors:\n  - {door: bin/x/nope.sh, tool: ymir_later, when: it is built, what: d}\n' > "$T/bin/mcp/doors.yaml"
"$G" --repo "$T" >/dev/null && ok "a waiting door is not judged until its file exists" || bad "a waiting door is skipped"
"$G" >/dev/null && ok "this tree: every registered door has its tool" || bad "this tree is clean"
printf 'mcp-parity-guard test: %s failure(s)\n' "$fail"; exit "$([ "$fail" -eq 0 ] && echo 0 || echo 1)"
