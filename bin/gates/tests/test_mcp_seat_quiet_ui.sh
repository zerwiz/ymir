#!/usr/bin/env bash
# test_mcp_seat_quiet_ui.sh — a fresh seat opens no UI window per MCP call (plan 324 F11).
#
# pi's MCP adapter opens a viewer for every tool call unless a server says `openUi: false`; in a
# browser that is a new tab per call. The fix was first made by hand on one box. This proves the
# install and update road (bin/bridge/mcp-config-seat.py, the `pi` seat) writes it for every server,
# and keeps an operator's explicit `openUi: true`.
#
# Fenced: HOME, the pi source and the pin are all inside a temporary directory; nothing real is read
# or written.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.pi/agent"
cat >"$TMP/.pi/agent/mcp-adapter.json" <<'J'
{"mcpServers": {
  "board":  {"url": "https://board.example.invalid/mcp"},
  "tools":  {"command": "tool-server", "args": ["--stdio"]},
  "viewer": {"url": "https://viewer.example.invalid/mcp", "openUi": true}
}}
J
HOME="$TMP" YMIR_RUNTIME_DIR="$TMP/none" python3 "$ROOT/bin/bridge/mcp-config-seat.py" 4600 \
  "$TMP/.pi/agent/mcp-adapter.json" pi >/dev/null 2>&1
rc=0
for f in mcp-adapter.json mcp.json; do
  python3 - "$TMP/.pi/agent/$f" <<'PY' || rc=1
import json, sys
d = json.load(open(sys.argv[1]))["mcpServers"]
quiet = sorted(n for n, s in d.items() if s.get("openUi") is False)
loud = sorted(n for n, s in d.items() if s.get("openUi") is not False)
ok = "board" in quiet and "tools" in quiet and loud == ["viewer"] and all(n in quiet for n in ("well", "bolthorn", "skuld"))
print(f"  {sys.argv[1].rsplit('/', 1)[1]}: quiet={quiet} kept-open={loud} -> {'ok' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
PY
done
[ "$rc" = 0 ] && echo "mcp seat quiet-ui self-test: PASS" || echo "mcp seat quiet-ui self-test: FAIL"
exit "$rc"
