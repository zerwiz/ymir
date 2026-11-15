#!/usr/bin/env bash
# mcp-config.sh — generate the harness MCP config: ONE local gateway door.
#
# Plan 51 (multi-machine operations), Phase 3 + 6 + 9c. An MCP address is never a
# literal LAN IP in a synced config, and it is never the heart directly: the
# record servers (well/engram, tickets/skuld, skills/bolthorn) are fronted by
# THIS body's own gateway (`bin/bridge/mcp-gateway.sh`, :8316), which resolves the
# heart's address at request time. A heart-address change re-resolves inside the
# gateway; the seat's config never moves. Firecrawl stays local (stdio).
#
# The MODEL rail is the same law (Part 9c): the config carries where models come
# from as RESOLVED metadata under `ymir.rail`, read from the ONE resolver
# (`bin/model/rail-resolve.sh`), so no surface restates a rail URL. Harnesses read
# `mcpServers`; the `ymir` block is advisory and ignored by them.
#
# The WELL DOOR law (2026-11-10): engram is Völundr's engine only. Every harness reaches
# memory through the gateway's `well` door, never a direct `engram-mcp --db` stdio
# server — that one writes the seat's own file, skips the gateway journal, and never
# reaches the heart. And every harness carries the SAME set as pi's mcp-adapter.json
# (minus engram), generated from that one source by bin/bridge/mcp-config-seat.py.
#
#   mcp-config.sh                # the gateway doors (JSON) to stdout
#   mcp-config.sh show           # the same
#   mcp-config.sh write          # the pi half: a NAMED merge into ~/.pi/agent/mcp{,-adapter}.json (backup kept)
#   mcp-config.sh seat [--check] # every harness present: pi · opencode · claude · cursor · codex · hermes
#   mcp-config.sh harness <name> # the set in one harness's format (pi|opencode|claude|cursor|codex)
#   mcp-config.sh claude [--check] # the Claude seat alone (alias of `seat`'s claude half; no engram)
#   mcp-config.sh --version
#
# Env: YMIR_MCP_GATEWAY_PORT (8316, alias MCP_GATEWAY_PORT) · YMIR_MCP_ADAPTER (the pi
#      source, default ~/.pi/agent/mcp-adapter.json)
set -u

VERSION="2.1.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
MODE="${1:-show}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(CDPATH='' cd "$SCRIPT_DIR" && while [ ! -e "$PWD/.pi" ] || [ ! -d "$PWD/RULES" ]; do [ "$PWD" = / ] && break; cd ..; done; pwd)}"
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../vault/hoard-lib.sh" "$SCRIPT_DIR/../../vault/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null; fi
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME}}"
GATEWAY_PORT="${MCP_GATEWAY_PORT:-${YMIR_MCP_GATEWAY_PORT:-8316}}"
PI_SOURCE="${YMIR_MCP_ADAPTER:-$HOME/.pi/agent/mcp-adapter.json}"

# The model rail, resolved once (plan 51 Part 9c): the serving URL and its key
# REFERENCE, never a value. A declined answer (no live rail) leaves the block out.
RAIL_HOST=""; RAIL_URL=""; RAIL_KEY="LLAMA_SWAP_API_KEY"; _rail=""
if [ -x "$SCRIPT_DIR/../model/rail-resolve.sh" ]; then
  _rail="$(bash "$SCRIPT_DIR/../model/rail-resolve.sh" resolve --json 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
s=d.get("serving") or {}
print("%s\t%s\t%s" % (s.get("host") or "", s.get("url") or "", s.get("key_ref") or "LLAMA_SWAP_API_KEY"))' 2>/dev/null || true)"
  IFS=$'\t' read -r RAIL_HOST RAIL_URL RAIL_KEY <<EOF
$_rail
EOF
fi

CONFIG="$(python3 - "$GATEWAY_PORT" "$RAIL_HOST" "$RAIL_URL" "$RAIL_KEY" <<'PY'
import json, sys
gp, rail_host, rail_url, rail_key = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
base = f"http://127.0.0.1:{gp}/mcp"
doc = {
  "mcpServers": {
    "well":     {"url": f"{base}/well"},
    "bolthorn": {"url": f"{base}/bolthorn"},
    "skuld":    {"url": f"{base}/skuld"},
    "firecrawl": {"command": "npx", "args": ["-y", "firecrawl-mcp"],
                  "env": {"FIRECRAWL_API_URL": "http://localhost:3002"}},
  }
}
if rail_host:
    doc["ymir"] = {"rail": {"host": rail_host, "url": rail_url, "keyRef": rail_key,
                             "resolver": "bin/model/rail-resolve.sh"}}
print(json.dumps(doc, indent=2))
PY
)"

case "$MODE" in
  show|--json|"") printf '%s\n' "$CONFIG" ;;
  write)
    # A NAMED merge, never a wholesale replace: before 2026-11-10 this overwrote both
    # pi files with the four gateway doors, dropping every other server the seat held
    # (the mesh bridge, the ymir door). Now only the record doors are re-pointed and a
    # direct engram is dropped; everything else stays. Both names are kept — pi 1.3+
    # reads `mcp.json`, Ymir's tools name `mcp-adapter.json`.
    rail_json=""
    [ -n "$RAIL_HOST" ] && rail_json="$(printf '%s' "$CONFIG" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin).get("ymir") or {}))')"
    YMIR_MCP_RAIL_JSON="$rail_json" python3 "$SCRIPT_DIR/mcp-config-seat.py" "$GATEWAY_PORT" "$PI_SOURCE" pi
    printf 'mcp-config: pi %s/mcp.json + mcp-adapter.json (gateway :%s)\n' "$(dirname "$PI_SOURCE")" "$GATEWAY_PORT"
    ;;
  seat)
    shift; python3 "$SCRIPT_DIR/mcp-config-seat.py" "$GATEWAY_PORT" "$PI_SOURCE" seat "$@" ;;
  harness)
    shift; python3 "$SCRIPT_DIR/mcp-config-seat.py" "$GATEWAY_PORT" "$PI_SOURCE" harness "$@" ;;
  claude)
    shift; python3 "$SCRIPT_DIR/mcp-config-seat.py" "$GATEWAY_PORT" "$PI_SOURCE" claude "$@" ;;
  *) printf 'error: unknown action %s\nhelp: mcp-config.sh [show|write|seat [--check]|harness <name>|claude [--check]]\n' "$MODE" >&2; exit 2 ;;
esac
