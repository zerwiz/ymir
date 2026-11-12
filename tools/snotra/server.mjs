#!/usr/bin/env node
// snotra — the meeting ear MCP face. Read-only access to stored meeting minutes
// and transcripts. Any seat's agent can ask "what did we decide about X?".
// Run:   node server.mjs  (env: PORT default 8321, SNOTRA_VAULT default $YMIR_HOME)
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";
import { readdir, readFile, stat } from "node:fs/promises";
import { join } from "node:path";

const PORT = Number(process.env.PORT || 8321);
const VAULT = process.env.SNOTRA_VAULT || process.env.YMIR_HOME || join(process.env.HOME, "Documents", "ymirhome");
const MINUTES_DIR = process.env.SNOTRA_MINUTES_DIR || join(VAULT, "hodd", "workspaces", "meetings");

const SERVER_DEF = { name: "snotra", version: "0.1.0" };

// --- helpers ----------------------------------------------------------------

async function listMinutes() {
  const entries = [];
  try {
    const dir = await readdir(MINUTES_DIR, { withFileTypes: true });
    for (const e of dir) {
      if (e.isFile() && e.name.endsWith(".md")) {
        const s = await stat(join(MINUTES_DIR, e.name));
        entries.push({ name: e.name, size: s.size, mtime: s.mtime });
      }
    }
  } catch {
    // vault not mounted yet — silent
  }
  return entries;
}

async function readMinute(name) {
  try {
    return await readFile(join(MINUTES_DIR, name), "utf8");
  } catch {
    return null;
  }
}

// --- tools & resource (registered per-connection) ---------------------------

function registerTools(mcp) {
  mcp.registerTool(
    "snotra_list",
    {
      title: "List stored meetings",
      description: "List all meeting minutes in the vault (read-only).",
      inputSchema: {}
    },
    async () => {
      const entries = await listMinutes();
      const lines = entries.map(e => `${e.name}  ${e.size}B  ${e.mtime.toISOString().slice(0, 10)}`);
      return { content: [{ type: "text", text: lines.join("\n") || "(no meetings stored)" }] };
    }
  );

  mcp.registerTool(
    "snotra_read",
    {
      title: "Read a meeting minute",
      description: "Read the full content of a stored meeting minute.",
      inputSchema: { name: z.string() }
    },
    async ({ name }) => {
      const text = await readMinute(name);
      if (!text) return { content: [{ type: "text", text: `no meeting found: ${name}` }], isError: true };
      return { content: [{ type: "text", text: text }] };
    }
  );

  mcp.registerTool(
    "snotra_search",
    {
      title: "Search meeting minutes",
      description: "Search meeting minutes for a keyword or phrase (case-insensitive).",
      inputSchema: { query: z.string() }
    },
    async ({ query }) => {
      const entries = await listMinutes();
      const results = [];
      for (const e of entries) {
        const text = await readMinute(e.name);
        if (text && text.toLowerCase().includes(query.toLowerCase())) {
          results.push({ name: e.name, snippet: text.slice(0, 200) });
        }
      }
      const lines = results.map(r => `${r.name}\n  ${r.snippet}...`);
      return { content: [{ type: "text", text: lines.join("\n\n") || "(no matches)" }] };
    }
  );

  mcp.registerTool(
    "snotra_summary",
    {
      title: "Summary of all meetings",
      description: "Return a brief summary of all stored meetings (names, dates, topics).",
      inputSchema: {}
    },
    async () => {
      const entries = await listMinutes();
      const lines = entries.map(e => `${e.name}  ${e.mtime.toISOString().slice(0, 10)}`);
      return { content: [{ type: "text", text: `Meetings: ${entries.length}\n${lines.join("\n")}` }] };
    }
  );

  mcp.resource(
    "the-ear",
    "snotra://ear",
    "the meeting ear — how many meetings are stored",
    async () => {
      const entries = await listMinutes();
      return {
        contents: [{ uri: "snotra://ear", mimeType: "text/plain", text: `meetings: ${entries.length}` }]
      };
    }
  );
}

function newMcp() {
  const mcp = new McpServer(SERVER_DEF);
  registerTools(mcp);
  return mcp;
}

// --- serve ------------------------------------------------------------------

const sessions = new Map();

function newTransport() {
  const t = new StreamableHTTPServerTransport({
    sessionIdGenerator: () => crypto.randomUUID(),
    onsessioninitialized: () => {}
  });
  t.onclose = () => {
    for (const [k, v] of sessions) {
      if (v === t) sessions.delete(k);
    }
  };
  return t;
}

// The bind and the browser ward (2026-11-12): loopback unless the operator widens it
// (YMIR_FLEET_BIND in ~/.config/ymir/fleet.env — a multi-machine heart names its tailnet
// address), and no wildcard CORS: a page in the operator's browser must not drive this door.
// A LIST (2026-11-12, ticket ymir/80): a heart listens on loopback AND its tailnet address, never the LAN.
const BINDS = String(process.env.SNOTRA_BIND || process.env.YMIR_FLEET_BIND || "127.0.0.1").split(/[\s,]+/).filter(Boolean);
const BIND = BINDS[0];
const ALLOWED_ORIGINS = (process.env.SNOTRA_CORS_ORIGINS || "").split(",").map(s => s.trim()).filter(Boolean);
const originAllowed = (req) => !req.headers.origin || ALLOWED_ORIGINS.includes(String(req.headers.origin));
import("node:http").then(({ default: http }) => {
  const serverHttp = http.createServer(async (req, res) => {
    if (!originAllowed(req)) { res.writeHead(403).end(); return; }
    const cors = {
      "access-control-allow-headers": "content-type, accept, mcp-session-id, mcp-protocol-version, mcp-integration-context",
      "access-control-allow-methods": "POST, OPTIONS, DELETE",
      "access-control-expose-headers": "mcp-session-id, Mcp-Session-Id"
    };
    if (req.headers.origin) { cors["access-control-allow-origin"] = String(req.headers.origin); cors["vary"] = "Origin"; }
    if (req.method === "OPTIONS") { res.writeHead(204, cors).end(); return; }
    if (!["POST", "DELETE"].includes(req.method)) { res.writeHead(405).end(); return; }
    // Set accept headers for the SDK handshake
    res.setHeader("accept", "application/json, text/event-stream");

    globalThis.__snotraSessions ||= new Map();
    const reqSid = String(req.headers["mcp-session-id"] || "");
    let entry = reqSid ? globalThis.__snotraSessions.get(reqSid) : null;

    if (req.method === "DELETE" && reqSid) {
      globalThis.__snotraSessions.delete(reqSid);
      return;
    }

    if (!entry) {
      const mcp = newMcp();
      const transport = new StreamableHTTPServerTransport({
        sessionIdGenerator: () => crypto.randomUUID(),
        onsessioninitialized: (id) => {
          if (!globalThis.__snotraSessions.has(id)) {
            globalThis.__snotraSessions.set(id, { mcp, transport });
          }
        }
      });
      await mcp.connect(transport);
      entry = { mcp, transport };
      if (!reqSid) globalThis.__snotraSessions.set("boot", entry);
    }

    const transport = entry.transport;
    Object.entries(cors).forEach(([k, v]) => res.setHeader(k, v));
    res.setHeader("content-type", "application/json");
    try {
      const raw = await new Promise((ok, no) => {
        let b = "";
        req.on("data", c => { b += c; if (b.length > 2 << 20) req.destroy(); });
        req.on("end", () => ok(b));
        req.on("error", no);
      });
      let parsed = null;
      try { parsed = JSON.parse(raw); } catch { /* raw body */ }
      await transport.handleRequest(req, res, parsed);
    } catch (e) {
      res.end(JSON.stringify({ jsonrpc: "2.0", id: null, error: { code: -32603, message: String(e) } }));
    }
  });
  serverHttp.listen(PORT, BIND);
    for (const extra of BINDS.slice(1)) http.createServer((q, r) => serverHttp.emit("request", q, r)).listen(PORT, extra);
}).catch(e => { process.stderr.write(String(e)); });
