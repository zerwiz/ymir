#!/usr/bin/env bash
# mcp-config.sh — generate the harness MCP config from THIS machine's ROLE.
#
# Plan 51 (multi-machine operations), Phase 3. An MCP address is never a literal
# LAN IP in a synced config: the record servers (well/engram, tickets/skuld,
# skills/bolthorn) live on the HEART, and every body addresses them by the heart's
# name — 127.0.0.1 when this machine IS the heart, the heart's tailnet name
# otherwise. Firecrawl is local (stdio). One shape per role, generated, not
# hand-edited per machine.
#
#   mcp-config.sh            # this machine's config (JSON) to stdout
#   mcp-config.sh show       # the same
#   mcp-config.sh write      # write $HOME/.pi/agent/mcp.json (backup kept)
#   mcp-config.sh --version
#
# Env: YMIR_FLEET_REGISTRY · YMIR_HOST · YMIR_MCP_WELL_PORT (8317) ·
#      YMIR_MCP_SKILLS_PORT (8319) · YMIR_MCP_TICKETS_PORT (8320)
set -u

VERSION="1.0.0"
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
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME:-$HOME/Documents/ymirhome}}"
REGISTRY="${YMIR_FLEET_REGISTRY:-$YMIR_HOME_ROOT/hodd/data/fleet.json}"
HOST="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
WELL_PORT="${YMIR_MCP_WELL_PORT:-8317}"
SKILLS_PORT="${YMIR_MCP_SKILLS_PORT:-8319}"
TICKETS_PORT="${YMIR_MCP_TICKETS_PORT:-8320}"

CONFIG="$(python3 - "$REGISTRY" "$HOST" "$WELL_PORT" "$SKILLS_PORT" "$TICKETS_PORT" <<'PY'
import json, sys
reg, me, wp, sp, tp = sys.argv[1:6]
try: doc = json.load(open(reg))
except Exception: doc = {}
hosts = doc.get("hosts") or {}
heart = str(doc.get("heart") or "localhost")
mine = (hosts.get(me) or {}).get("roles") or ["dev"]
hh = hosts.get(heart) or {}
addr = "127.0.0.1" if ("heart" in mine or not heart or heart == "localhost") else str(hh.get("tailnet") or hh.get("lan") or heart)
# strip a trailing /mcp if the registry stored one
print(json.dumps({
  "mcpServers": {
    "well":     {"url": f"http://{addr}:{wp}/mcp"},
    "bolthorn": {"url": f"http://{addr}:{sp}/mcp"},
    "skuld":    {"url": f"http://{addr}:{tp}"},
    "firecrawl": {"command": "npx", "args": ["-y", "firecrawl-mcp"],
                  "env": {"FIRECRAWL_API_URL": "http://localhost:3002"}},
  }
}, indent=2))
PY
)"

case "$MODE" in
  show|--json|"") printf '%s\n' "$CONFIG" ;;
  write)
    dest="$HOME/.pi/agent/mcp.json"
    mkdir -p "$(dirname "$dest")"
    [ -f "$dest" ] && cp "$dest" "$dest.bak-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || true
    printf '%s\n' "$CONFIG" >"$dest"
    printf 'mcp-config: wrote %s (host=%s)\n' "$dest" "$HOST"
    ;;
  *) printf 'error: unknown action %s\nhelp: mcp-config.sh [show|write]\n' "$MODE" >&2; exit 2 ;;
esac
