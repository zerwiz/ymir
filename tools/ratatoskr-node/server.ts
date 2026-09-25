// ratatoskr-node.ts — the heart's A2A node (wave D, 2026-09-23).
// DefaultRequestHandler + InMemoryTaskStore + a WELL round-trip executor,
// served over JSON-RPC (the A2A 1.0 wire) at :8301.
import { AgentCard, AgentSkill, Message, Part, Role, TaskState, TextPart } from "@a2a-js/sdk";
import { DefaultRequestHandler, InMemoryTaskStore, JsonRpcTransportHandler, ServerCallContext, type AgentExecutor, type RequestContext, type AgentExecutionEvent } from "@a2a-js/sdk/server";

const WELL = process.env.WELL_URL || "http://127.0.0.1:4602";
const PORT = Number(process.env.PORT || 8301);

// The card's `url` must be the address a PEER uses to reach this node — over the
// fleet that is the tailnet name, never a LAN address (a home IP is dead on the
// road). Resolved, not hardcoded (Rule 07): an explicit A2A_ADVERTISE_URL wins,
// then A2A_ADVERTISE_HOST, then this host's own tailnet DNS name, then loopback.
function tailnetHost(): string | undefined {
  try {
    const out = Bun.spawnSync(["tailscale", "status", "--json"], { stdout: "pipe", stderr: "ignore" });
    if (out.exitCode !== 0) return undefined;
    const self = JSON.parse(out.stdout.toString())?.Self?.DNSName as string | undefined;
    return self ? self.replace(/\.$/, "") : undefined;
  } catch {
    return undefined;
  }
}

function advertiseUrl(): string {
  const explicit = process.env.A2A_ADVERTISE_URL;
  if (explicit) return explicit.endsWith("/") ? explicit : `${explicit}/`;
  const host = process.env.A2A_ADVERTISE_HOST || tailnetHost() || "127.0.0.1";
  return `http://${host}:${PORT}/`;
}

const card: AgentCard = {
  name: process.env.A2A_AGENT_NAME || "heart-whynot",
  description: "The record heart + the forge: gate, well, mill, served-MCP. The A2A node of the federation.",
  url: advertiseUrl(),
  version: "1.0.0",
  capabilities: {
    streaming: true,
    pushNotifications: false,
    stateTransitionHistory: false,
  },
  skills: [{ id: "well-recall", name: "well-recall", description: "Recall from the well" } satisfies AgentSkill],
  defaultInputModes: ["text"],
  defaultOutputModes: ["text"],
  securitySchemes: [],
  security: [],
  protocols: ["a2a"],
};

const executor: AgentExecutor = {
  async *executeTask(context: RequestContext): AsyncIterable<AgentExecutionEvent> {
    const task = (context as { request: { task?: Task } }).request?.task;
    const query = task?.parts?.[0] && "text" in task.parts[0] ? (task.parts[0] as TextPart).text : "health";
    let reply = "well idle";
    try {
      const r = await fetch(`${WELL}/recall?q=${encodeURIComponent(query)}&k=3`);
      reply = (await r.text()).slice(0, 600) || "no recall";
    } catch { reply = "well unreachable"; }
    const m: Message = { role: Role.AGENT, parts: [{ kind: "text", text: reply }] as unknown as Part[] };
    yield { kind: "task", task: { ...task!, status: { state: TaskState.COMPLETED }, message: m } } as AgentExecutionEvent;
  },
};

const store = new InMemoryTaskStore();
const requestHandler = new DefaultRequestHandler(card, store, executor);
const transport = new JsonRpcTransportHandler(requestHandler);

const server = Bun.serve({
  port: PORT,
  async fetch(req: Request) {
    const url = new URL(req.url);
    if (url.pathname === "/.well-known/agent-card.json") return Response.json(card);
    if (req.method === "POST") {
      const body = await req.text();
      const context = new ServerCallContext({}); // tenant/user defaults
      const out = await transport.handle(body, context);
      if (out && typeof (out as AsyncGenerator).next === "function") {
        const first = await (out as AsyncGenerator).next();
        return Response.json(first.value, { headers: { "content-type": "application/json" } });
      }
      return Response.json(out, { headers: { "content-type": "application/json" } });
    }
    if (url.pathname === "/.well-known/agent-card.json") return Response.json(card);
    return new Response("ratatoskr node — POST JSON-RPC here; card at /.well-known/agent-card.json", { status: 404 });
  },
});
console.log(`ratatoskr: heart node on :${PORT} — card + JSON-RPC live`);