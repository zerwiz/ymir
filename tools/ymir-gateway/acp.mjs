/**
 * acp.mjs — the bridge to the agent Brokk already runs.
 *
 * Plan 68, P1. The Allfather: *"can't we use the API for open code that we are using?"*
 * and then, pointedly: *"there are some open source things that we can download from GitHub to do
 * this."*
 *
 * HE WAS RIGHT, AND I WAS ABOUT TO REBUILD IT.
 *
 * I wrote this file first — a hand-rolled JSON-RPC framing layer over `opencode acp` stdio — and
 * only then checked whether the thing already existed. It does:
 *
 *   @agentclientprotocol/sdk   1.7.0   Apache-2.0   Zed Industries — the OFFICIAL ACP SDK
 *   @livekit/agents            1.9.1   Apache-2.0   self-hostable WebRTC session layer
 *
 * ACP (Agent Client Protocol) is a published standard, not a private detail of opencode. So the
 * house law (open-source-first: adopt a validated project before any custom build) is not a
 * preference here — rebuilding the framing is exactly the thing it forbids, and it would have made
 * us *worse* than the standard: no typed methods, no spec compliance, no interop with any other
 * ACP client that appears later.
 *
 * WHAT IS OURS, AND WHY IT IS NOT THE SDK'S JOB:
 *   · session identity across devices (session.mjs)      — Ymir-specific, nobody else has this
 *   · the brain seam (this file)                           — so voice never learns hosted vs local
 *   · the tailnet-only reach and the doors' MCP surface    — the house's own
 *
 * WHAT WE ADOPT:
 *   · ACP framing + session/prompt                         — @agentclientprotocol/sdk
 *   · WebRTC sessions, VAD, turn detection, barge-in       — @livekit/agents (self-hosted)
 *   · the local voice loop reference                       — plan 34's design, vui (Apache-2.0)
 */

import { BRAINS } from "./session.mjs";

/**
 * The one interface the voice layer sees. Two implementations, no more: hosted ACP and local pi.
 * The voice layer must never branch on which brain it has.
 */
export class Brain {
  constructor(name) {
    this.name = name;
    if (!Object.values(BRAINS).includes(name)) {
      throw new Error(`unknown brain: ${name} (the house allows ${Object.values(BRAINS).join(", ")})`);
    }
  }

  /**
   * Ask the agent something.
   * @returns {Promise<{ok: true, text: string} | {ok: false, reason: string, detail: string}>}
   * Always resolves. A dead agent is a typed RESULT — never a rejection, never a silence. A
   * transport that hangs is worse than one that reports, and the phone must be able to say so.
   */
  async ask() {
    throw new Error("not implemented");
  }

  async down() {
    return { ok: true, detail: "not running" };
  }
}

/**
 * The hosted brain: the SAME agent runtime Brokk runs, over ACP.
 *
 * The framing, the method names and the session lifecycle belong to @agentclientprotocol/sdk —
 * this class only adapts that SDK's shape onto ours, and adds the two things the SDK cannot know:
 * a timeout that produces a typed result, and the local/hosted seam.
 */
export class AcpBrain extends Brain {
  constructor({ cwd, env, timeoutMs = 120_000, sdk } = {}) {
    super(BRAINS.OPENCODE);
    this.cwd = cwd;
    this.env = env;
    this.timeoutMs = timeoutMs;
    this.session = null;      // the SDK ActiveSession, once `up()` succeeds
    this._sdk = sdk;         // injectable, so a test needs no network and no agent
  }

  /** Load the official SDK lazily, so importing this file never requires the dependency. */
  async #load() {
    if (this._sdk) return this._sdk;
    try {
      this._sdk = await import("@agentclientprotocol/sdk");
    } catch (e) {
      return { error: `the ACP SDK is not installed: ${String(e?.message ?? e).split("\n")[0]}\n  npm i @agentclientprotocol/sdk` };
    }
    return this._sdk;
  }

  async up() {
    if (this.session) return { ok: true, detail: "already connected" };
    const sdk = await this.#load();
    if (sdk.error) return { ok: false, reason: "sdk-missing", detail: sdk.error };

    // The doors go in as STANDARD MCP. The SDK's SessionBuilder has `withMcpServer(...)`, so the
    // agent is handed the house's own MCP servers the same way any other client would — no
    // custom tool bridge, no duplicated door, and the one-capability-one-door law holds because
    // the doors are referenced, never reimplemented.
    const mcpServers = (process.env.YMIR_MCP_SERVERS ?? "")
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean)
      .map((name) => ({ name, command: process.env.YMIR_MCP_CMD ?? "ymir-mcp", args: [name] }));

    try {
      const builder = new sdk.SessionBuilder()
        .withAgentCapabilities({ loadSession: false });
      for (const server of mcpServers) builder.withMcpServer(server);
      this.session = await builder.start();
      return { ok: true, detail: `acp session up · ${mcpServers.length} MCP server(s)` };
    } catch (e) {
      this.session = null;
      return { ok: false, reason: "session-failed", detail: String(e?.message ?? e).split("\n")[0] };
    }
  }

  async ask(prompt, { timeoutMs } = {}) {
    if (!this.connection) {
      const up = await this.up();
      if (!up.ok) return up;
    }
    const budget = timeoutMs ?? this.timeoutMs;
    let timer;
    const expiry = new Promise((resolve) => {
      timer = setTimeout(() => resolve({ __timeout: true }), budget);
    });
    try {
      const answer = await Promise.race([this.#prompt(prompt), expiry]);
      clearTimeout(timer);
      if (answer?.__timeout) {
        return { ok: false, reason: "timeout", detail: `no answer in ${budget}ms` };
      }
      if (answer?.error) {
        return { ok: false, reason: "agent-error", detail: String(answer.error.message ?? answer.error) };
      }
      return { ok: true, text: String(answer?.text ?? answer?.content ?? "") };
    } catch (e) {
      clearTimeout(timer);
      return { ok: false, reason: "transport-failed", detail: String(e?.message ?? e).split("\n")[0] };
    }
  }

  async #prompt(prompt) {
    // CONFIRMED against the installed 1.7.0 surface (tools/ymir-gateway/README.md):
    //   SessionBuilder.toRequest() · withMcpServer(mcpServer) · withAdditionalDirectories(…)
    //   start(): Promise<ActiveSession>
    //   ActiveSession.prompt(prompt) · nextUpdate() · readText() · dispose()
    const session = this.session;
    if (!session) return { error: { message: "no active session" } };
    await session.prompt(prompt);          // streaming updates arrive via nextUpdate()
    return { text: session.readText() };   // the SDK assembles the reply for us
  }

  async down() {
    try { await this.session?.dispose?.(); } catch { /* already gone: that is the state we wanted */ }
    this.session = null;
    return { ok: true, detail: "session disposed" };
  }
}