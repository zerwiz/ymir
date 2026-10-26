// well-mcp — the served MCP face of the well (engram via the :4602 bridge).
// Bodies (pi · opencode) register this URL; no local store on any body.
// Run:   bun run server.ts  (env: WELL_URL default http://127.0.0.1:4602, PORT default 8317)
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { z } from "zod";

const WELL = process.env.WELL_URL || "http://127.0.0.1:4602";
const PORT = Number(process.env.PORT || 8317);

const server = new McpServer({ name: "well", version: "0.1.0" });

server.registerTool(
  "well_recall",
  {
    title: "Recall from the well",
    description:
      "Recall memories relevant to a query. SCOPE FIRST (plan 136): pass a store, a tag or a since date " +
      "and the search is confined to that shelf before similarity is scored. Voided and archived episodes " +
      "are never returned.",
    inputSchema: {
      query: z.string(),
      limit: z.number().optional(),
      store: z.enum(["episodic", "semantic", "procedural"]).optional(),
      tag: z.string().optional(),
      since: z.string().optional(),
    },
  },
  async ({ query, limit, store, tag, since }) => {
    const qs = new URLSearchParams({ q: query });
    if (limit) qs.set("k", String(limit));
    if (store) qs.set("store", store);
    if (tag) qs.set("tag", tag);
    if (since) qs.set("since", since);
    const r = await fetch(`${WELL}/recall?${qs.toString()}`);
    return { content: [{ type: "text", text: await r.text() }] };
  },
);
server.registerTool(
  "well_remember",
  {
    title: "Observe into the well",
    description:
      "Store a memory. THE GATE (plan 136): a write must change future behaviour, be a commitment with " +
      "consequences, or be a decision with rationale — otherwise it is dropped and the reason comes back. " +
      "State the shape and the shelf when you know them.",
    inputSchema: {
      content: z.string(),
      actors: z.string().optional(),
      tags: z.string().optional(),
      shape: z.enum(["behaviour", "commitment", "decision"]).optional(),
      store: z.enum(["episodic", "semantic", "procedural"]).optional(),
      task: z.string().optional(),
    },
  },
  async ({ content, actors, tags, shape, store, task }) => {
    const r = await fetch(`${WELL}/observe`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ content, actors, tags, shape, store, task }),
    });
    return { content: [{ type: "text", text: await r.text() }] };
  },
);
server.registerTool(
  "well_correct",
  {
    title: "Correct a memory",
    description:
      "Append a correction that CHAINS to the original by id (never an overwrite): the replacement names " +
      "the original, the original is annotated void, and recall stops handing the old version back as fact.",
    inputSchema: { original_id: z.string(), content: z.string(), actors: z.string().optional() },
  },
  async ({ original_id, content, actors }) => {
    const r = await fetch(`${WELL}/correct`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ original_id, content, actors }),
    });
    return { content: [{ type: "text", text: await r.text() }] };
  },
);
server.registerTool(
  "well_health",
  { title: "The well's health", description: "Store path, episodes, agents", inputSchema: {} },
  async () => {
    const r = await fetch(`${WELL}/health`);
    return { content: [{ type: "text", text: await r.text() }] };
  },
);

const sessions = new Map<string, StreamableHTTPServerTransport>();

function newTransport(): StreamableHTTPServerTransport {
  const t = new StreamableHTTPServerTransport({
    sessionIdGenerator: () => crypto.randomUUID(),
    onsessioninitialized: () => {},
  });
  t.onclose = () => { for (const [k, v] of sessions) if (v === t) sessions.delete(k); };
  return t;
}

Bun.serve({
  port: PORT,
  async fetch(req: Request) {
    const url = new URL(req.url);
    if (req.method === "DELETE") {
      const sid = new URL(req.url).searchParams.get("sessionId") || req.headers.get("mcp-session-id") || "";
      sessions.delete(sid);
      return new Response(null, { status: 200 });
    }
    if (url.pathname !== "/mcp") return new Response("well-mcp — /mcp is the door", { status: 404 });
    const sid = new URL(req.url).searchParams.get("sessionId") || req.headers.get("mcp-session-id") || "";
    let transport = sid ? sessions.get(sid) : undefined;
    if (!transport) {
      transport = newTransport();
      sessions.set(transport.sessionId, transport);
      const init = await server.connect(transport);
      const headers = new Headers();
      headers.set("mcp-session-id", transport.sessionId);
      if (req.method === "POST") headers.set("location", `/mcp?sessionId=${encodeURIComponent(transport.sessionId)}`);
      return init.response ?? new Response(null, { status: 200, headers });
    }
    const { body, parsedBody } = await transport.handleRequest(req, new URL(req.url));
    return body ?? new Response(null, { status: 200 });
  },
});

console.log(`well-mcp: serving ${WELL} on :${PORT}/mcp`);