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

const SERVER_DEF = { name: "snotra", version: "0.2.0" };

// --- the ear (STT): a LIVE resolution, never a single point -----------------
// The heart fronts this door; the HEARING rides a strong box (plan 51 Part
// 9a — the heart's GPU cannot run whisper). The candidate order is the fleet
// registry's `ear` row (private, resolved at runtime — never a URL in this
// file); whichever box answers /health first serves, and a dropped box is a
// reroute, never an outage (Part 9c). The fallback order below is DOCTRINE
// (first-heimdall, then whynot, then omarchy) and carries names only.
const EAR_PORT = process.env.SNOTRA_EAR_PORT || "8322";
const EAR_PATH = process.env.SNOTRA_EAR_PATH || "/inference";
const EAR_TIMEOUT_MS = Number(process.env.SNOTRA_EAR_TIMEOUT_MS || 4000);
const EAR_TTL_MS = Number(process.env.SNOTRA_EAR_TTL_MS || 30000);
const FLEET_REGISTRY = process.env.SNOTRA_FLEET_REGISTRY || join(VAULT, "hodd", "data", "fleet.json");
const EAR_FALLBACK_ORDER = ["heimdall", "whynot", "omarchy"];
let earCache = { url: null, seat: null, at: 0, health: null };
// An ear that answers /health but ABORTS on a request (whynot's CUDA build on a
// Pascal card does exactly that) must not black-hole the lane: a failed POST
// marks that box out for a spell and the next live box takes the request.
const earFailed = new Map();   // url -> epoch ms until which it is out
const EAR_EJECT_MS = Number(process.env.SNOTRA_EAR_EJECT_MS || 60000);
function earDead(url) {
  const t = earFailed.get(url);
  if (!t) return false;
  if (t < Date.now()) { earFailed.delete(url); return false; }
  return true;
}
function markEarDead(url) { earFailed.set(url, Date.now() + EAR_EJECT_MS); }

async function earCandidates() {
  let order = EAR_FALLBACK_ORDER;
  let hosts = {};
  try {
    const doc = JSON.parse(await readFile(FLEET_REGISTRY, "utf8"));
    if (Array.isArray(doc.ear) && doc.ear.length) order = doc.ear.filter(x => typeof x === "string");
    hosts = doc.hosts || {};
  } catch {
    // no registry on this seat — the doctrine order, still without a URL here
  }
  return order.map(name => {
    const h = hosts[name] || {};
    return { seat: name, url: `http://${h.tailnet || h.lan || name}:${EAR_PORT}` };
  });
}

async function probeEar(url) {
  try {
    const r = await fetch(`${url}/health`, { signal: AbortSignal.timeout(EAR_TIMEOUT_MS) });
    if (!r.ok) return null;
    return await r.json().catch(() => ({}));
  } catch {
    return null;
  }
}

async function resolveEar(force = false) {
  const now = Date.now();
  if (!force && earCache.url && now - earCache.at < EAR_TTL_MS && !earDead(earCache.url)) return earCache;
  for (const c of await earCandidates()) {
    if (earDead(c.url)) continue;
    const health = await probeEar(c.url);
    if (health) {
      earCache = { url: c.url, seat: c.seat, at: now, health };
      return earCache;
    }
  }
  const tried = (await earCandidates()).map(c => c.seat).join(", ");
  earCache = { url: null, seat: null, at: now, health: null, tried };
  return earCache;
}

// postEar <ear> <bytes> <filename> <language> — one attempt, resolved shape
async function postEar(ear, bytes, filename, language) {
  const form = new FormData();
  form.append("file", new Blob([bytes], { type: "audio/wav" }), filename || "clip.wav");
  form.append("response_format", "json");
  form.append("language", language || "en");
  const r = await fetch(`${ear.url}${EAR_PATH}`, {
    method: "POST", body: form, signal: AbortSignal.timeout(600000)
  });
  const raw = await r.text();
  if (!r.ok) throw new Error(`HTTP ${r.status}: ${raw.slice(0, 200)}`);
  try { const j = JSON.parse(raw); return j.text ?? j.transcription ?? raw; } catch { return raw; }
}

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
    "the meeting ear — stored meetings and the live hearing box",
    async () => {
      const entries = await listMinutes();
      const ear = await resolveEar();
      const live = ear.url ? `ear: ${ear.seat} (${ear.url})` : `ear: none live (tried: ${ear.tried || "none"})`;
      return {
        contents: [{ uri: "snotra://ear", mimeType: "text/plain", text: `meetings: ${entries.length}\n${live}` }]
      };
    }
  );

  // The hearing itself: the door posts the audio to whichever strong box is
  // live at this instant. Provenance (which seat heard) rides the answer, so a
  // caller is never told a pleasant lie about where the ear stood.
  mcp.registerTool(
    "snotra_ear",
    {
      title: "Where the ear hears from",
      description: "Report the live strong box carrying whisper for the fleet (plan 51 Part 9c live resolution).",
      inputSchema: {}
    },
    async () => {
      const ear = await resolveEar(true);
      if (!ear.url) {
        return { content: [{ type: "text", text: `no live ear — tried: ${ear.tried || "none"}` }], isError: true };
      }
      return { content: [{ type: "text", text: `ear: ${ear.seat}\nurl: ${ear.url}\nhealth: ${JSON.stringify(ear.health)}` }] };
    }
  );

  mcp.registerTool(
    "snotra_transcribe",
    {
      title: "Transcribe audio on the fleet's ear",
      description: "Transcribe a short audio clip (base64) on whichever strong box carries whisper now. For a stored meeting use snotra_list/snotra_read; for a full-length recording use bin/snotra-transcribe.sh on the capture seat.",
      inputSchema: {
        audio_base64: z.string().describe("the audio bytes, base64-encoded (wav/mp3/ogg)"),
        filename: z.string().optional().describe("the clip's name, for the ear's log"),
        language: z.string().optional().describe("spoken language (default en)")
      }
    },
    async ({ audio_base64, filename, language }) => {
      let bytes;
      try {
        bytes = Buffer.from(String(audio_base64 || ""), "base64");
      } catch {
        return { content: [{ type: "text", text: "audio_base64 is not valid base64" }], isError: true };
      }
      if (!bytes.length) return { content: [{ type: "text", text: "audio_base64 is empty" }], isError: true };
      let lastErr = "none";
      // one attempt per live candidate: a box that dies mid-request is ejected
      // and the next live box hears instead — a reroute, never an outage.
      for (let attempt = 0; attempt < 4; attempt++) {
        const ear = await resolveEar(attempt > 0);
        if (!ear.url) break;
        try {
          const text = await postEar(ear, bytes, filename, language);
          return { content: [{ type: "text", text: `[ear=${ear.seat}] ${String(text).trim()}` }] };
        } catch (e) {
          lastErr = `${ear.seat}: ${String(e)}`;
          markEarDead(ear.url);
        }
      }
      const tried = earCache.tried || "none";
      return { content: [{ type: "text", text: `no ear could hear — last: ${lastErr}; tried: ${tried}` }], isError: true };
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

import("node:http").then(({ default: http }) => {
  const serverHttp = http.createServer(async (req, res) => {
    const cors = {
      "access-control-allow-origin": "*",
      "access-control-allow-headers": "content-type, accept, mcp-session-id, mcp-protocol-version, mcp-integration-context",
      "access-control-allow-methods": "POST, OPTIONS, DELETE",
      "access-control-expose-headers": "mcp-session-id, Mcp-Session-Id"
    };
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
        // The audio lane: a clip rides the door as base64 JSON-RPC, so the
        // body cap must clear a short recording (64 MB ≈ a few minutes of
        // 16 kHz mono once base64-expanded).
        req.on("data", c => { b += c; if (b.length > 64 << 20) req.destroy(); });
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
  serverHttp.listen(PORT, "0.0.0.0");
}).catch(e => { process.stderr.write(String(e)); });
