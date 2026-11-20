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
    let res: Response;
    try {
      res = await fetch(new URL(path, BRIDGE).toString(), {
        ...init,
        headers: { "content-type": "application/json", ...(init?.headers ?? {}) },
        // Cold starts fetch the embedding model once (measured ~17s); the 60s
        // default is the headroom — tune via YMIR_WELL_TIMEOUT_MS (Rule 07).
        signal: AbortSignal.timeout(Number(process.env.YMIR_WELL_TIMEOUT_MS) || 60000),
      });
    } catch (e) {
      // A refused or timed-out connection is NOT an HTTP answer — fetch rejects
      // instead of returning a response. Shape it like one so every caller (the
      // tools above, the probe below) reads the same "not ok" and says so
      // plainly instead of throwing.
      return { ok: false as const, status: 0, body: String((e as Error)?.message ?? e) };
    }
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
        // SCOPED RECALL (plan 136): the shelf is chosen BEFORE the search, so a
        // keeper's own memory is not out-competed by everyone's.
        store: {
          type: "string",
          description: "shelf to search: episodic (events) | semantic (facts, preferences) | procedural (how-to)",
        },
        tag: { type: "string", description: "only episodes carrying this tag, e.g. 'domain:snotra'" },
        since: { type: "string", description: "only episodes at or after this date (YYYY-MM-DD)" },
      },
      required: ["query"],
    },
    async execute(
      _id: string,
      params: { query: string; k?: number; store?: string; tag?: string; since?: string },
    ) {
      const k = Math.max(1, Math.min(20, Number(params.k ?? 5)));
      const qs = new URLSearchParams({ q: params.query, k: String(k) });
      if (params.store) qs.set("store", params.store);
      if (params.tag) qs.set("tag", params.tag);
      if (params.since) qs.set("since", params.since);
      const r = await call(`/recall?${qs.toString()}`);
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
          // The shelf and the write's source are shown, not buried: a keeper must
          // be able to tell a fact from a workflow from an event at a glance.
          const shelf = e.store ? `{${e.store}}` : "";
          return `${i + 1}. [${Number(h.score ?? 0).toFixed(2)}]${shelf} ${String(e.content ?? "").slice(0, 600)}${tags ? `\n   tags: ${tags}` : ""}`;
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
        // THE GATE (plan 136). A write that changes no behaviour, commits to
        // nothing and decides nothing is DROPPED, so say which of the three this
        // is, and what kind of memory it is. Stating the shape is a claim the
        // writer makes; it is recorded and audited, never assumed.
        shape: {
          type: "string",
          description: "which question this answers: behaviour | commitment | decision",
        },
        store: {
          type: "string",
          description: "the shelf: episodic (an event) | semantic (a fact/preference) | procedural (a workflow)",
        },
        task: { type: "string", description: "what work this lesson belongs to (raises its relevance)" },
        retention: {
          type: "string",
          description: "how long it matters: 'keep' (default), 'season:<days>', 'ephemeral'",
        },
        privacy: {
          type: "string",
          description: "public | internal (default) | private. The vault and confidential material are REFUSED",
        },
      },
      required: ["content"],
    },
    async execute(
      _id: string,
      params: {
        content: string;
        tags?: string;
        actors?: string;
        salience?: number;
        shape?: string;
        store?: string;
        task?: string;
        retention?: string;
        privacy?: string;
      },
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
          shape: params.shape,
          store: params.store,
          task: params.task,
          retention: params.retention,
          privacy: params.privacy,
        }),
      });
      if (!r.ok) {
        return { content: [{ type: "text", text: `the lesson was NOT written (${r.status}): ${r.body}` }], isError: true };
      }
      const b = (r.body as any) ?? {};
      // A DROP IS A NORMAL ANSWER, and it must not read as success: the gate
      // exists so the well holds what is worth keeping, and the writer is told
      // which of the three questions it failed.
      if (b.stored === false) {
        const g = b.gate ?? {};
        return {
          content: [{
            type: "text",
            text: `the gate DROPPED it: ${g.why ?? "no reason given"}` +
              (g.duplicate_of ? `\n   it is already in the well as ${g.duplicate_of}` : "") +
              "\n   (a write must change future behaviour, be a commitment, or be a decision with rationale)",
          }],
        };
      }
      const tags = Array.isArray(b.tags) ? b.tags.join(", ") : "";
      return {
        content: [{
          type: "text",
          text: `written to the well: ${b.id ?? "?"} [${b.store ?? "?"}]` + (tags ? `\n   tags: ${tags}` : ""),
        }],
      };
    },
  });

  // A session that cannot reach the well should say so once, plainly, rather than
  // let every later recall fail in silence.
  pi.on("session_start", async () => {
    // The bridge is raised by saga-session-start.sh WHILE the digest runs, so a
    // session can outrun its own well by a second or three. Probe a few times
    // before declaring it down — a birth race is not an outage.
    let r: { ok: boolean; status: number; body: string } = { ok: false, status: 0, body: "" };
    for (let attempt = 0; attempt < 6 && !r.ok; attempt++) {
      if (attempt > 0) await new Promise((resolve) => setTimeout(resolve, 1000));
      r = await call("/health");
    }
    if (!r.ok) {
      console.error(`[ymir-well] the well did not answer (${r.status}): ${r.body}`);
      pi.registerMessageRenderer?.("ymir-well-offline", (m: any) => m);
      return;
    }
    const e = (r.body as any)?.episodes;
    if (typeof e === "number" && e === 0) {
      console.error("[ymir-well] the well is reachable but holds 0 episodes");
    }
  });
}
