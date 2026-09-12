/**
 * smidja visualizer server — JSON API over a target repo's smidja.db, plus the
 * built UI when ./dist exists. Reads are read-only; the single write is
 * POST /api/sessions/:smidja_id/archive, which sets one review flag on a row.
 *
 * There is no ingest endpoint and no websocket. The data path is
 * agents → sqlite → web ui, and the UI gets there by polling.
 *
 *   bun run server/index.ts
 *   bun run server/index.ts --db /path/to/repo/smidja/smidja_data/smidja.db
 *   CMD_DB=/path/to/smidja.db PORT=8437 bun run server/index.ts
 */
import { existsSync, readdirSync, statSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";
import { smidjaDb, resolveDbPath } from "./db.ts";
import type { AgentPrompts, ApiError, HealthResponse } from "../shared/types.ts";
import * as rosterApi from "./roster-api.ts";
import * as chat from "./chat.ts";
import * as settingsApi from "./settings.ts";
import { isPiResolvable, piModels } from "./model-catalog.ts";

const PORT = Number(process.env.PORT ?? 8437);
const DIST_DIR = resolve(import.meta.dir, "..", "dist");

/** Kaia's engram memory bridge (Python, see scripts/kaia-memory-bridge.py). */
const MEMORY_BRIDGE = process.env.KAIA_MEMORY_URL ?? "http://127.0.0.1:4602";

const dbPath = resolveDbPath();

/** <repoRoot>/smidja/smidja_data/smidja.db — three dirnames up is the repo root. */
const repoRoot = resolve(dirname(dirname(dirname(dbPath))));
let db: smidjaDb;
try {
  db = new smidjaDb(dbPath);
} catch (error) {
  console.error(`[smidja] ${(error as Error).message}`);
  process.exit(1);
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function notFound(message: string): Response {
  return json({ error: message } satisfies ApiError, 404);
}

/** Guard every handler so a malformed query can't take the server down mid-run. */
function safely(
  handler: (req: Request) => Response | Promise<Response>,
): (req: Request) => Promise<Response> {
  return async (req) => {
    try {
      return await handler(req);
    } catch (error) {
      console.error(`[smidja] ${req.method} ${new URL(req.url).pathname}:`, error);
      return json({ error: (error as Error).message } satisfies ApiError, 500);
    }
  };
}

/**
 * smidja_ids and agent names are path segments on disk, so anything that isn't a
 * plain identifier is rejected outright rather than sanitized into something
 * that might still escape the sessions directory.
 */
const SAFE_SEGMENT = /^[A-Za-z0-9._-]+$/;

function isSafeSegment(value: string): boolean {
  return SAFE_SEGMENT.test(value) && value !== "." && value !== "..";
}

function param(req: Request, key: string): string {
  return decodeURIComponent(
    (req as Request & { params: Record<string, string> }).params[key] ?? "",
  );
}

function intQuery(req: Request, key: string, fallback: number): number {
  const raw = new URL(req.url).searchParams.get(key);
  if (raw === null || raw.trim() === "") return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/**
 * Proxy one Kaia memory request to the engram bridge, collapsing the result
 * into our JSON envelope. A bridge that is down is reported as 503 rather than
 * a crash, so the UI can show "memory offline" instead of a dead page.
 */
async function memoryProxy(req: Request, path: string): Promise<Response> {
  const target = new URL(path, MEMORY_BRIDGE.endsWith("/") ? MEMORY_BRIDGE : `${MEMORY_BRIDGE}/`);
  target.search = new URL(req.url).search;
  const upstream = await fetch(target, {
    method: req.method,
    headers: { "content-type": "application/json" },
    body: req.method === "POST" ? await req.text() : undefined,
  });
  const raw = await upstream.text();
  return new Response(raw, {
    status: upstream.status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

/** Serve the built SPA if it has been built; otherwise point at the dev server. */
async function serveStatic(req: Request): Promise<Response> {
  const { pathname } = new URL(req.url);

  if (!existsSync(DIST_DIR)) {
    return new Response(
      `smidja visualizer API is running on :${PORT}.\n\n` +
        `No ./dist build found. Run "bun run dev" for the Vite dev server ` +
        `(it proxies /api here), or "bun run build" to serve the UI from this process.\n`,
      { status: 200, headers: { "content-type": "text/plain; charset=utf-8" } },
    );
  }

  // Reject traversal before touching the filesystem.
  const candidate = resolve(join(DIST_DIR, pathname));
  if (candidate === DIST_DIR || candidate.startsWith(DIST_DIR + "/")) {
    if (existsSync(candidate) && statSync(candidate).isFile()) {
      return new Response(Bun.file(candidate));
    }
  }

  // SPA fallback: breadcrumb routes are client-side.
  const indexHtml = join(DIST_DIR, "index.html");
  if (existsSync(indexHtml)) {
    return new Response(Bun.file(indexHtml), {
      headers: { "content-type": "text/html; charset=utf-8" },
    });
  }
  return notFound("not found");
}

const server = Bun.serve({
  port: PORT,
  routes: {
    "/api/health": safely(
      (req) =>
        json({
          ok: true,
          db: db.path,
          journal_mode: db.journalMode,
          // ?scope=all → include every run (archived + plumbing one-shots) so
          // the count agrees with the all-inclusive sessions list. Additive.
          sessions: db.sessionCount(new URL(req.url).searchParams.get("scope") === "all"),
        } satisfies HealthResponse),
    ),

    "/api/sessions": safely((req) => {
      // A run that died without finalizing its own session (killed from old
      // code, crashed, SIGKILL) would otherwise stay "running" and keep
      // offering Stop/Pause. Reconcile stale running rows against live pids
      // before serving, so the L1 list shows the truth.
      db.reconcileStaleRunning();
      // DEFAULT = all-inclusive (the OLD behavior: every run listed). The
      // additive ?scope=cleaned escapes to the current cleaned list
      // (archived + Kaia plumbing one-shots hidden). Nothing old is lost.
      const scope = new URL(req.url).searchParams.get("scope");
      const includeAll = scope !== "cleaned";
      return json(db.sessions(intQuery(req, "limit", 200), includeAll));
    }),

    // The self-improving surface: failures grouped by diagnosis + model, with
    // the fix to apply. What to change to make the system work.
    "/api/decisions": safely(() => json(db.decisions())),

    // Statistics: runs, tokens, cost, cache-hit ratio, commercial savings.
    "/api/stats": safely(() => json(db.stats())),

    "/api/sessions/:smidja_id": safely((req) => {
      db.reconcileStaleRunning();
      const detail = db.sessionDetail(param(req, "smidja_id"));
      return detail ? json(detail) : notFound(`no session ${param(req, "smidja_id")}`);
    }),

    // The one write. Archiving is review triage — it belongs to the reader, not
    // to the run — so it never touches anything a tracer wrote.
    "/api/sessions/:smidja_id/archive": {
      POST: safely(async (req) => {
        const adwId = param(req, "smidja_id");
        if (!isSafeSegment(adwId)) {
          return json({ error: "invalid smidja_id" } satisfies ApiError, 400);
        }
        const body = (await req.json().catch(() => ({}))) as { archived?: unknown };
        const archived = body.archived === undefined ? true : Boolean(body.archived);
        return db.setArchived(adwId, archived)
          ? json({ smidja_id: adwId, archived })
          : notFound(`no session ${adwId}`);
      }),
    },

    // The Stop button. Signals the run's live processes children-first so the
    // smidja's SIGTERM handler can finalize the trace as fail (session.py). Then,
    // whatever the outcome of the signal, it reconciles the db server-side so
    // a Stop always leaves the run closed: a pid may be gone before the signal
    // (stale row), or the smidja may be running code with no finalizer (crashed,
    // SIGKILL, or predating the handler). `finalizeStopped` is idempotent, so
    // it is safe to call even when the smidja already settled the run itself.
    "/api/sessions/:smidja_id/stop": {
      POST: safely(async (req) => {
        const adwId = param(req, "smidja_id");
        if (!isSafeSegment(adwId)) {
          return json({ error: "invalid smidja_id" } satisfies ApiError, 400);
        }
        if (!db.session(adwId)) return notFound(`no session ${adwId}`);
        const procs = db.liveProcesses(adwId); // only pids still alive
        // children first, then the smidja itself
        const order = [...procs.filter((p) => p.kind === "agent"), ...procs.filter((p) => p.kind === "smidja")];
        let stopped = 0;
        for (const p of order) {
          try {
            process.kill(p.pid, "SIGTERM");
            stopped += 1;
          } catch {
            // gone between the liveness probe and the signal
          }
        }
        // The smidja's own finalizer runs on SIGTERM a moment later; if it does
        // not (or already ran and the row is still open), close it from here.
        db.finalizeStopped(adwId);
        return json({
          smidja_id: adwId,
          stopped,
          finalized: !db.liveProcesses(adwId).length,
          pids: order.map((p) => p.pid),
        });
      }),
    },

    // Pause / resume — SIGSTOP / SIGCONT the live agent children so the run
    // can be held mid-flight while the engineer steers, then continued.
    // Only genuinely-live pids are signalled and only successes are counted.
    "/api/sessions/:smidja_id/pause": {
      POST: safely(async (req) => {
        const adwId = param(req, "smidja_id");
        if (!isSafeSegment(adwId)) return json({ error: "invalid smidja_id" } satisfies ApiError, 400);
        const procs = db.liveProcesses(adwId).filter((p) => p.kind === "agent");
        let signalled = 0;
        for (const p of procs) {
          try { process.kill(p.pid, "SIGSTOP"); signalled += 1; } catch { /* gone */ }
        }
        return json({ smidja_id: adwId, paused: signalled, pids: procs.map((p) => p.pid) });
      }),
    },
    "/api/sessions/:smidja_id/resume": {
      POST: safely(async (req) => {
        const adwId = param(req, "smidja_id");
        if (!isSafeSegment(adwId)) return json({ error: "invalid smidja_id" } satisfies ApiError, 400);
        const procs = db.liveProcesses(adwId).filter((p) => p.kind === "agent");
        let signalled = 0;
        for (const p of procs) {
          try { process.kill(p.pid, "SIGCONT"); signalled += 1; } catch { /* gone */ }
        }
        return json({ smidja_id: adwId, resumed: signalled, pids: procs.map((p) => p.pid) });
      }),
    },

    // Engineer steering: inject a message into a running (or paused) run.
    // The message is appended to the session's steer file; the smidja's next
    // agent call (or resume) reads it as standing guidance. Pause first for
    // the message to apply before the current agent's next turn.
    "/api/sessions/:smidja_id/steer": {
      POST: safely(async (req) => {
        const adwId = param(req, "smidja_id");
        if (!isSafeSegment(adwId)) return json({ error: "invalid smidja_id" } satisfies ApiError, 400);
        if (!db.session(adwId)) return notFound(`no session ${adwId}`);
        const body = (await req.json().catch(() => ({}))) as { message?: unknown };
        const message = typeof body.message === "string" ? body.message.trim() : "";
        if (!message) return json({ error: "steer needs a message" } satisfies ApiError, 400);

        const steerFile = join(db.sessionsDir, adwId, "steer.md");
        const stamp = new Date().toISOString();
        const append = `${stamp}\n\n${message}\n\n`;
        if (!existsSync(join(db.sessionsDir, adwId))) {
          await Bun.$`mkdir -p ${join(db.sessionsDir, adwId)}`;
        }
        if (existsSync(steerFile)) {
          await Bun.file(steerFile).write((await Bun.file(steerFile).text()) + append);
        } else {
          await Bun.file(steerFile).write(`# Engineer steering\n\n${append}`);
        }
        return json({ smidja_id: adwId, ok: true, note: "steer written — applies on the run's next agent call" });
      }),
    },

    "/api/sessions/:smidja_id/events": safely((req) =>
      json(
        db.events(
          param(req, "smidja_id"),
          intQuery(req, "after", 0),
          intQuery(req, "limit", 500),
        ),
      ),
    ),

    "/api/sessions/:smidja_id/envelopes": safely((req) =>
      json(db.envelopes(param(req, "smidja_id"))),
    ),

    "/api/sessions/:smidja_id/gates": safely((req) => json(db.gates(param(req, "smidja_id")))),

    // The exact prompts an agent was sent, read from the session dir. Files are
    // the raw record; the db has no copy of them.
    "/api/sessions/:smidja_id/agents/:agent/prompts": safely(async (req) => {
      const adwId = param(req, "smidja_id");
      const agent = param(req, "agent");
      if (!isSafeSegment(adwId) || !isSafeSegment(agent)) {
        return json({ error: "invalid smidja_id or agent" } satisfies ApiError, 400);
      }
      if (!db.session(adwId)) return notFound(`no session ${adwId}`);

      const dir = resolve(db.sessionsDir, adwId, agent, "prompts");
      // Defense in depth: the segment check already forbids traversal.
      if (dir !== db.sessionsDir && !dir.startsWith(db.sessionsDir + sep)) {
        return json({ error: "invalid path" } satisfies ApiError, 400);
      }

      // A prompt file is absent whenever the agent never ran in this session —
      // a normal state, so it reads as null rather than an error.
      const read = async (name: string): Promise<string | null> => {
        const file = Bun.file(join(dir, `${name}.md`));
        return (await file.exists()) ? await file.text() : null;
      };
      return json({
        system: await read("system"),
        user: await read("user"),
      } satisfies AgentPrompts);
    }),

    // The model's thinking/reasoning for an agent's phase, read from the raw
    // streams — the db only stores token counts, not text. Both coding agents
    // are covered: pi (`pi_sessions/*.jsonl` thinking blocks) and opencode
    // (`raw_output.jsonl` reasoning parts when the stream carries them).
    "/api/sessions/:smidja_id/agents/:agent/thinking": safely(async (req) => {
      const adwId = param(req, "smidja_id");
      const agent = param(req, "agent");
      if (!isSafeSegment(adwId) || !isSafeSegment(agent)) {
        return json({ error: "invalid smidja_id or agent" } satisfies ApiError, 400);
      }
      if (!db.session(adwId)) return notFound(`no session ${adwId}`);

      const agentDir = resolve(db.sessionsDir, adwId, agent);
      if (agentDir !== db.sessionsDir && !agentDir.startsWith(db.sessionsDir + sep)) {
        return json({ error: "invalid path" } satisfies ApiError, 400);
      }

      const blocks: string[] = [];
      const scanJsonl = async (dir: string) => {
        if (!existsSync(dir)) return;
        // pi `--mode json` streams thinking as message_update deltas inside
        // raw_output.jsonl — accumulate per contentIndex between start/end.
        const thinking = new Map<number, string>();
        const thinkingOn = new Map<number, boolean>();
        for (const name of readdirSync(dir)) {
          if (!name.endsWith(".jsonl")) continue;
          const file = Bun.file(join(dir, name));
          const text = await file.text();
          for (const line of text.split("\n")) {
            if (!line.trim()) continue;
            try {
              const ev = JSON.parse(line);
              // pi: assistant messages carry content[].thinking blocks
              if (ev.type === "message") {
                for (const c of ev.message?.content ?? []) {
                  if ((c.type === "thinking" || c.type === "reasoning")
                      && typeof (c.thinking ?? c.text) === "string") {
                    const t = String(c.thinking ?? c.text).trim();
                    if (t) blocks.push(t);
                  }
                }
                continue;
              }
              // pi (current): message_update / assistantMessageEvent deltas
              const ame = ev.assistantMessageEvent;
              const ci = ame?.contentIndex ?? 0;
              if (ev.type === "message_update" && ame && typeof ame.type === "string") {
                if (ame.type === "thinking_start") {
                  thinkingOn.set(ci, true);
                  thinking.set(ci, "");
                  continue;
                }
                if (ame.type === "thinking_delta" && typeof ame.delta === "string") {
                  if (thinkingOn.get(ci)) thinking.set(ci, (thinking.get(ci) ?? "") + ame.delta);
                  continue;
                }
                if (ame.type === "thinking_end") {
                  thinkingOn.set(ci, false);
                  const t = (thinking.get(ci) ?? "").trim();
                  if (t) blocks.push(t);
                  continue;
                }
                continue;
              }
              if (ev.type === "message_start" && ev.message?.role === "assistant") {
                thinking.clear();
                thinkingOn.clear();
                continue;
              }
              // opencode: reasoning parts / reasoning text when present
              const part = ev.part ?? {};
              if (part.type === "reasoning" && typeof part.text === "string") {
                const t = part.text.trim();
                if (t) blocks.push(t);
              } else if (typeof ev.reasoning === "string" && ev.reasoning.trim()) {
                blocks.push(ev.reasoning.trim());
              }
            } catch {
              /* malformed line — skip */
            }
          }
        }
      };

      await scanJsonl(join(agentDir, "pi_sessions"));
      await scanJsonl(agentDir); // raw_output.jsonl for opencode

      // Loss D additive fallback: a task-dispatched sub-agent runs in its OWN
      // opencode session (ses_...) whose stream is not on the trace disk, so
      // the raw-scan above finds nothing. We DO capture its final report as
      // output.txt (P1). Surface that as the lane's "thinking/result" so a
      // sub-agent that produced real work never shows an empty shell. Label it
      // clearly as the result, not fabricated chain-of-thought.
      if (blocks.length === 0) {
        const outFile = join(agentDir, "output.txt");
        if (existsSync(outFile)) {
          const t = (await Bun.file(outFile).text()).trim();
          if (t) blocks.push(t);
        }
      }
      return json({ smidja_id: adwId, agent, thinking: blocks });
    }),

    // ── Local settings (WayOfTeams MCP keys, stored in repo .env) ────────
    "/api/settings": safely(async () =>
      json(settingsApi.listSettings(repoRoot)),
    ),
    "/api/settings/save": {
      POST: safely(async (req) => {
        const body = (await req.json().catch(() => ({}))) as { key?: string; value?: string };
        if (!body.key || body.value === undefined) {
          return json({ error: "settings save needs key and value" } satisfies ApiError, 400);
        }
        try {
          return json(settingsApi.saveSetting(repoRoot, body.key, body.value));
        } catch (error) {
          return json({ error: (error as Error).message } satisfies ApiError, 400);
        }
      }),
    },

    // ── Orchestrator chat: picker + conversation + session launch ─────────
    "/api/rosters": safely(async () => json(await rosterApi.rosters(dbPath))),
    "/api/models": safely(async () => {
      const rosterModels = await rosterApi.models(dbPath);
      const catalog = await piModels(repoRoot);
      return json(
        rosterModels.map((m: { id: string }) => ({ ...m, available: isPiResolvable(m.id, catalog) })),
      );
    }),
    "/api/rosters/:name": safely(async (req) => {
      const name = param(req, "name");
      return json(await rosterApi.roster(dbPath, name));
    }),
    "/api/chat/history": safely(async (req) => {
      const sessionId = new URL(req.url).searchParams.get("session") ?? "default";
      return json(await chat.history(dbPath, sessionId));
    }),
    "/api/chat/sessions": safely(async () => json(await chat.listSessions(dbPath))),
    "/api/chat/debug/sessions": safely(async () => json(await chat.debugSessions(dbPath))),
    "/api/chat/models": safely(async () => json(await chat.piModels(repoRoot))),
    "/api/chat/message": {
      POST: safely(async (req) => {
        const body = (await req.json().catch(() => ({}))) as {
          sessionId?: string;
          content?: string;
          model?: string;
        };
        return json(
          await chat.sendMessage(
            { sessionId: body.sessionId ?? "default", content: body.content ?? "", model: body.model },
            dbPath,
          ),
        );
      }),
    },
    "/api/chat/session": {
      POST: safely(async (req) => {
        const body = (await req.json().catch(() => ({}))) as {
          roster?: string;
          orchestratorModel?: string;
          task?: string;
        };
        return json(
          await chat.startSession(
            {
              roster: body.roster ?? "",
              orchestratorModel: body.orchestratorModel,
              task: body.task ?? "",
            },
            dbPath,
          ),
        );
      }),
      DELETE: safely(async (req) => {
        const url = new URL(req.url);
        const sessionId = url.searchParams.get("session") ?? "default";
        return json(await chat.deleteSession(dbPath, sessionId));
      }),
    },
    "/api/chat/steer": {
      POST: safely(async (req) => {
        const body = (await req.json().catch(() => ({}))) as { adwId?: string; message?: string };
        if (!body.adwId || !body.message) {
          return json({ error: "steer needs adwId and message" } satisfies ApiError, 400);
        }
        return json(await chat.steer(dbPath, body.adwId, body.message));
      }),
    },

    // ── Kaia's memory (engram) — proxied to the Python bridge ──────────────
    "/api/memory/health": safely(async (req) => {
      try {
        return await memoryProxy(req, "/health");
      } catch {
        return json({ ok: false, db: null, error: "kaia memory bridge unreachable" }, 503);
      }
    }),
    "/api/memory/inspect": safely(async (req) => {
      try {
        return await memoryProxy(req, "/inspect");
      } catch {
        return json({ error: "kaia memory bridge unreachable" } satisfies ApiError, 503);
      }
    }),
    "/api/memory/recall": safely(async (req) => {
      try {
        return await memoryProxy(req, "/recall");
      } catch {
        return json({ error: "kaia memory bridge unreachable" } satisfies ApiError, 503);
      }
    }),
    "/api/memory/timeline": safely(async (req) => {
      try {
        return await memoryProxy(req, "/timeline");
      } catch {
        return json({ error: "kaia memory bridge unreachable" } satisfies ApiError, 503);
      }
    }),
    "/api/memory/observe": {
      POST: safely(async (req) => {
        try {
          return await memoryProxy(req, "/observe");
        } catch {
          return json({ error: "kaia memory bridge unreachable" } satisfies ApiError, 503);
        }
      }),
    },
  },

  fetch(req) {
    const { pathname } = new URL(req.url);
    if (pathname.startsWith("/api/")) return notFound(`no route ${pathname}`);
    return serveStatic(req);
  },
});

console.log(`[smidja] visualizer api  http://localhost:${server.port}`);
console.log(`[smidja] db              ${db.path}  [journal_mode=${db.journalMode}]`);
const reconciled = db.reconcileStaleRunning();
if (reconciled > 0) console.log(`[smidja] reconciled ${reconciled} stale running session(s)`);
console.log(
  existsSync(DIST_DIR)
    ? `[smidja] serving ui from  ${DIST_DIR}`
    : `[smidja] no ./dist — use "bun run dev" for the Vite dev server on :8438`,
);

process.on("SIGINT", () => {
  db.close();
  process.exit(0);
});
