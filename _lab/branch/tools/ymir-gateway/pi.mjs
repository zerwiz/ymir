/**
 * pi.mjs — the LOCAL brain: the same `Brain` shape, speaking to the llama rail on this box.
 *
 * Plan 68, P1/P3. The house rule (AGENTS.md): **local models → pi, hosted → opencode.**
 * This is the "pi" half: no cloud, no per-token cost, and it keeps working when the tailnet or the
 * internet does not.
 *
 * WHY IT EXISTS AS ITS OWN FILE: the voice layer must never branch on which brain it has. Two
 * implementations, one interface, and a test that drives BOTH through it — because a seam that only
 * ever gets exercised in one direction is a seam nobody has tested.
 *
 * The rail is an OpenAI-compatible server (`http://127.0.0.1:8080/v1`) serving the house's models.
 * One model is resident at a time, chosen by the request, and the RAIL, not this file, decides what
 * fits the card. Voice work competes for that VRAM; `voice-gpu-lib.sh` frees it on demand — that is
 * P3's job, and it is why the brain takes a model name rather than assuming one.
 */

import { Brain } from "./acp.mjs";
import { BRAINS } from "./session.mjs";

const DEFAULT_RAIL = "http://127.0.0.1:8080/v1";
const DEFAULT_MODEL = "qwen3.6-35b-a3b@iq3_s";

export class LocalBrain extends Brain {
  constructor({ railUrl, model, timeoutMs = 120_000, fetchImpl } = {}) {
    super(BRAINS.PI);
    this.railUrl = (railUrl ?? process.env.YMIR_RAIL_URL ?? DEFAULT_RAIL).replace(/\/+$/, "");
    this.model = model ?? process.env.YMIR_RAIL_MODEL ?? DEFAULT_MODEL;
    this.timeoutMs = timeoutMs;
    // injectable so the test needs no rail at all
    this._fetch = fetchImpl ?? globalThis.fetch;
  }

  /**
   * Is the local brain usable RIGHT NOW? A health probe, never a completion: deciding must not
   * cost a token or a second of latency, or the choice is slower than the thing it chooses.
   */
  async available() {
    try {
      const ctl = AbortSignal.timeout ? AbortSignal.timeout(2500) : undefined;
      const res = await this._fetch(`${this.railUrl}/models`, {
        headers: { authorization: this.#auth() },
        signal: ctl,
      });
      return res.ok;
    } catch {
      return false;   // no rail, no local brain — the router falls back, it does not fail
    }
  }

  #auth() {
    const key = process.env.LLAMA_SWAP_API_KEY ?? process.env.YMIR_RAIL_KEY ?? "";
    return key ? `Bearer ${key}` : "";
  }

  /**
   * Ask the local model. Always resolves with a typed result, exactly like AcpBrain — a rail that is
   * down must be REPORTED, never thrown into the voice loop, where it would become a dead turn.
   */
  async ask(prompt, { timeoutMs, model } = {}) {
    const budget = timeoutMs ?? this.timeoutMs;
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), budget);
    try {
      const res = await this._fetch(`${this.railUrl}/chat/completions`, {
        method: "POST",
        headers: { "content-type": "application/json", authorization: this.#auth() },
        body: JSON.stringify({
          model: model ?? this.model,
          messages: [{ role: "user", content: String(prompt) }],
          // The rail's global sets reasoning = off, and reasoning on burns the whole token budget
          // on reasoning_content and returns an EMPTY summary with HTTP 200 (measured on the box).
          stream: false,
        }),
        signal: ctrl.signal,
      });
      if (!res.ok) {
        return { ok: false, reason: `rail-${res.status}`, detail: (await res.text()).slice(0, 160) };
      }
      const body = await res.json();
      const text = body?.choices?.[0]?.message?.content;
      if (typeof text !== "string" || text.length === 0) {
        // An empty completion with HTTP 200 is a REAL failure mode here, not an edge case.
        return {
          ok: false,
          reason: "empty-completion",
          detail:
            "the rail answered 200 with no content — check reasoning=off in the preset, or the " +
            "model may have spent max_tokens without answering",
        };
      }
      return { ok: true, text };
    } catch (e) {
      const aborted = e?.name === "AbortError";
      return {
        ok: false,
        reason: aborted ? "timeout" : "rail-unreachable",
        detail: aborted ? `no answer in ${budget}ms` : `${this.railUrl} — ${String(e?.message ?? e).split("\n")[0]}`,
      };
    } finally {
      clearTimeout(timer);
    }
  }
}

/**
 * The router. `local | api | auto` — and this is a VOICE-AND-BRAIN choice the Allfather makes per
 * session, not a setting installed once. `auto` prefers local: it is private, free, and survives the
 * network being gone; api is the escape hatch when sub-second turns matter more than either.
 */
export async function pickBrain({ requested = "auto", apiBrain, localBrain } = {}) {
  if (requested === BRAINS.PI) {
    if (localBrain && !(await localBrain.available())) {
      return { brain: null, reason: "local-requested-but-no-rail" };
    }
    return { brain: localBrain, reason: "local requested" };
  }
  if (requested === BRAINS.OPENCODE) return { brain: apiBrain, reason: "hosted requested" };

  if (localBrain && (await localBrain.available())) {
    return { brain: localBrain, reason: "auto: the local rail answered, so local by default" };
  }
  return { brain: apiBrain, reason: "auto: no local rail, falling back to the hosted agent" };
}