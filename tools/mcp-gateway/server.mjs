#!/usr/bin/env node
// server.mjs — the MCP gateway engine (plan 51 P6).
//
// One local door per body, fronting the record MCPs (well/engram · skuld
// tickets · bolthorn skills). Attached it proxies the role-resolved upstreams;
// detached or offline it serves the cached tool catalog and queues tool calls
// into this body's own journal — never hanging a harness, never blocking on the
// network. On reconnect it flushes the journal and refreshes the catalogs.
//
// The well is special: its engram is local-first on every seat, so the gateway
// reaches the seat's own well door first; only the heart-only MCPs (tickets,
// skills) carry the cache+queue treatment in earnest.
//
// Dependency-free on purpose: it is the fallback door, so it must not need a
// package tree to stand. It speaks stateless StreamableHTTP JSON-RPC.
//
// Env:
//   MCP_GATEWAY_UPSTREAMS           JSON map: {"skuld":{"urls":[...],"local_first":bool}}
//   MCP_GATEWAY_STATE               the body state dir (journal lives here)
//   MCP_GATEWAY_BIN                 the platform bin/ (journal-append/reconcile)
//   MCP_GATEWAY_PORT                listen port (default 8316)
//   MCP_GATEWAY_HOST                the seat's short hostname (report only)
//   MCP_GATEWAY_UPSTREAM_TIMEOUT_MS per-upstream request timeout (default 1500)

import http from "node:http";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";

const VERSION = "1.0.0";
const PORT = Number(process.env.MCP_GATEWAY_PORT || 8316);
const STATE = process.env.MCP_GATEWAY_STATE || path.join(os.homedir(), ".ymir-state");
const CACHE = path.join(STATE, "mcp-gateway", "cache");
const RECDIR = path.join(CACHE, "rec");
const BIN = process.env.MCP_GATEWAY_BIN || "";
const HOST = process.env.MCP_GATEWAY_HOST || os.hostname().split(".")[0].toLowerCase();
const TIMEOUT = Number(process.env.MCP_GATEWAY_UPSTREAM_TIMEOUT_MS || 1500);
const PROTOCOL = "2024-11-05";

fs.mkdirSync(RECDIR, { recursive: true });

let UPSTREAMS = {};
try { UPSTREAMS = JSON.parse(process.env.MCP_GATEWAY_UPSTREAMS || "{}"); } catch { UPSTREAMS = {}; }
if (!UPSTREAMS || typeof UPSTREAMS !== "object" || !Object.keys(UPSTREAMS).length) {
  UPSTREAMS = { well: { urls: ["http://127.0.0.1:8317/mcp"], local_first: true } };
}
for (const [name, up] of Object.entries(UPSTREAMS)) {
  if (!up || typeof up !== "object") { UPSTREAMS[name] = { urls: [], local_first: false }; continue; }
  if (!Array.isArray(up.urls)) up.urls = up.urls ? [String(up.urls)] : [];
}

const SYNC_TOOL = {
  name: "sync",
  description: "Push this body's write journal to the heart, refresh the cached tool catalogs, and report the link. Reconciles without shell access.",
  inputSchema: {
    type: "object",
    properties: {
      action: { type: "string", enum: ["push", "pull", "refresh", "all"], description: "push the journal · pull/refresh the catalogs · all (default)" }
    },
    additionalProperties: false
  }
};

const WRITE_VERB = /(^|_)(create|update|delete|remove|set|clear|add|put|move|comment|toggle|assign|archive|forget|remember|write|apply|fold|receive|import|register|unregister|raise|lower|dispatch|spawn|merge|push|send|post|edit|patch|commit|drop|reap|purge)(_|$)/;
const READ_VERB = /(^|_)(list|get|show|search|recall|why|stats|status|read|find|query|view|count|health|inspect|describe|peek|fetch|load)(_|$)/;

function isReadTool(name) {
  const n = String(name || "").toLowerCase();
  if (WRITE_VERB.test(n)) return false;
  return READ_VERB.test(n);
}

// ── the disk cache: tool catalogs, last-read results, upstream health ────────
function catFile(server) { return path.join(CACHE, `${server}.json`); }
function readCatalog(server) {
  try { return JSON.parse(fs.readFileSync(catFile(server), "utf8")); } catch { return null; }
}
function writeCatalog(server, tools) {
  const doc = { ts: new Date().toISOString(), tools: Array.isArray(tools) ? tools : [] };
  try { fs.writeFileSync(catFile(server), JSON.stringify(doc, null, 2)); } catch { /* cache is best-effort */ }
  return doc;
}
function recFile(server, tool, args) {
  const h = crypto.createHash("sha1").update(JSON.stringify(args || {})).digest("hex").slice(0, 12);
  return path.join(RECDIR, `${server}__${tool}__${h}.json`);
}
function readResult(server, tool, args) {
  try { return JSON.parse(fs.readFileSync(recFile(server, tool, args), "utf8")); } catch { return null; }
}
function writeResult(server, tool, args, result) {
  try { fs.writeFileSync(recFile(server, tool, args), JSON.stringify({ ts: new Date().toISOString(), result }, null, 2)); } catch { /* best-effort */ }
}
function statusFile() { return path.join(CACHE, "status.json"); }
function readStatusAll() {
  try { return JSON.parse(fs.readFileSync(statusFile(), "utf8")); } catch { return {}; }
}
function recordStatus(server, ok, detail) {
  const all = readStatusAll();
  all[server] = { state: ok ? "ok" : "unreachable", ts: new Date().toISOString(), detail: detail || null };
  try { fs.writeFileSync(statusFile(), JSON.stringify(all, null, 2)); } catch { /* best-effort */ }
}

// ── HTTP JSON-RPC against an upstream MCP server ─────────────────────────────
function post(url, bodyObj, sid) {
  return new Promise((resolve) => {
    let u;
    try { u = new URL(url); } catch { return resolve({ ok: false, status: 0, error: "bad url" }); }
    const data = Buffer.from(JSON.stringify(bodyObj));
    const headers = {
      "content-type": "application/json",
      "accept": "application/json, text/event-stream",
      "content-length": String(data.length)
    };
    if (sid) headers["mcp-session-id"] = sid;
    const req = http.request(
      { hostname: u.hostname, port: u.port || 80, path: (u.pathname || "/") + (u.search || ""), method: "POST", headers },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve({
          ok: res.statusCode >= 200 && res.statusCode < 300,
          status: res.statusCode,
          sid: res.headers["mcp-session-id"],
          body: Buffer.concat(chunks).toString("utf8")
        }));
      }
    );
    req.setTimeout(TIMEOUT, () => req.destroy(new Error("timeout")));
    req.on("error", (e) => resolve({ ok: false, status: 0, error: e.message }));
    req.write(data);
    req.end();
  });
}

function parseRpc(raw, id) {
  if (!raw) return null;
  let d = null;
  try { d = JSON.parse(raw); } catch { d = null; }
  if (d && typeof d === "object") return d;
  for (const line of String(raw).split(/\r?\n/)) {
    const m = line.match(/^data:\s*(.*)$/);
    if (!m) continue;
    let j = null;
    try { j = JSON.parse(m[1]); } catch { j = null; }
    if (j && (id === undefined || j.id === id)) return j;
  }
  return null;
}

const sessions = new Map();

async function ensureSession(url) {
  if (sessions.has(url)) return sessions.get(url);
  const r = await post(url, {
    jsonrpc: "2.0", id: "gw-init", method: "initialize",
    params: { protocolVersion: PROTOCOL, capabilities: {}, clientInfo: { name: "mcp-gateway", version: VERSION } }
  }, null);
  if (!r.ok) return null;
  const sid = r.sid || "";
  if (sid) sessions.set(url, sid);
  await post(url, { jsonrpc: "2.0", method: "notifications/initialized", params: {} }, sid || undefined);
  return sid;
}

async function upstreamRpc(server, method, params) {
  const up = UPSTREAMS[server];
  if (!up || !up.urls.length) return { ok: false, error: "no upstream configured" };
  const errors = [];
  for (const url of up.urls) {
    const sid = await ensureSession(url);
    let r = await post(url, { jsonrpc: "2.0", id: `gw-${Date.now()}`, method, params: params || {} }, sid || undefined);
    if (!r.ok && sid && (r.status === 400 || r.status === 404)) {
      sessions.delete(url);
      const sid2 = await ensureSession(url);
      r = await post(url, { jsonrpc: "2.0", id: `gw-${Date.now()}`, method, params: params || {} }, sid2 || undefined);
    }
    if (!r.ok) { errors.push(`${url}: ${r.error || `HTTP ${r.status}`}`); continue; }
    const j = parseRpc(r.body);
    if (j && j.result !== undefined) return { ok: true, result: j.result, url };
    if (j && j.error) return { ok: true, rpcError: j.error, url };
    errors.push(`${url}: no JSON-RPC result`);
  }
  return { ok: false, error: errors.join("; ") };
}

async function refreshCatalog(server) {
  const r = await upstreamRpc(server, "tools/list", {});
  if (r.ok && Array.isArray(r.result && r.result.tools)) {
    writeCatalog(server, r.result.tools);
    recordStatus(server, true, r.url);
    return r.result.tools.length;
  }
  recordStatus(server, false, r.error || "no tools/list result");
  return -1;
}

// ── the detached paths: cached result, or the write journal ──────────────────
function journalCall(server, tool, args) {
  if (!BIN) return "(no bin dir configured; call not journaled)";
  const data = JSON.stringify({ server, tool, args: args || {} });
  const r = spawnSync("bash", [path.join(BIN, "journal-append.sh"), "--op", `mcp.call.${server}`, "--data", data], {
    encoding: "utf8", env: { ...process.env }
  });
  const out = String(r.stdout || "").trim().split("\n").filter(Boolean).pop();
  return out || "(journal write failed)";
}

function journalReconcile() {
  if (!BIN) return "(no bin dir configured; journal not pushed)";
  const r = spawnSync("bash", [path.join(BIN, "journal-reconcile.sh")], { encoding: "utf8", env: { ...process.env } });
  return (String(r.stdout || "") + String(r.stderr || "")).trim() || "(reconcile ran)";
}

function journalState() {
  const dir = path.join(STATE, "journal");
  let files = [];
  try { files = fs.readdirSync(dir).filter((f) => f.endsWith(".jsonl")); } catch { files = []; }
  let entries = 0, last = 0;
  for (const f of files) {
    try {
      const p = path.join(dir, f);
      entries += fs.readFileSync(p, "utf8").split("\n").filter(Boolean).length;
      last = Math.max(last, fs.statSync(p).mtimeMs);
    } catch { /* ignore */ }
  }
  return { files: files.length, entries, last_age_s: last ? Math.round((Date.now() - last) / 1000) : null };
}

function health() {
  const all = readStatusAll();
  const upstreams = {};
  let anyOk = false, anyKnown = false;
  for (const name of Object.keys(UPSTREAMS)) {
    const st = all[name] || {};
    if (st.state === "ok") anyOk = true;
    if (st.state) anyKnown = true;
    upstreams[name] = {
      state: st.state || "unknown",
      ts: st.ts || null,
      tools: (readCatalog(name) || {}).tools ? (readCatalog(name).tools.length) : 0,
      detail: st.detail || null
    };
  }
  const link = anyOk ? "attached" : (anyKnown ? "detached" : "unchecked");
  return {
    gateway: "mcp-gateway", version: VERSION, host: HOST, port: PORT,
    link, upstreams, journal: journalState()
  };
}

// ── MCP method handling ──────────────────────────────────────────────────────
async function toolsFor(serverFilter) {
  const servers = serverFilter ? [serverFilter] : Object.keys(UPSTREAMS);
  const out = [SYNC_TOOL];
  for (const s of servers) {
    if (!UPSTREAMS[s]) continue;
    const live = await refreshCatalog(s);
    const cat = readCatalog(s);
    if (cat && Array.isArray(cat.tools)) out.push(...cat.tools);
    if (live < 0 && !cat) recordStatus(s, false, "no upstream and no cached catalog");
  }
  return out;
}

async function callUpstream(server, name, args) {
  const r = await upstreamRpc(server, "tools/call", { name, arguments: args || {} });
  if (!r.ok) return { ok: false, error: r.error };
  if (r.rpcError) return { ok: true, content: [{ type: "text", text: String(r.rpcError.message || r.rpcError) }], isError: true, rpcError: true };
  const res = r.result || {};
  if (isReadTool(name)) writeResult(server, name, args, res);
  recordStatus(server, true, r.url);
  if (res && Array.isArray(res.content)) return { ok: true, content: res.content, isError: !!res.isError };
  return { ok: true, content: [{ type: "text", text: JSON.stringify(res) }], isError: !!res.isError };
}

async function doSync(action) {
  const act = String(action || "all");
  const lines = [];
  if (act === "push" || act === "all") {
    lines.push(journalReconcile());
    lines.push(`journal now: ${JSON.stringify(journalState())}`);
  }
  if (act === "pull" || act === "refresh" || act === "all") {
    for (const s of Object.keys(UPSTREAMS)) {
      const n = await refreshCatalog(s);
      lines.push(`${s}: ${n >= 0 ? `${n} tools refreshed` : "upstream unreachable (catalog left as cached)"}`);
    }
  }
  lines.push(`link: ${health().link}`);
  return { content: [{ type: "text", text: lines.join("\n") }], isError: false };
}

async function handleToolCall(serverFilter, name, args) {
  if (name === "sync") return await doSync(args && args.action);
  let servers = serverFilter ? [serverFilter].filter((s) => UPSTREAMS[s]) : [];
  if (!servers.length) {
    const owner = Object.keys(UPSTREAMS).find((s) => ((readCatalog(s) || {}).tools || []).some((t) => t.name === name));
    servers = owner ? [owner] : Object.keys(UPSTREAMS);
  }
  const errors = [];
  for (const s of servers) {
    const r = await callUpstream(s, name, args);
    if (r.ok) return { content: r.content, isError: !!r.isError };
    errors.push(`${s}: ${r.error}`);
  }
  const server = servers[0] || serverFilter || "record";
  if (isReadTool(name)) {
    const cached = readResult(server, name, args);
    if (cached) return { content: [{ type: "text", text: `cached (gateway detached — upstream unreachable): ${JSON.stringify(cached.result)}` }], isError: false };
  }
  const key = journalCall(server, name, args);
  return {
    content: [{ type: "text", text: `queued to the journal (upstream unreachable): op mcp.call.${server}, key ${key}` }],
    isError: false
  };
}

function rpcResult(id, result) { return { jsonrpc: "2.0", id, result }; }
function rpcError(id, code, message) { return { jsonrpc: "2.0", id, error: { code, message } }; }

async function handleRpc(msg, serverFilter) {
  if (!msg || typeof msg !== "object") return rpcError(null, -32600, "invalid request");
  const { id, method, params } = msg;
  if (method === "initialize") {
    const st = health();
    const summary = Object.entries(st.upstreams).map(([n, s]) => `${n}=${s.state}`).join(" ");
    return rpcResult(id, {
      protocolVersion: (params && params.protocolVersion) || PROTOCOL,
      capabilities: { tools: { listChanged: false } },
      serverInfo: { name: "mcp-gateway", version: VERSION },
      instructions: `Ymir MCP gateway (${st.link})${summary ? ` — ${summary}` : ""}. Record doors proxy the heart when it answers and serve the cached catalog when it does not; writes are queued to this body's journal and flushed by the sync tool.`
    });
  }
  if (method === "notifications/initialized" || (method && method.startsWith("notifications/"))) return null;
  if (method === "ping") return rpcResult(id, {});
  if (method === "tools/list") return rpcResult(id, { tools: await toolsFor(serverFilter) });
  if (method === "tools/call") {
    const name = params && params.name;
    const args = (params && params.arguments) || {};
    if (!name) return rpcError(id, -32602, "tools/call needs a name");
    return rpcResult(id, await handleToolCall(serverFilter, name, args));
  }
  if (method === "resources/list") return rpcResult(id, { resources: [] });
  if (method === "prompts/list") return rpcResult(id, { prompts: [] });
  return rpcError(id, -32601, `method not found: ${method}`);
}

// ── the HTTP surface ─────────────────────────────────────────────────────────
function sendJson(res, code, obj) {
  const body = Buffer.from(JSON.stringify(obj));
  res.writeHead(code, { "content-type": "application/json", "content-length": String(body.length) });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve) => {
    const chunks = [];
    let size = 0;
    req.on("data", (c) => {
      size += c.length;
      if (size > 4 << 20) { req.destroy(); resolve(""); return; }
      chunks.push(c);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", () => resolve(""));
  });
}

const server = http.createServer(async (req, res) => {
  let u;
  try { u = new URL(req.url, "http://localhost"); } catch { return sendJson(res, 400, { error: "bad url" }); }

  if (req.method === "GET" && (u.pathname === "/health" || u.pathname === "/")) {
    return sendJson(res, 200, health());
  }
  const m = u.pathname.match(/^\/mcp(?:\/([A-Za-z0-9_-]+))?\/?$/);
  if (!m) return sendJson(res, 404, { error: "not found" });
  const serverFilter = m[1] || null;
  if (serverFilter && !UPSTREAMS[serverFilter]) {
    return sendJson(res, 404, { jsonrpc: "2.0", id: null, error: { code: -32601, message: `unknown record server: ${serverFilter}` } });
  }
  if (req.method === "GET") {
    res.writeHead(405, { allow: "POST" });
    return res.end();
  }
  if (req.method !== "POST") return sendJson(res, 405, { error: "method not allowed" });

  const raw = await readBody(req);
  let msg;
  try { msg = JSON.parse(raw); } catch { return sendJson(res, 400, rpcError(null, -32700, "parse error")); }

  const one = async (m0) => {
    const out = await handleRpc(m0, serverFilter);
    return out;
  };
  let reply;
  if (Array.isArray(msg)) {
    const parts = [];
    for (const m0 of msg) { const r = await one(m0); if (r) parts.push(r); }
    reply = parts;
  } else {
    reply = await one(msg);
  }
  if (reply === null || (Array.isArray(reply) && reply.length === 0)) {
    res.writeHead(202); return res.end();
  }
  return sendJson(res, 200, reply);
});

server.listen(PORT, "127.0.0.1", () => {
  process.stdout.write(`mcp-gateway ${VERSION} listening on http://127.0.0.1:${PORT} (host=${HOST}, state=${STATE})\n`);
});
