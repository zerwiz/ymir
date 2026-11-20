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
#   mcp-config.sh            # this machine's config (JSON) to stdout
#   mcp-config.sh show       # the same
#   mcp-config.sh write      # write $HOME/.pi/agent/mcp-adapter.json (backup kept)
#   mcp-config.sh claude [--check]   # seat ymir · engram · well in Claude Code (user scope)
#                            # through Claude's own door (`claude mcp add`), never a hand-merge
#                            # of ~/.claude.json; a row already present is left alone (plan 239 P1)
#   mcp-config.sh --version
#
# Env: YMIR_MCP_GATEWAY_PORT (8316, alias MCP_GATEWAY_PORT)
set -u

VERSION="2.0.0"
case "${1-}" in -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
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
    # TWO names, ONE document. pi (1.3+) reads `~/.pi/agent/mcp.json`; Ymir's own tools
    # (mcp-gate.sh, a2a-mcp.sh, eir-doctor.sh) name `mcp-adapter.json`. Before this the
    # generator wrote ONLY the adapter name, so `pi mcp list` answered "No MCP servers
    # configured" after a clean install — a config pi never read. Write both; keep the
    # adapter name so ymir's tools do not drift.
    dir="$HOME/.pi/agent"
    mkdir -p "$dir"
    for dest in "$dir/mcp.json" "$dir/mcp-adapter.json"; do
      [ -f "$dest" ] && cp "$dest" "$dest.bak-$(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || true
      printf '%s\n' "$CONFIG" >"$dest"
    done
    printf 'mcp-config: wrote %s/mcp.json + mcp-adapter.json (gateway :%s)\n' "$dir" "$GATEWAY_PORT"
    ;;
  claude)
    # Plan 239 P1: Claude Code had NO Ymir door — install only counted engram rows, it never
    # wrote one. Seat the same three Pi carries in .pi/mcp-adapter.json: the ymir packet
    # (stdio), the engram store (stdio, resolved from the hoard) and the well (gateway).
    command -v claude >/dev/null 2>&1 || { printf 'mcp-config[1]{harness,state,why}:\n  "claude","absent","no claude on this host"\n'; exit 0; }
    check=0; [ "${2-}" = "--check" ] && check=1
    db=""; command -v hoard_memory_store >/dev/null 2>&1 && hoard_memory_store db 2>/dev/null
    engram_bin="$(command -v engram-mcp 2>/dev/null || printf '%s' "$HOME/.local/bin/engram-mcp")"
    missing=0
    printf 'mcp-config[3]{server,state,detail}:\n'
    for name in ymir engram well; do
      if claude mcp get "$name" >/dev/null 2>&1; then printf '  "%s","current",""\n' "$name"; continue; fi
      if [ "$check" = 1 ]; then printf '  "%s","absent","mcp-config.sh claude seats it"\n' "$name"; missing=$((missing+1)); continue; fi
      case "$name" in
        ymir)   claude mcp add -s user ymir -- python3 "$ROOT/bin/mcp/ymir-mcp.py" >/dev/null 2>&1 ;;
        engram) if [ -x "$engram_bin" ] && [ -n "$db" ]; then claude mcp add -s user engram -- "$engram_bin" --db "$db" >/dev/null 2>&1
                else printf '  "engram","skip","no engram-mcp or no store on this seat"\n'; continue; fi ;;
        well)   claude mcp add -s user --transport http well "http://127.0.0.1:${GATEWAY_PORT}/mcp/well" >/dev/null 2>&1 ;;
      esac
      if claude mcp get "$name" >/dev/null 2>&1; then printf '  "%s","seated","user scope"\n' "$name"; else printf '  "%s","failed","claude mcp add refused"\n' "$name"; missing=$((missing+1)); fi
    done
    [ "$missing" = 0 ] ;;
  *) printf 'error: unknown action %s\nhelp: mcp-config.sh [show|write|claude [--check]]\n' "$MODE" >&2; exit 2 ;;
esac
