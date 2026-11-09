/**
 * reading.ts — the ONE counter for "how much room is left in this session".
 *
 * Pure functions, no pi import, no shell, no clock of their own: everything the
 * reading needs arrives in a Snapshot that `index.ts` gathers from the harness.
 * That is deliberate — it is the only way the number can be TESTED (a session
 * that spends tokens must report a smaller remainder) without a live model, and
 * the only way the voice can be sure it is repeating this arithmetic rather than
 * inventing a second counter (`bin/voice/voice_tools.py` reads the published
 * reading this module derives).
 *
 * The three facts, and where each comes from (never a guess):
 *
 *   1. the tokens of the last turn   ctx.getContextUsage().tokens, and the last
 *                                   assistant message's own `usage.input`
 *   2. the window the model holds    ctx.model.contextWindow — the catalogue's
 *                                   own number (RULES/07: resolve, never assume)
 *   3. turns until the engine        derived: (window - reserve - tokens) / the
 *      compacts                     session's own tokens-per-turn
 *
 * A session whose window is unknown gets a REFUSAL with the reason. So does a
 * session whose token count the harness cannot measure yet (it is null right
 * after a compaction, before the next response). "I do not know" is a true
 * answer; a fabricated window is the fault this module exists to prevent.
 */

/** Everything the harness can tell us, gathered once, honestly. */
export interface Snapshot {
  /** ctx.getContextUsage().tokens — estimated context tokens, or null when unknown. */
  tokens: number | null;
  /** ctx.getContextUsage().contextWindow — the model's window, or null when undeclared. */
  contextWindow: number | null;
  /** Tokens held back before compaction. */
  reserveTokens: number;
  /** Where reserveTokens came from, so a reader can check it. */
  reserveSource: string;
  /** User turns spoken in this session; null when the session cannot be counted. */
  userTurns: number | null;
  /** The last assistant message's `usage.input` — what the last turn carried. */
  lastTurnTokens: number | null;
  /** The model id, as the catalogue names it. */
  model: string;
  /** The session id the harness mints. */
  session: string;
  /** The working directory, for a human reading the record. */
  cwd: string;
  /** The reading's own instant, ISO 8601, supplied by the caller (never Date.now here). */
  at: string;
}

export interface Reading {
  ok: boolean;
  /** Why the reading cannot answer — present only when ok is false. */
  reason?: string;
  tokens?: number;
  contextWindow?: number;
  percent?: number;
  compactAt?: number;
  remaining?: number;
  state?: "room" | "at-threshold" | "past-threshold";
  userTurns?: number | null;
  lastTurnTokens?: number | null;
  perTurn?: number | null;
  turnsLeft?: number | null;
  reserveTokens?: number;
  reserveSource?: string;
  model?: string;
  session?: string;
  at?: string;
}

const positive = (n: unknown): n is number =>
  typeof n === "number" && Number.isFinite(n) && n > 0;

/**
 * Derive the reading. Never rounds a refusal into a number: if either half of the
 * ratio is unknown, the answer says so and names which half.
 */
export function deriveReading(s: Snapshot): Reading {
  if (!positive(s.contextWindow)) {
    return {
      ok: false,
      reason:
        `the context window is unknown for ${s.model || "this model"} — the catalogue declares no ` +
        `contextWindow, and a window is never assumed (RULES/07). Nothing here is a guess: ask again ` +
        `after the model is resolved, or name the window in the model's catalogue entry.`,
    };
  }
  if (!positive(s.tokens)) {
    return {
      ok: false,
      reason:
        "the harness reports no measured context for this session yet (it is null right after a " +
        "compaction and before the next response). Ask again after the next turn — an estimate " +
        "here would be a guess.",
    };
  }

  const reserve = positive(s.reserveTokens) ? s.reserveTokens : 0;
  const compactAt = Math.max(0, s.contextWindow - reserve);
  const remaining = compactAt - s.tokens;
  const state: Reading["state"] =
    remaining > 0 ? "room" : remaining === 0 ? "at-threshold" : "past-threshold";

  // Tokens per turn: the session's own spending, never a rule of thumb. `tokens`
  // is the projected context, which is what the window is spent on.
  let perTurn: number | null = null;
  if (positive(s.userTurns) && s.tokens > 0) perTurn = Math.round(s.tokens / s.userTurns);
  const turnsLeft =
    perTurn && perTurn > 0 ? Math.max(0, Math.floor(Math.max(0, remaining) / perTurn)) : null;

  return {
    ok: true,
    tokens: s.tokens,
    contextWindow: s.contextWindow,
    percent: Math.round((s.tokens / s.contextWindow) * 1000) / 10,
    compactAt,
    remaining,
    state,
    userTurns: s.userTurns,
    lastTurnTokens: s.lastTurnTokens,
    perTurn,
    turnsLeft,
    reserveTokens: reserve,
    reserveSource: s.reserveSource,
    model: s.model,
    session: s.session,
    at: s.at,
  };
}

const n = (v: number | null | undefined): string =>
  v === null || v === undefined || !Number.isFinite(v) ? "unknown" : String(Math.round(v));
const pct = (v: number | null | undefined): string =>
  v === null || v === undefined || !Number.isFinite(v) ? "unknown" : `${v}%`;

/** The agent-facing answer: the same three facts the voice tool reports. */
export function renderReading(r: Reading): string {
  if (!r.ok) {
    return `context_left[1]{state,why}:\n  "unknown","${oneLine(r.reason ?? "no reason given")}"`;
  }
  const verdict =
    r.state === "room"
      ? `about ${n(r.turnsLeft)} more turn(s) of this size before the engine compacts`
      : r.state === "at-threshold"
        ? "the compaction threshold is reached — the next turn will be summarised"
        : `past the compaction threshold by ${n(-(r.remaining ?? 0))} tokens — summarise now, or save a plan`;

  return [
    `context_left[9]{tokens,window,percent,compact_at,remaining,user_turns,per_turn,turns_left,state}:`,
    `  "${n(r.tokens)}","${n(r.contextWindow)}","${pct(r.percent)}","${n(r.compactAt)}",` +
      `"${n(r.remaining)}","${n(r.userTurns ?? null)}","${n(r.perTurn)}","${n(r.turnsLeft)}","${r.state}"`,
    ``,
    `the last turn carried ${n(r.lastTurnTokens ?? null)} prompt tokens; the window holds ${n(r.contextWindow)}.`,
    `the engine compacts at ${n(r.compactAt)} (${n(r.reserveTokens)} reserved, ${r.reserveSource}), so ` +
      `${n(r.remaining)} tokens of room remain — ${verdict}.`,
    `model ${r.model} · session ${r.session} · reading taken ${r.at}`,
  ].join("\n");
}

function oneLine(text: string): string {
  return String(text).replace(/\s+/g, " ").replace(/"/g, "'").trim();
}
