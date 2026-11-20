// ratatoskr-node.ts — the heart's A2A node (wave D, 2026-09-23).
// DefaultRequestHandler + InMemoryTaskStore + a WELL round-trip executor,
// served over JSON-RPC (the A2A 1.0 wire) at :8301.
import { Message, Part, Role, TaskState, TextPart, type AgentCard as SdkAgentCard } from "@a2a-js/sdk";
import { DefaultRequestHandler, InMemoryTaskStore, JsonRpcTransportHandler, ServerCallContext, type AgentExecutor, type RequestContext, type AgentExecutionEvent } from "@a2a-js/sdk/server";
import { A2A_CARD_PATH, type AgentCard } from "../../contracts/src/index.ts";
import { heartCard } from "./card.ts";

const WELL = process.env.WELL_URL || "http://127.0.0.1:4602";
const PORT = Number(process.env.PORT || 8301);

// The card is the SHARED contract's: built (and validated) at boot, so a card
// that left the shape fails here, loudly, and never reaches the wire.
const card: AgentCard = heartCard();

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
const requestHandler = new DefaultRequestHandler(card as unknown as SdkAgentCard, store, executor);
const transport = new JsonRpcTransportHandler(requestHandler);

const server = Bun.serve({
  port: PORT,
  async fetch(req: Request) {
    const url = new URL(req.url);
    if (url.pathname === A2A_CARD_PATH) return Response.json(card);
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
    return new Response(`ratatoskr node — POST JSON-RPC here; card at ${A2A_CARD_PATH}`, { status: 404 });
  },
});
console.log(`ratatoskr: heart node on :${PORT} — card + JSON-RPC live`);
