#!/usr/bin/env bash
# mcp-gateway.sh — the body's ONE local door in front of the record MCPs.
#
# Plan 51 (multi-machine operations), Phase 6. An MCP address must never be a
# literal heart IP baked into every seat's config: a body fronts its record MCPs
# (well/engram · skuld tickets · bolthorn skills) through this gateway, and the
# harness points HERE. Attached, the gateway proxies the role-resolved heart
# endpoints (tailnet first, LAN fallback, loopback on the heart). Detached or
# offline it serves the cached tool catalog and queues writes into this body's
# own journal (state/journal/<host>.jsonl, the P2b outbox), so a harness never
# hangs and never blocks on the network. On reconnect the journal flushes
# (idempotency keys make replays no-ops) and the catalogs refresh.
#
# The well is special: its engram is local-first on every seat, so the gateway
# reaches the seat's own well door first (the heart's as fallback). Only the
# heart-only MCPs carry the cache+queue treatment.
#
# The door admits BROWSER readers (CORS, 2026-09-27; PINNED 2026-09-28): the
# Óðrerir hall and the other in-repo UIs read the record from a PAGE, and the
# retired skuld server opened that road; the gateway keeps it open — but only to
# this body's OWN pages. An Origin whose host is not loopback (127.0.0.1 ·
# localhost · [::1]) — or is not listed in MCP_GATEWAY_ALLOWED_ORIGINS — is
# REFUSED with 403 before the method gate, not merely denied CORS; a request
# with no Origin is a native MCP client and is admitted. Binding 127.0.0.1 is
# not a browser boundary by itself: a page may reach loopback, and 127.0.0.1 is
# mixed-content-exempt, so an unpinned wildcard admitted ANY visited page to the
# record. A preflight OPTIONS from an admitted origin answers 204.
#
#   mcp-gateway.sh serve            # run the gateway in the foreground
#   mcp-gateway.sh start|stop       # raise / lower it in the background
#   mcp-gateway.sh status [--json]  # link, upstreams, journal depth
#   mcp-gateway.sh resolve          # the role-resolved upstream map (JSON)
#   mcp-gateway.sh rail [verb]      # the LIVING model rail (bin/rail-resolve.sh)
#   mcp-gateway.sh sync [action]    # push|pull|refresh|all via the sync tool
#   mcp-gateway.sh catalog          # the cached catalogs
#   mcp-gateway.sh --version
#
# Registry (read at runtime; never shipped): $YMIR_HOME/hodd/data/fleet.json.
# A missing registry degrades cleanly — the well still serves loopback, the
# heart-only rows go unconfigured, and the gateway never fails to stand.
#
# Env: YMIR_FLEET_REGISTRY · YMIR_HOST · MCP_GATEWAY_STATE · MCP_GATEWAY_PORT
#      (YMIR_MCP_GATEWAY_PORT) · MCP_GATEWAY_ALLOWED_ORIGINS (extra browser
#      origins to admit beside this body's loopback pages) · YMIR_MCP_WELL_PORT
#      (8317) · YMIR_MCP_SKILLS_PORT (8319) · YMIR_MCP_TICKETS_PORT (8320)
set -u

VERSION="1.2.0"
case "${1-}" in
  -v|-V|--version) printf '%s\n' "$VERSION"; exit 0 ;;
  -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${BROKK_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# The ONE resolver (Rule 07): env -> the recorded choice -> the one default.
if [ -z "${YMIR_HOARD_LIB_LOADED:-}" ]; then
  for _c in "$SCRIPT_DIR/hoard-lib.sh" "$(dirname "$SCRIPT_DIR")/bin/hoard-lib.sh"; do
    [ -r "$_c" ] && { . "$_c"; YMIR_HOARD_LIB_LOADED=1; break; }
  done
  unset _c
fi
YMIR_HOME_ROOT=""
if command -v ymir_home_root >/dev/null 2>&1; then ymir_home_root YMIR_HOME_ROOT 2>/dev/null; fi
YMIR_HOME_ROOT="${YMIR_HOME_ROOT:-${YMIR_HOME}}"
STATE_DEFAULT=""
if command -v hoard_state_dir >/dev/null 2>&1; then hoard_state_dir STATE_DEFAULT 2>/dev/null; fi

STATE="${MCP_GATEWAY_STATE:-${BROKK_STATE_OVERRIDE:-${STATE_DEFAULT:-${YMIR_STATE_DIR:-$YMIR_HOME_ROOT/state}}}}"
REGISTRY="${YMIR_FLEET_REGISTRY:-$YMIR_HOME_ROOT/hodd/data/fleet.json}"
HOST="${YMIR_HOST:-$(hostname -s 2>/dev/null | tr 'A-Z' 'a-z')}"
HOST="${HOST:-unknown}"
GATEWAY_PORT="${MCP_GATEWAY_PORT:-${YMIR_MCP_GATEWAY_PORT:-8316}}"
WELL_PORT="${YMIR_MCP_WELL_PORT:-8317}"
SKILLS_PORT="${YMIR_MCP_SKILLS_PORT:-8319}"
TICKETS_PORT="${YMIR_MCP_TICKETS_PORT:-8320}"
NODE="${MCP_GATEWAY_NODE:-node}"

# The engine: beside the door in the tree, or materialized into the seat's
# ~/.fleet by the role-aware raise.
server_path() {
  if [ -f "$ROOT/tools/mcp-gateway/server.mjs" ]; then
    printf '%s\n' "$ROOT/tools/mcp-gateway/server.mjs"
  elif [ -f "$HOME/.fleet/mcp-gateway-server.mjs" ]; then
    printf '%s\n' "$HOME/.fleet/mcp-gateway-server.mjs"
  fi
}

# ── the role-resolved upstream map ───────────────────────────────────────────
resolve_upstreams() {
  python3 - "$REGISTRY" "$HOST" "$WELL_PORT" "$SKILLS_PORT" "$TICKETS_PORT" <<'PY'
import json, sys
reg, me, wp, sp, tp = sys.argv[1:6]
try: doc = json.load(open(reg))
except Exception: doc = {}
hosts = doc.get("hosts") or {}
heart = str(doc.get("heart") or "")
mine = (hosts.get(me) or {}).get("roles") or ["dev"]
is_heart = "heart" in mine
hh = hosts.get(heart) or {}

def mk(addr, port, suffix="/mcp"):
    return "http://%s:%s%s" % (addr, port, suffix)

# the heart's reachable addresses: tailnet first, LAN fallback, loopback on the heart
heart_addrs = []
if is_heart:
    heart_addrs = ["127.0.0.1"]
else:
    for a in (hh.get("tailnet"), hh.get("lan")):
        if a and a not in heart_addrs:
            heart_addrs.append(a)
    if not heart_addrs and heart:
        heart_addrs = [heart]

well = [mk("127.0.0.1", wp)]
for a in heart_addrs:
    u = mk(a, wp)
    if u not in well:
        well.append(u)          # the heart's well door as a fallback for seats without one
skills = [mk(a, sp) for a in heart_addrs]
tickets = [mk(a, tp, "") for a in heart_addrs]     # skuld serves bare HTTP (:8320)

print(json.dumps({
  "well":     {"urls": well, "local_first": True},
  "bolthorn": {"urls": skills, "local_first": False},
  "skuld":    {"urls": tickets, "local_first": False},
}))
PY
}

# ── the verbs ────────────────────────────────────────────────────────────────
gw_url() { printf 'http://127.0.0.1:%s' "$GATEWAY_PORT"; }

gw_health() {  # prints the health JSON, or nothing when the gateway is down
  curl -fsS -m 2 "$(gw_url)/health" 2>/dev/null || true
}

cmd_serve() {
  local server; server="$(server_path)"
  if [ -z "$server" ]; then
    printf 'error: mcp-gateway engine not found (tools/mcp-gateway/server.mjs or ~/.fleet/mcp-gateway-server.mjs)\n' >&2
    return 1
  fi
  export MCP_GATEWAY_STATE="$STATE"
  export BROKK_STATE_OVERRIDE="$STATE"
  export MCP_GATEWAY_BIN="$SCRIPT_DIR"
  export MCP_GATEWAY_HOST="$HOST"
  export MCP_GATEWAY_PORT="$GATEWAY_PORT"
  export MCP_GATEWAY_ALLOWED_ORIGINS="${MCP_GATEWAY_ALLOWED_ORIGINS:-}"
  export MCP_GATEWAY_UPSTREAMS="${MCP_GATEWAY_UPSTREAMS:-$(resolve_upstreams)}"
  exec "$NODE" "$server"
}

pidfile() { printf '%s\n' "$STATE/mcp-gateway/gateway.pid"; }

cmd_start() {
  mkdir -p "$STATE/mcp-gateway"
  local pid; pid="$(cat "$(pidfile)" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    printf 'mcp-gateway: already running (pid %s)\n' "$pid"
    return 0
  fi
  nohup bash "$SCRIPT_DIR/mcp-gateway.sh" serve >>"$STATE/mcp-gateway/gateway.log" 2>&1 &
  local new=$!
  printf '%s\n' "$new" >"$(pidfile)"
  sleep 1
  if kill -0 "$new" 2>/dev/null; then
    printf 'mcp-gateway: started (pid %s, port %s)\n' "$new" "$GATEWAY_PORT"
    return 0
  fi
  printf 'mcp-gateway: FAILED to start — see %s/mcp-gateway/gateway.log\n' "$STATE" >&2
  return 1
}

cmd_stop() {
  local pid; pid="$(cat "$(pidfile)" 2>/dev/null || true)"
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    printf 'mcp-gateway: not running\n'
    return 0
  fi
  kill "$pid" 2>/dev/null || true
  rm -f "$(pidfile)"
  printf 'mcp-gateway: stopped (pid %s)\n' "$pid"
}

cmd_status() {
  local json; json="$(gw_health)"
  if [ -z "$json" ]; then
    printf 'mcp_gateway[3]{fact,value}:\n'
    printf '  "service","not running"\n'
    printf '  "port","%s"\n' "$GATEWAY_PORT"
    printf '  "start","bin/mcp-gateway.sh start"\n'
    return 0
  fi
  if [ "${1-}" = "--json" ]; then printf '%s\n' "$json"; return 0; fi
  # The model rail is a SIBLING fact (plan 51 Part 9c), resolved by the ONE
  # resolver — a model URL in the upstream map would be read as a sixth MCP
  # server by the engine, so it is never one.
  local rail_row=""
  if [ -x "$SCRIPT_DIR/rail-resolve.sh" ]; then
    rail_row="$(bash "$SCRIPT_DIR/rail-resolve.sh" resolve --json 2>/dev/null | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
s=d.get("serving") or {}
print(("%s %s" % (s.get("host") or "none", s.get("url") or "")).strip())' 2>/dev/null || true)"
  fi
  python3 - "$json" "$rail_row" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
up = d.get("upstreams") or {}
n = 5 + len(up)
print("mcp_gateway[%d]{fact,value}:" % n)
print('  "host","%s"' % d.get("host"))
print('  "port","%s"' % d.get("port"))
print('  "link","%s"' % d.get("link"))
for name in sorted(up):
    s = up[name]
    print('  "upstream.%s","%s (%s tools)"' % (name, s.get("state"), s.get("tools")))
j = d.get("journal") or {}
print('  "journal","%s entries in %s file(s), last %ss ago"' % (j.get("entries"), j.get("files"), j.get("last_age_s")))
print('  "rail","%s"' % (sys.argv[2] or "unresolved"))
PY
}

cmd_sync() {
  local action="${1:-all}"
  local out
  out="$(curl -fsS -m 20 -X POST -H 'content-type: application/json' \
    -H 'accept: application/json, text/event-stream' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"sync\",\"arguments\":{\"action\":\"$action\"}}}" \
    "$(gw_url)/mcp" 2>/dev/null || true)"
  if [ -z "$out" ]; then
    printf 'mcp-gateway: not running — start it first (bin/mcp-gateway.sh start)\n' >&2
    return 1
  fi
  printf '%s' "$out" | python3 -c '
import json,sys
try: d=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
for c in (d.get("result") or {}).get("content") or []:
    if c.get("type")=="text": print(c.get("text",""))
' 2>/dev/null || printf '%s\n' "$out"
}

cmd_catalog() {
  local dir="$STATE/mcp-gateway/cache"
  local rows="" f n
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    rows="${rows}  \"${f##*/}\",\"$(wc -c <"$f" | tr -d '[:space:]')\",\"$(( $(date -u +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) ))\"\n"
  done
  n=0; [ -n "$rows" ] && n="$(printf '%b' "$rows" | grep -c '^  "')"
  printf 'mcp_gateway_catalog[%s]{file,bytes,age_s}:\n' "$n"
  printf '%b' "$rows"
}

# The living model rail, reached through the ONE resolver (plan 51 Part 9c):
# `mcp-gateway.sh rail resolve [alias]` / `rail status`. It is never an upstream.
cmd_rail() { bash "$SCRIPT_DIR/rail-resolve.sh" "$@"; }

case "${1:-status}" in
  serve)    cmd_serve ;;
  start)    cmd_start ;;
  stop)     cmd_stop ;;
  status)   cmd_status "${2-}" ;;
  resolve)  resolve_upstreams ;;
  rail)     shift; cmd_rail "$@" ;;
  sync)     cmd_sync "${2-}" ;;
  catalog)  cmd_catalog ;;
  *) printf 'error: unknown command %s\nhelp: bin/mcp-gateway.sh [serve|start|stop|status|resolve|rail|sync|catalog]\n' "$1" >&2; exit 2 ;;
esac
