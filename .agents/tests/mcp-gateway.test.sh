#!/usr/bin/env bash
# mcp-gateway.test.sh — the P6 proof (plan 51): a REAL refused-network run.
#
# Proves the gateway is a door that remembers:
#   1. attached → it proxies a real upstream and CACHES the tool catalog;
#   2. the upstream is killed (a real ECONNREFUSED, never a flag) →
#      initialize→tools/list still answers FROM CACHE, fast, and a write is
#      queued into this body's journal;
#   3. reconnect (the upstream returns) → the journal flushes and a call
#      proxies live again.
#
# No network double: the upstream is a real listener, and its absence is a real
# refused connection on 127.0.0.1.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GW="$ROOT/bin/bridge/mcp-gateway.sh"
fail=0
ok()  { printf 'ok - %s\n' "$1"; }
bad() { printf 'not ok - %s\n' "$1" >&2; fail=1; }

TMP="$(mktemp -d)"
GWPID=""; UPPID=""
cleanup() {
  [ -n "$UPPID" ] && kill "$UPPID" 2>/dev/null
  [ -n "$GWPID" ] && kill "$GWPID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }
UP_PORT="$(free_port)"
GW_PORT="$(free_port)"
STATE="$TMP/state"; mkdir -p "$STATE/journal" "$TMP/heart"
export BROKK_STATE_OVERRIDE="$STATE" YMIR_HOST=gwbody

# ── the upstream: a real MCP server on a real socket ─────────────────────────
cat >"$TMP/upstream.mjs" <<'EOF'
import http from "node:http";
const PORT = Number(process.argv[2]);
const TOOLS = [
  { name: "tickets_list", description: "List tickets", inputSchema: { type: "object" } },
  { name: "tickets_create", description: "Create a ticket", inputSchema: { type: "object" } }
];
http.createServer((req, res) => {
  let raw = "";
  req.on("data", (c) => (raw += c));
  req.on("end", () => {
    let m = {};
    try { m = JSON.parse(raw); } catch { m = {}; }
    const send = (o, extra = {}) => {
      const b = Buffer.from(JSON.stringify(o));
      res.writeHead(200, { "content-type": "application/json", "content-length": String(b.length), ...extra });
      res.end(b);
    };
    if (m.method === "initialize") return send({ jsonrpc: "2.0", id: m.id, result: { protocolVersion: "2024-11-05", capabilities: { tools: {} }, serverInfo: { name: "upstream", version: "1" } } }, { "mcp-session-id": "up1" });
    if (m.method === "notifications/initialized") { res.writeHead(202); return res.end(); }
    if (m.method === "tools/list") return send({ jsonrpc: "2.0", id: m.id, result: { tools: TOOLS } });
    if (m.method === "tools/call") return send({ jsonrpc: "2.0", id: m.id, result: { content: [{ type: "text", text: "live:" + m.params.name }] } });
    return send({ jsonrpc: "2.0", id: m.id, error: { code: -32601, message: "no" } });
  });
}).listen(PORT, "127.0.0.1");
EOF

start_upstream() { node "$TMP/upstream.mjs" "$UP_PORT" >"$TMP/up.log" 2>&1 & UPPID=$!; sleep 0.4; }

rpc() {  # <path> <method> <params-json>
  local body params
  params="${3-}"; [ -n "$params" ] || params='{}'
  body="$(python3 -c 'import json,sys; print(json.dumps({"jsonrpc":"2.0","id":1,"method":sys.argv[1],"params":json.loads(sys.argv[2])}))' "$2" "$params")"
  curl -s -m 6 -X POST -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' \
    -d "$body" "http://127.0.0.1:$GW_PORT$1" 2>/dev/null || true
}

UPSTREAMS="{\"skuld\":{\"urls\":[\"http://127.0.0.1:$UP_PORT/mcp\"],\"local_first\":false},\"bolthorn\":{\"urls\":[\"http://127.0.0.1:$UP_PORT/mcp\"],\"local_first\":false},\"well\":{\"urls\":[\"http://127.0.0.1:$UP_PORT/mcp\"],\"local_first\":true}}"

# ═══ 1. attached: the gateway proxies the upstream and caches the catalog ═══
start_upstream
MCP_GATEWAY_STATE="$STATE" MCP_GATEWAY_PORT="$GW_PORT" MCP_GATEWAY_UPSTREAMS="$UPSTREAMS" \
  YMIR_HEART=127.0.0.1 YMIR_HOST=gwbody BROKK_STATE_OVERRIDE="$STATE" \
  YMIR_JOURNAL_PUSH="cp \"\$1\" \"$TMP/heart/\"" \
  bash "$GW" serve >"$TMP/gw.log" 2>&1 &
GWPID=$!
sleep 1

out="$(rpc /mcp/skuld initialize '{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}')"
printf '%s' "$out" | grep -q '"mcp-gateway"' && ok "initialize answers the gateway identity" || bad "initialize: $out"

out="$(rpc /mcp/skuld tools/list)"
printf '%s' "$out" | grep -q 'tickets_list' && ok "attached: tools/list served through the gateway" || bad "attached tools/list: $out"
[ -f "$STATE/mcp-gateway/cache/skuld.json" ] && ok "attached: the tool catalog was cached" || bad "no cached catalog"
grep -q 'tickets_list' "$STATE/mcp-gateway/cache/skuld.json" 2>/dev/null && ok "cached catalog holds the upstream tools" || bad "cache content: $(cat "$STATE/mcp-gateway/cache/skuld.json" 2>/dev/null)"

out="$(rpc /mcp/skuld tools/call '{"name":"tickets_list","arguments":{"namespace":"work"}}')"
printf '%s' "$out" | grep -q 'live:tickets_list' && ok "attached: a read proxies live (and is cached)" || bad "attached read: $out"

# ═══ 1b. the browser road: the door admits ONLY the body's own origin ═══════
# The Óðrerir hall reads the record from a PAGE, and the retired skuld server
# opened CORS for it; the gateway must keep that road open — but pinned to the
# body's own pages. A foreign Origin is refused outright (403), not merely
# denied CORS: a hostile page must not read OR write the record through the
# loopback door. A request with no Origin is a native MCP client and is
# admitted (every rpc() call above carries none).
pf="$(curl -s -m 3 -o /dev/null -D - -X OPTIONS "http://127.0.0.1:$GW_PORT/mcp/skuld" \
  -H 'Origin: http://127.0.0.1:4322' -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: content-type,mcp-session-id' 2>/dev/null | tr -d '\r')"
printf '%s' "$pf" | grep -qi '^HTTP/1.1 204' && ok "preflight: the hall's own origin answers 204" || bad "preflight: $pf"
printf '%s' "$pf" | grep -qi '^access-control-allow-origin: http://127.0.0.1:4322' && ok "preflight: the origin is echoed (pinned, not *)" || bad "preflight CORS: $pf"
printf '%s' "$pf" | grep -qi 'allow-private-network' && bad "preflight widened with allow-private-network" || ok "preflight carries no allow-private-network widening"

pf="$(curl -s -m 3 -o /dev/null -D - -X OPTIONS "http://127.0.0.1:$GW_PORT/mcp/skuld" \
  -H 'Origin: https://evil.example' -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: content-type' 2>/dev/null | tr -d '\r')"
printf '%s' "$pf" | grep -qi '^HTTP/1.1 403' && ok "preflight: a foreign origin is REFUSED (403, no 204)" || bad "foreign preflight: $pf"
printf '%s' "$pf" | grep -qi 'allow-private-network' && bad "foreign preflight widened" || ok "foreign preflight carries no widening"

out="$(curl -s -m 3 -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' -H 'Origin: https://evil.example' \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/list"}' "http://127.0.0.1:$GW_PORT/mcp/skuld" 2>/dev/null)"
[ "$out" = 403 ] && ok "a foreign origin is refused a READ (403)" || bad "foreign read: HTTP $out"

out="$(curl -s -m 3 -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' -H 'Origin: https://evil.example' \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"tickets_create","arguments":{"title":"drive-by"}}}' "http://127.0.0.1:$GW_PORT/mcp/skuld" 2>/dev/null)"
[ "$out" = 403 ] && ok "a foreign origin is refused a WRITE (403)" || bad "foreign write: HTTP $out"

out="$(curl -s -m 3 -D - -o /dev/null -X POST -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' -H 'Origin: http://127.0.0.1:4322' \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/list"}' "http://127.0.0.1:$GW_PORT/mcp/skuld" 2>/dev/null | tr -d '\r')"
printf '%s' "$out" | grep -qi '^HTTP/1.1 200' && ok "the hall's own origin is served (200)" || bad "hall POST: $out"
printf '%s' "$out" | grep -qi '^access-control-allow-origin: http://127.0.0.1:4322' && ok "an answered call carries the pinned origin" || bad "POST CORS: $out"

# ═══ 2. the upstream dies (a REAL refused connection) ═══════════════════════
kill "$UPPID" 2>/dev/null; wait "$UPPID" 2>/dev/null; UPPID=""
sleep 0.3

start_ns="$(date +%s%N)"
out="$(rpc /mcp/skuld tools/list)"
end_ns="$(date +%s%N)"
elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
printf '%s' "$out" | grep -q 'tickets_list' && ok "detached: tools/list served FROM CACHE" || bad "detached tools/list: $out"
[ "$elapsed_ms" -lt 3000 ] && ok "detached: the harness did not hang (${elapsed_ms}ms)" || bad "detached call took ${elapsed_ms}ms"

out="$(rpc /mcp/skuld tools/call '{"name":"tickets_list","arguments":{"namespace":"work"}}')"
printf '%s' "$out" | grep -q 'cached (gateway detached' && ok "detached: a read with a cached record is served" || bad "detached read: $out"

out="$(rpc /mcp/skuld tools/call '{"name":"tickets_create","arguments":{"title":"offline ticket"}}')"
printf '%s' "$out" | grep -q 'queued to the journal' && ok "detached: a write is reported queued" || bad "detached write: $out"
J="$STATE/journal/gwbody.jsonl"
[ -s "$J" ] && ok "detached: the write landed in the journal" || bad "journal empty"
python3 - "$J" <<'PY' && ok "journal entry names the server, tool and an idempotency key" || bad "journal entry shape"
import json, sys
d = json.loads(open(sys.argv[1]).read().strip().split("\n")[-1])
assert d["op"] == "mcp.call.skuld", d
assert d["data"]["tool"] == "tickets_create", d
assert d["key"].count(":") == 2, d
PY

# ═══ 3. reconnect: the sync tool flushes the journal and refreshes ══════════
start_upstream
out="$(rpc /mcp tools/call '{"name":"sync","arguments":{"action":"all"}}')"
printf '%s' "$out" | grep -q 'pushed 1' && ok "sync: the journal flushed on reconnect" || bad "sync push: $out"
[ -s "$TMP/heart/gwbody.jsonl" ] && ok "sync: the heart inbox received the journal" || bad "heart inbox empty"
[ -f "$J" ] && bad "journal not moved after the flush" || ok "sync: the flushed journal moved to sent/"

out="$(rpc /mcp/skuld tools/call '{"name":"tickets_list","arguments":{}}')"
printf '%s' "$out" | grep -q 'live:tickets_list' && ok "reconnect: a call proxies live again" || bad "reconnect call: $out"

out="$(curl -s -m 3 "http://127.0.0.1:$GW_PORT/health")"
printf '%s' "$out" | grep -q '"link":"attached"' && ok "health: the gateway reports attached" || bad "health: $out"

[ "$fail" = 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
