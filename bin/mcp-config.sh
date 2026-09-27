#!/usr/bin/env bash
# mcp-config.sh — generate the harness MCP config: ONE local gateway door.
#
# Plan 51 (multi-machine operations), Phase 3 + 6. An MCP address is never a
# literal LAN IP in a synced config, and it is never the heart directly: the
# record servers (well/engram, tickets/skuld, skills/bolthorn) are fronted by
# THIS body's own gateway (`bin/mcp-gateway.sh`, :8316), which resolves the
# heart's address at request time. A heart-address change re-resolves inside the
# gateway; the seat's config never moves. Firecrawl stays local (stdio).
#
#   mcp-config.sh            # this machine's config (JSON) to stdout
#   mcp-config.sh show       # the same
#   mcp-config.sh write      # write $HOME/.pi/agent/mcp-adapter.json (backup kept)
#   mcp-config.sh --version
#
# Env: YMIR_MCP_GATEWAY_PORT (8316, alias MCP_GATEWAY_PORT)
set -u

VERSION="2.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
MODE="${1:-show}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null; fi
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME}}"
GATEWAY_PORT="${MCP_GATEWAY_PORT:-${YMIR_MCP_GATEWAY_PORT:-8316}}"

CONFIG="$(python3 - "$GATEWAY_PORT" <<'PY'
import json, sys
gp = sys.argv[1]
base = f"http://127.0.0.1:{gp}/mcp"
print(json.dumps({
  "mcpServers": {
    "well":     {"url": f"{base}/well"},
    "bolthorn": {"url": f"{base}/bolthorn"},
    "skuld":    {"url": f"{base}/skuld"},
    "firecrawl": {"command": "npx", "args": ["-y", "firecrawl-mcp"],
                  "env": {"FIRECRAWL_API_URL": "http://localhost:3002"}},
  }
}, indent=2))
PY
)"

case "$MODE" in
  show|--json|"") printf '%s\n' "$CONFIG" ;;
  write)
    dest="$HOME/.pi/agent/mcp-adapter.json"
    mkdir -p "$(dirname "$dest")"
    [ -f "$dest" ] && cp "$dest" "$dest.bak-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || true
    printf '%s\n' "$CONFIG" >"$dest"
    printf 'mcp-config: wrote %s (gateway :%s)\n' "$dest" "$GATEWAY_PORT"
    ;;
  *) printf 'error: unknown action %s\nhelp: mcp-config.sh [show|write]\n' "$MODE" >&2; exit 2 ;;
esac
