/**
 * ymir-well — Kaia's memory, as tools inside every pi session.
 *
 * The well is Mimirsbrunn: the engram store at $YMIR_HOME/memory/kaia.engram,
 * reached over the bridge on :4602. Every worker Ymir seats should be able to
 * recall what was learned and observe what it learned — that is what makes the
 * fleet learn instead of re-learning. Before this, only the orchestrator could,
 * and only through smidja_orchestrate.py.
 *
 * Placement: this file belongs to the SHARED source, which the loader deploys to
 * the global extension home — pi auto-discovers BOTH the global home and a
 * project-local .pi/extensions, and the same extension in both registers its
 * tools twice, which pi refuses. ONE home. Never copy this into a project.
 *
 * Contract (pi.dev/docs/latest/extensions):
 *   - export a default factory receiving ExtensionAPI (sync or async)
 *   - registerTool works during load and at runtime
 *   - do not start background resources in the factory
 */
export default function well(pi: any) {
  const BRIDGE = process.env.YMIR_MEMORY_URL ?? "http://127.0.0.1:4602";

  /** One shape for every answer: a tool that throws teaches the model nothing. */
  async function call(path: string, init?: RequestInit) {
    const res = await fetch(new URL(path, BRIDGE).toString(), {
      ...init,
      headers: { "content-type": "application/json", ...(init?.headers ?? {}) },
      signal: AbortSignal.timeout(15000),
    });
    const body = await res.text();
    if (!res.ok) {
      return { ok: false as const, status: res.status, body: body.slice(0, 400) };
    }
    try {
      return { ok: true as const, body: JSON.parse(body) };
    } catch {
      return { ok: true as const, body };
    }
  }

  pi.registerTool({
    name: "well_recall",
    description:
      "Recall from Kaia's memory (the well) what Ymir already learned. Use before " +
      "starting work: a lesson already paid for costs nothing the second time. " +
      "Returns episodes with their score, content and tags.",
    parameters: {
      type: "object",
      properties: {
        query: { type: "string", description: "what you want to remember, in words" },
        k: { type: "number", description: "how many episodes (default 5)" },
      },
      required: ["query"],
    },
    async execute(_id: string, params: { query: string; k?: number }) {
      const k = Math.max(1, Math.min(20, Number(params.k ?? 5)));
      const r = await call(`/recall?q=${encodeURIComponent(params.query)}&k=${k}`);
      if (!r.ok) {
        return { content: [{ type: "text", text: `the well did not answer (${r.status}): ${r.body}` }], isError: true };
      }
      const hits = (r.body as any)?.results ?? [];
      if (!hits.length) {
        return { content: [{ type: "text", text: "the well holds nothing for that yet." }] };
      }
      const text = hits
        .map((h: any, i: number) => {
          const e = h.episode ?? {};
          const tags = Array.isArray(e.tags) ? e.tags.join(", ") : String(e.tags ?? "");
          return `${i + 1}. [${Number(h.score ?? 0).toFixed(2)}] ${String(e.content ?? "").slice(0, 600)}${tags ? `\n   tags: ${tags}` : ""}`;
        })
        .join("\n");
      return { content: [{ type: "text", text }] };
    },
  });

  pi.registerTool({
    name: "well_observe",
    description:
      "Write a lesson into Kaia's memory (the well). Use when a run teaches " +
      "something durable — what worked, what failed, what the next hand must know. " +
      "The orchestrator reads this before dispatch, so write it plain and true.",
    parameters: {
      type: "object",
      properties: {
        content: { type: "string", description: "the lesson, in full sentences" },
        tags: { type: "string", description: "comma-separated labels, e.g. 'run,lesson'" },
        actors: { type: "string", description: "comma-separated names involved" },
        salience: { type: "number", description: "importance 0..1 (default 0.7)" },
      },
      required: ["content"],
    },
    async execute(
      _id: string,
      params: { content: string; tags?: string; actors?: string; salience?: number },
    ) {
      // LISTS, never comma-strings: the store keeps a string as an array of
      // CHARACTERS, and a later recall then reads tags as "r,u,n".
      const list = (v?: string) =>
        String(v ?? "").split(",").map((s) => s.trim()).filter(Boolean);
      const r = await call("/observe", {
        method: "POST",
        body: JSON.stringify({
          content: params.content,
          tags: list(params.tags ?? "run,lesson"),
          actors: list(params.actors),
          salience: Math.max(0, Math.min(1, Number(params.salience ?? 0.7))),
        }),
      });
      if (!r.ok) {
        return { content: [{ type: "text", text: `the lesson was NOT written (${r.status}): ${r.body}` }], isError: true };
      }
      const id = (r.body as any)?.id ?? "?";
      return { content: [{ type: "text", text: `written to the well: ${id}` }] };
    },
  });

  // A session that cannot reach the well should say so once, plainly, rather than
  // let every later recall fail in silence.
  pi.on("session_start", async () => {
    const r = await call("/health");
    if (!r.ok) {
      pi.registerMessageRenderer?.("ymir-well-offline", (m: any) => m);
      return;
    }
    const e = (r.body as any)?.episodes;
    if (typeof e === "number" && e === 0) {
      console.error("[ymir-well] the well is reachable but holds 0 episodes");
    }
  });
}
