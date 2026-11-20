/**
 * context-left — every pi seat can see its own remaining context.
 *
 * THE FAULT THIS CLOSES (measured 2026-11-09): only Rödd, the voice, could ask
 * "how much room is left". Its toolbox had a `context_left` tool; a pi seat — the
 * counsellor, every Eindri, every seat in Sessrúmnir — had nothing, so work ran
 * into the window without warning and died at the ceiling (two errands that night
 * did exactly that: "25 minutes at the context ceiling").
 *
 * ONE COUNTER, NOT TWO. This extension is the source of truth:
 *
 *   * the tool below answers from the harness's own state (`ctx.getContextUsage()`,
 *     `ctx.model.contextWindow`, `ctx.sessionManager.getEntries()`), so it never
 *     invents a window or a token count;
 *   * it PUBLISHES that reading to `<home>/hodd/state/context-left/<session>.json`
 *     on every call and on every turn end, and `bin/voice/voice_tools.py` repeats
 *     the published reading instead of keeping a counter of its own.
 *
 * One writer per file: each session writes only its own file, and a reader picks
 * the newest live one. Nothing here is hardcoded (RULES/07): the window comes from
 * the model catalogue, the reserve from the settings files, the home from the
 * house's own resolver — and every one of them names where it read the number.
 *
 * Contract (RULES/13, pi.dev/docs/latest/extensions): `pi` is taken as `any` because
 * `@earendil-works/pi-coding-agent` is not installed as a package here; the factory
 * starts no process, socket or timer — work begins at a tool call or a turn end.
 */
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

import { resolveYmirRoot } from "../lib/ymir-home.ts";
import { deriveReading, renderReading, type Reading, type Snapshot } from "./reading.ts";

/** Pi's documented default when nothing names a reserve (docs/compaction.md). */
const DEFAULT_RESERVE_TOKENS = 16384;

const isPositive = (v: unknown): v is number =>
  typeof v === "number" && Number.isFinite(v) && v > 0;

// ── the three roots: the tree (bin/), the home (state/), the settings ─────────

/** The operator's home — the house's own resolver, never a restated default. */
function resolveHome(root: string): string {
  const explicit = process.env.YMIR_HOME?.trim();
  if (explicit && existsSync(join(explicit, "hodd"))) return resolve(explicit);
  try {
    const out = execFileSync(
      "bash",
      ["-lc", `. "${join(root, "bin", "vault", "hoard-lib.sh")}" 2>/dev/null; ymir_home_root 2>/dev/null`],
      { encoding: "utf8", timeout: 8000, stdio: ["ignore", "pipe", "ignore"] },
    ).trim();
    const last = out.split(/\r?\n/).filter(Boolean).pop();
    if (last && existsSync(join(last, "hodd"))) return resolve(last);
  } catch {
    /* unresolved — the caller says so instead of guessing a path */
  }
  return "";
}

/**
 * reserveTokens, resolved in pi's own order: the project settings, then the user
 * settings, then the documented default — and the answer says which one answered.
 */
function resolveReserve(cwd: string): { tokens: number; source: string } {
  const candidates = [
    { file: join(cwd, ".pi", "settings.json"), label: "project settings" },
    { file: join(process.env.HOME ?? "", ".pi", "agent", "settings.json"), label: "user settings" },
  ];
  for (const { file, label } of candidates) {
    try {
      if (!existsSync(file)) continue;
      const parsed = JSON.parse(readFileSync(file, "utf8")) as Record<string, unknown>;
      if (isPositive(parsed.reserveTokens)) {
        return { tokens: parsed.reserveTokens as number, source: `${label} (${file})` };
      }
    } catch {
      /* a malformed settings file falls through to the next candidate, and says so below */
    }
  }
  return { tokens: DEFAULT_RESERVE_TOKENS, source: "pi's documented default" };
}

// ── the harness's own facts ───────────────────────────────────────────────────

interface HarnessFacts {
  tokens: number | null;
  contextWindow: number | null;
  model: string;
  session: string;
  /** The transcript pi persists for this session — how a reader (bin/seat/context.sh) matches it. */
  sessionFile: string;
  userTurns: number | null;
  lastTurnTokens: number | null;
}

function gather(ctx: any): HarnessFacts {
  let usage: { tokens?: number | null; contextWindow?: number | null } | undefined;
  try {
    usage = ctx?.getContextUsage?.();
  } catch {
    usage = undefined;
  }

  const contextWindow =
    isPositive(usage?.contextWindow) ? (usage!.contextWindow as number)
      : isPositive(ctx?.model?.contextWindow) ? (ctx.model.contextWindow as number)
        : null;
  const model = String(ctx?.model?.id ?? ctx?.model?.modelId ?? ctx?.model?.name ?? "");

  let session = "";
  let sessionFile = "";
  try {
    session = String(ctx?.sessionManager?.getSessionId?.() ?? "");
    sessionFile = String(ctx?.sessionManager?.getSessionFile?.() ?? "");
  } catch {
    session = "";
    sessionFile = "";
  }

  let userTurns: number | null = null;
  let lastTurnTokens: number | null = null;
  try {
    const entries = ctx?.sessionManager?.getEntries?.() as
      | Array<{ type?: string; message?: { role?: string; usage?: { input?: number } } }>
      | undefined;
    if (Array.isArray(entries)) {
      let turns = 0;
      for (let i = entries.length - 1; i >= 0; i -= 1) {
        const entry = entries[i];
        if (entry?.type !== "message") continue;
        const message = entry.message;
        if (message?.role === "user") turns += 1;
        if (lastTurnTokens === null && message?.role === "assistant") {
          const input = message.usage?.input;
          if (isPositive(input)) lastTurnTokens = input;
        }
      }
      userTurns = turns;
    }
  } catch {
    userTurns = null;
  }

  return {
    tokens: typeof usage?.tokens === "number" ? usage.tokens : null,
    contextWindow,
    model,
    session,
    sessionFile,
    userTurns,
    lastTurnTokens,
  };
}

// ── the publication: one file per session, one writer each ───────────────────

/** A session id is a filename — keep it to characters a filename may hold. */
function sessionSlug(session: string): string {
  const slug = String(session || "unknown").replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 120);
  return slug || "unknown";
}

function publish(home: string, reading: Reading, extra: Record<string, unknown>): string {
  if (!home) return "";
  const dir = join(home, "hodd", "state", "context-left");
  const file = join(dir, `${sessionSlug(reading.session ?? "")}.json`);
  try {
    mkdirSync(dir, { recursive: true });
    const record = {
      version: 1,
      published_by: ".pi/extensions/context-left",
      pid: process.pid,
      session_file: extra.sessionFile ?? "",
      ...extra,
      ...reading,
      rendered: renderReading(reading),
    };
    writeFileSync(file, `${JSON.stringify(record, null, 2)}\n`, "utf8");
    return file;
  } catch {
    return ""; // the reading is still true; only its publication failed
  }
}

export default function contextLeft(pi: ExtensionAPI) {
  const extensionDir = dirname(fileURLToPath(import.meta.url));
  // The shared resolver: the deploy-time `.ymir-root` record, then a walk up (RULES/12).
  const root = resolveYmirRoot(extensionDir);

  function takeReading(ctx: any): { reading: Reading; snapshot: Snapshot; file: string } {
    const home = resolveHome(root);
    const facts = gather(ctx);
    const cwd = String(ctx?.cwd ?? process.cwd());
    const reserve = resolveReserve(cwd);
    const snapshot: Snapshot = {
      tokens: facts.tokens,
      contextWindow: facts.contextWindow,
      reserveTokens: reserve.tokens,
      reserveSource: reserve.source,
      userTurns: facts.userTurns,
      lastTurnTokens: facts.lastTurnTokens,
      model: facts.model,
      session: facts.session,
      cwd,
      at: new Date().toISOString(),
    };
    const reading = deriveReading(snapshot);
    const file = publish(home, reading, {
      cwd,
      root,
      home: home || null,
      sessionFile: facts.sessionFile,
    });
    return { reading, snapshot, file };
  }

  pi.registerTool({
    name: "context_left",
    label: "Context left",
    description:
      "How much conversation this session is carrying: the tokens of the last turn, the window the " +
      "model holds, and how many turns until the engine compacts. Ask before a long task, or when a " +
      "report is growing, so you summarise early instead of being cut off. It refuses, naming why, " +
      "when the harness reports no measured context or the model declares no window.",
    parameters: { type: "object", properties: {}, additionalProperties: false },
    execute: async (_toolCallId: string, _params: any, _signal: any, _onUpdate: any, ctx: any) => {
      const { reading, file } = takeReading(ctx);
      const where = file
        ? `\npublished: ${file} (the voice repeats this reading; it keeps no counter of its own)`
        : `\nnot published: the home is unresolved, so <home>/hodd/state/context-left/ could not be written`;
      return { content: [{ type: "text", text: `${renderReading(reading)}${where}` }], details: undefined };
    },
  });

  // Fresh without being asked: a reader (the voice) must never repeat a reading
  // from three turns ago. Cheap — a local read of state the harness already holds.
  pi.on("turn_end", async (_event: any, ctx: any) => {
    try {
      takeReading(ctx);
    } catch {
      /* a reading that cannot be published must never break a turn */
    }
    return undefined;
  });
}

/** Exported for the test: the same arithmetic, without a harness. */
export { deriveReading, renderReading };
export type { Reading, Snapshot };
