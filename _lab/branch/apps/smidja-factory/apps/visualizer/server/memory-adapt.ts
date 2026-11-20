/**
 * memory-adapt — one translation, at the one boundary where the shapes meet.
 *
 * The Kaia bridge (`bin/bridge/mimir-bridge.py`, :4602) answers a FLAT payload —
 * `store`, `episodes`, `facts`, `entities`, `edges`. The UI's published contract
 * (`shared/types.ts`) is NESTED: `db`, `counts.{episodes,facts,entities,edges}`.
 *
 * Nothing translated between them, so `inspect?.counts.episodes` threw during render and
 * the Memory page came up **blank with no error** (measured 2026-10-20). The fix belongs
 * here rather than in the view: the API should answer its own contract, and a future shape
 * change should break a test, not a page.
 *
 * Rules:
 *   · never drop a field the bridge sent — copy, then add what the contract requires;
 *   · never overwrite a field the bridge already supplied (a `counts` that exists wins);
 *   · never invent a number that was absent — 0 is honest, a guess is not.
 */
export function adaptMemoryPayload(path: string, payload: unknown): any {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) return payload;
  const d: any = { ...(payload as Record<string, unknown>) };

  if (path === "/health") {
    if (d.ok === undefined) d.ok = d.status === "up";
    if (d.db === undefined && d.store !== undefined) d.db = d.store;
    return d;
  }

  if (path === "/inspect") {
    if (d.db === undefined && d.store !== undefined) d.db = d.store;
    if (d.counts === undefined) {
      d.counts = {
        episodes: d.episodes ?? 0,
        facts: d.facts ?? 0,
        entities: d.entities ?? 0,
        edges: d.edges ?? 0,
      };
    }
    return d;
  }

  return d;
}
