/**
 * session.mjs — the ONE thing that must be right first: session identity.
 *
 * Plan 68, phase P1. The Allfather: *"yes, the phone can do the same as Brokk can do."*
 *
 * Why identity comes before voice, before reach, before tools: a conversation started on the
 * phone must be resumable on the computer and the tools it used must belong to ONE session.
 * Retrofitting that after the voice loop exists is the expensive way round — the seam has to be
 * in place while there is nothing yet to be sorry about.
 *
 * TWO BRAINS, ONE SEAM. The house already decides which is which (AGENTS.md: local → pi, hosted →
 * opencode), so this does not invent a third path:
 *
 *   opencode  → ACP (Agent Client Protocol) over stdio — the standard agent-as-server protocol,
 *               verified present on this box (`opencode acp`, `opencode attach <url>`)
 *   pi        → the local rail at 127.0.0.1:8080, driven the way pi itself is driven
 *
 * A phone session never picks a model. It picks a BRAIN, and the brain picks the model from the
 * agent config — exactly as it does on the computer. "Use local models" is therefore a routing
 * decision, not a second implementation.
 */

import { randomUUID, createHash } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

/** The two brains the house allows. Anything else is a mistake, not an extension point. */
export const BRAINS = Object.freeze({
  OPENCODE: "opencode", // hosted · ACP · the runtime Brokk already runs
  PI: "pi",             // local  · the llama rail
});

/** A session id is stable across devices but not guessable: the phone and the computer must meet
 *  the same conversation, and nobody else may join it. */
export function newSessionId(device = "unknown") {
  const raw = `${device}:${randomUUID()}`;
  const h = createHash("sha256").update(raw).digest("hex");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}`;
}

/**
 * SessionIdentity — the record that makes "the same conversation" checkable.
 *
 * `resumeToken` is a bearer secret: possessing it is what lets a device rejoin. It is never
 * derived from the session id, so knowing one does not grant the other.
 */
export class SessionIdentity {
  constructor({ sessionId, brain, device, createdAt, resumeToken } = {}) {
    this.sessionId = sessionId ?? newSessionId(device);
    this.brain = Object.values(BRAINS).includes(brain) ? brain : BRAINS.OPENCODE;
    this.device = device ?? "unknown";
    this.createdAt = createdAt ?? new Date().toISOString();
    this.resumeToken = resumeToken ?? randomUUID();
  }

  /** Enrol another device into the SAME conversation. That is what "the phone and the computer
   *  are the same Brokk" means in code. */
  enrol(device) {
    this.device = `${this.device}+${device}`;
    return this;
  }

  /** Answer whether a token may rejoin. Constant-time compare: a timing side channel on a
   *  bearer token is a real, if slow, attack. */
  mayResume(token) {
    if (typeof token !== "string" || token.length !== this.resumeToken.length) return false;
    let diff = 0;
    for (let i = 0; i < token.length; i += 1) {
      diff |= token.charCodeAt(i) ^ this.resumeToken.charCodeAt(i);
    }
    return diff === 0;
  }

  toJSON() {
    return {
      sessionId: this.sessionId,
      brain: this.brain,
      device: this.device,
      createdAt: this.createdAt,
      // the token is NOT part of the serialised record — it is returned once, at issue
    };
  }
}

/**
 * SessionStore — survives a phone going to sleep, a screen locking, or the gateway restarting.
 * Without persistence, "continue where we left off" is impossible and every turn is a new Brokk.
 */
export class SessionStore {
  constructor(dir) {
    this.dir = dir;
    mkdirSync(dir, { recursive: true });
  }

  #path(id) {
    return join(this.dir, `${id}.json`);
  }

  save(identity, token) {
    const record = identity.toJSON();
    record.resumeTokenHash = createHash("sha256").update(token).digest("hex");
    writeFileSync(this.#path(identity.sessionId), `${JSON.stringify(record, null, 2)}\n`, { mode: 0o600 });
    return record;
  }

  load(sessionId) {
    const p = this.#path(sessionId);
    if (!existsSync(p)) return null;
    try {
      return JSON.parse(readFileSync(p, "utf8"));
    } catch {
      return null; // a truncated record is not a session; never half-restore one
    }
  }

  /** Rejoin a conversation from another device with its token. */
  resume(sessionId, token) {
    const rec = this.load(sessionId);
    if (!rec) return null;
    const given = createHash("sha256").update(String(token ?? "")).digest("hex");
    return given === rec.resumeTokenHash ? rec : null;
  }
}

/**
 * Brain selection — "use local models" is a ROUTING decision, not a second implementation.
 *
 * `auto` prefers LOCAL when a rail answers, because local is private and free, and falls back to
 * the hosted ACP runtime when it does not. The probe is a health check, not a model call: it must
 * not cost a token or a second to decide.
 */
export function chooseBrain({ requested = "auto", railUrl } = {}) {
  if (requested === BRAINS.PI) return BRAINS.PI;
  if (requested === BRAINS.OPENCODE) return BRAINS.OPENCODE;
  return railUrl ? BRAINS.PI : BRAINS.OPENCODE;
}