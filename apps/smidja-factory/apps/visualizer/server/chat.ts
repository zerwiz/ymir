/**
 * /api/chat/* — the orchestrator chat endpoints.
 *
 *   POST /api/chat/message  → send a message to Pi as Völundr, capture the reply
 *   GET  /api/chat/history  → conversation for one session (JSONL on disk)
 *   POST /api/chat/session  → launch a smidja run for a team + task
 *   POST /api/chat/steer    → inject guidance into the active session
 *
 * Conversation is stored as JSONL at <data_dir>/chat-history/<session>.jsonl,
 * one JSON object per line (the data_dir is the sibling of the trace db).
 *
 * This mirrors the existing server style: read-only against smidja.db, cautious
 * about spawning, and everything wrapped by `safely` in the caller.
 */
import { existsSync, mkdirSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { repoRootOf } from "./db.ts";
import { piCommand } from "./model-catalog.ts";
import { parseEnv } from "./settings.ts";
import type {
  ChatHistoryResponse,
  ChatMessage,
  ChatMessageRequest,
  ChatMessageResponse,
  SessionStartRequest,
  SessionStartResponse,
} from "../shared/types.ts";

const VERBOSE = process.env.SMIDJA_CHAT_DEBUG === "1" || process.env.SMIDJA_DEBUG === "1";

/**
 * The chat's default model — the house's orchestration model, and one this
 * machine's pi catalog actually serves (`bin/model/catalog.sh --has …`). The id
 * that used to sit here, `opencode-go/deepseek-v4-flash`, is listed by no
 * provider: pi warns "Model … not found", lets the request through as a custom
 * id, and the upstream answers 400 {"message":"Model is unavailable."} — which
 * pi reports as exit 1, which the chat showed as "Völundr (Pi) failed".
 */
export const DEFAULT_CHAT_MODEL = "opencode-go/deepseek-v4.1-flash";

/**
 * WHERE THE OPERATOR NAMES THEIR MODEL — the home, never this repo.
 *
 * The repo is agnostic and ships the generic default above. What one operator wants their
 * chat to start on is their own shape, so it lives in the home's `config/smidja.env`
 * (`SMIDJA_CHAT_MODEL=…`; the repo ships the shape as `config/smidja.env.example`). A unit
 * or a wrapper that knows better may set `SMIDJA_CHAT_MODEL` in the environment instead.
 */
export const CHAT_CONFIG_PATH = "config/smidja.env";

/** The model the chat starts on: the environment, then the home, then the repo default. */
export function chatModelDefault(root: string): string {
  const fromEnv = process.env.SMIDJA_CHAT_MODEL?.trim();
  if (fromEnv) return fromEnv;
  try {
    const file = join(root, CHAT_CONFIG_PATH);
    if (existsSync(file)) {
      const value = parseEnv(readFileSync(file, "utf8")).get("SMIDJA_CHAT_MODEL")?.trim();
      if (value) return value;
    }
  } catch {
    /* an unreadable config must never stop the chat — fall through to the default */
  }
  return DEFAULT_CHAT_MODEL;
}

/**
 * pi's extension status lines: `[constellation] mesh: unconfigured`,
 * `[excalidraw] excalidraw: no fork`, `[wayofteams-tools] …`. Every installed
 * extension prints one on every run — working or failing — so none of them is
 * the cause of a failure, and none belongs in the error the user reads.
 */
const EXTENSION_STATUS = /^\[[a-z][a-z0-9._-]*\]/i;

/**
 * The real reason pi exited non-zero, shown WHOLE: its stderr with the extension
 * status lines dropped and nothing truncated. A provider's error body is the one
 * line that says what is wrong (which model, which key, which door), so cutting
 * it at 300 characters hid exactly the answer it was meant to give.
 */
export function failureReason(stderr: string): string {
  const lines = stderr
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);
  const real = lines.filter((l) => !EXTENSION_STATUS.test(l));
  // If nothing but status lines came back, repeat what pi said rather than nothing.
  return (real.length ? real : lines).join("\n");
}

/** Debug helper: always visible in the server log when chat debugging is on. */
function dbg(...parts: unknown[]): void {
  if (VERBOSE) console.error("[chat-debug]", ...parts);
}

/** Bun.env can carry non-string (boolean) values that Bun.spawn env rejects. */
function envWith(extra: Record<string, string>): Record<string, string> {
  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(Bun.env)) {
    if (typeof v === "string") env[k] = v;
  }
  return { ...env, ...extra };
}

function chatDir(dbPath: string): string {
  // data_dir = dirname(dbPath); chat history lives beside the db.
  return join(dirname(dbPath), "chat-history");
}

function sessionFile(dbPath: string, sessionId: string): string {
  return join(chatDir(dbPath), `${sessionId}.jsonl`);
}

/** Every persisted chat session, newest first, with its message count and last
 * activity time — powers the multi-session switcher (new/open/switch chat).
 * The default session always appears; an empty history dir yields just that. */
export async function listSessions(dbPath: string): Promise<{ id: string; messages: number; updated_at: string | null }[]> {
  const dir = chatDir(dbPath);
  const out: { id: string; messages: number; updated_at: string | null }[] = [];
  let seen = false;
  if (existsSync(dir)) {
    for (const name of readdirSync(dir)) {
      if (!name.endsWith(".jsonl")) continue;
      const id = name.slice(0, -".jsonl".length);
      const file = join(dir, name);
      let updated_at: string | null = null;
      let messages = 0;
      try {
        const st = statSync(file);
        updated_at = new Date(st.mtime).toISOString();
        const text = await Bun.file(file).text();
        messages = text.split("\n").filter((l) => l.trim()).length;
      } catch {
        /* skip unreadable */
      }
      if (id === "default") seen = true;
      out.push({ id, messages, updated_at });
    }
  }
  if (!seen) out.push({ id: "default", messages: 0, updated_at: null });
  return out.sort((a, b) => (b.updated_at ?? "").localeCompare(a.updated_at ?? ""));
}

async function readHistoryAsync(dbPath: string, sessionId: string): Promise<ChatMessage[]> {
  const file = sessionFile(dbPath, sessionId);
  if (!existsSync(file)) return [];
  const text = await Bun.file(file).text();
  const out: ChatMessage[] = [];
  for (const line of text.split("\n")) {
    if (!line.trim()) continue;
    try {
      out.push(JSON.parse(line) as ChatMessage);
    } catch {
      // skip malformed lines
    }
  }
  return out;
}

async function appendMessage(dbPath: string, sessionId: string, msg: ChatMessage): Promise<void> {
  const dir = chatDir(dbPath);
  mkdirSync(dir, { recursive: true });
  const file = sessionFile(dbPath, sessionId);
  const existing = existsSync(file) ? await Bun.file(file).text() : "";
  await Bun.file(file).write(existing + JSON.stringify(msg) + "\n");
}

/** A session id is a path segment on disk — plain identifiers only. */
const SAFE_SESSION = /^[A-Za-z0-9._-]+$/;

export async function history(dbPath: string, sessionId: string): Promise<ChatHistoryResponse> {
  if (!SAFE_SESSION.test(sessionId)) throw new Error("invalid session id");
  return readHistoryAsync(dbPath, sessionId);
}

/**
 * DELETE /api/chat/session — permanently delete a chat conversation.
 * Removes the session JSONL from disk. The `default` session is allowed to be
 * deleted too (it is recreated empty on the next listSessions call).
 */
export async function deleteSession(dbPath: string, sessionId: string): Promise<{ ok: boolean }> {
  if (!SAFE_SESSION.test(sessionId)) throw new Error("invalid session id");
  const file = sessionFile(dbPath, sessionId);
  if (existsSync(file)) {
    await Bun.file(file).delete();
  }
  return { ok: true };
}

/** Debug: raw session-file listing (id, size, last-modified) — for debugging
 * the chat store when the switcher shows a stale/empty conversation list. */
export async function debugSessions(dbPath: string): Promise<{
  dir: string;
  sessions: { id: string; bytes: number; updated_at: string | null }[];
}> {
  const dir = chatDir(dbPath);
  const sessions: { id: string; bytes: number; updated_at: string | null }[] = [];
  if (existsSync(dir)) {
    for (const name of readdirSync(dir)) {
      if (!name.endsWith(".jsonl")) continue;
      try {
        const st = statSync(join(dir, name));
        sessions.push({
          id: name.slice(0, -".jsonl".length),
          bytes: st.size,
          updated_at: new Date(st.mtime).toISOString(),
        });
      } catch {
        /* skip unreadable */
      }
    }
  }
  return { dir, sessions: sessions.sort((a, b) => (b.updated_at ?? "").localeCompare(a.updated_at ?? "")) };
}

/**
 * POST /api/chat/message — run Pi once in print mode against a persistent
 * session-scoped conversation, capture stdout as Völundr's reply, and persist both
 * the user message and the reply to the session JSONL.
 */
export async function sendMessage(req: ChatMessageRequest, dbPath: string): Promise<ChatMessageResponse> {
  const { sessionId, content, model } = req;
  if (!SAFE_SESSION.test(sessionId)) throw new Error("invalid session id");
  const trimmed = content.trim();
  if (!trimmed) throw new Error("message is empty");

  await appendMessage(dbPath, sessionId, {
    id: `u-${Date.now()}`,
    ts: new Date().toISOString(),
    role: "user",
    content: trimmed,
  });

  const reply = await runPi(trimmed, sessionId, model);

  const msg: ChatMessage = {
    id: `k-${Date.now()}`,
    ts: new Date().toISOString(),
    role: "kaia",
    content: reply,
  };
  await appendMessage(dbPath, sessionId, msg);
  return { message: msg };

  async function runPi(prompt: string, session: string, requestedModel?: string): Promise<string> {
    const root = repoRootOf(dbPath);
    // The user picks the chat model in the UI (orchestrator picker); fall back
    // to the orchestrator's cloud model. Passing it explicitly keeps pi on the
    // right surface instead of its heavy wayofteams-tools MCP default.
    // The user picks the chat model in the UI (the model picker); fall back to
    // the house's orchestration model. Passing it explicitly keeps pi on the
    // right surface instead of its heavy wayofteams-tools MCP default.
    // It must be an id this machine's pi catalog actually serves: the old
    // `deepseek-v4-flash` is not one, and the provider answers it with
    // 400 "Model is unavailable" (pi then exits 1, plan 275 item 15).
    const model = requestedModel?.trim() || chatModelDefault(root);
    const args = [
      "--print",
      "--session",
      `chat/${session}`,
      "--model",
      model,
      ...volundrPromptArgs(root),
      prompt,
    ];
    dbg(`spawn pi: model=${model} session=${session} cwd=${root}`);
    dbg(`  args: ${args.join(" ").slice(0, 300)}${args.join(" ").length > 300 ? " …" : ""}`);
    const proc = Bun.spawn(piCommand(args), {
      stdout: "pipe",
      stderr: "pipe",
      cwd: root,
      env: envWith(wotEnv(root)),
    });
    dbg(`  pid=${proc.pid}`);

    // Race the WHOLE read against a timer that RESOLVES to a sentinel (never
    // rejects) — an unhandled rejection here crashes the entire trace server
    // (observed twice). pi can hang with no output, so the stream never closes.
    const TIMED_OUT = Symbol("timed-out");
    const result = await Promise.race([
      (async () => {
        const [stdout, stderr] = await Promise.all([
          new Response(proc.stdout).text(),
          new Response(proc.stderr).text(),
        ]);
        const exit = await proc.exited;
        return { exit: exit ?? 0, stdout, stderr };
      })(),
      new Promise<typeof TIMED_OUT>((resolve) => setTimeout(() => resolve(TIMED_OUT), 120_000)),
    ]);

    if (result === TIMED_OUT) {
      dbg(`  TIMED OUT after 120s (pid=${proc.pid}) — killing`);
      try { proc.kill(); } catch { /* ignore */ }
      throw new Error("Völundr (Pi) took too long — try again");
    }
    dbg(`  exit=${result.exit} stdout=${result.stdout.length}ch stderr=${result.stderr.length}ch`);
    if (result.exit !== 0) {
      if (VERBOSE) console.error(`[chat] pi exit ${result.exit}, stderr:\n${result.stderr}`);
      // Surface WHY pi failed instead of a bare exit code — the chat UI shows
      // this to the user. What pi says first is not the cause: each extension
      // prints a status line (`[constellation] …`, `[excalidraw] …`) whether or
      // not the message works, and showing those as the reason hid the real
      // provider error and cut it at 300 characters. Drop every status line,
      // keep the whole of what is left.
      const why = failureReason(result.stderr);
      throw new Error(`Völundr (Pi) failed (exit ${result.exit})${why ? ` — ${why}` : ""}`);
    }
    return result.stdout.trim() || "(no response)";
  }
}

/**
 * VÖLUNDR'S PERSONA — where it comes from, in order.
 *
 * The repo stays agnostic: the smithy ships a **generic** Völundr with the app, and the
 * operator's own shape lives in their home and may override it. What must never happen
 * again is the middle case: the chat quietly finding nothing and answering as whichever
 * agent's contract happens to sit in the working directory (measured 2026-11-14 — the
 * reply introduced itself as the seat's counsellor).
 *
 *   1. `VOLUNDR_PERSONA`, then `KAIA_PERSONA` — an explicit file, for a unit or a wrapper
 *      that knows better. The old name is still read so no wrapper breaks.
 *   2. `<root>/.agents/skills/smidja/volundr/persona.md`, then the historical
 *      `.../kaia/persona.md` — the operator's own shape. When the chat's data lives in the
 *      home, `root` IS the home, so this is the home override.
 *   3. `<root>/apps/smidja-factory/apps/visualizer/prompts/volundr.md`, then the historical
 *      `prompts/kaia.md` — a target repo that carries the smithy itself.
 *   4. the default that ships WITH the app, found by walking up from this file — so the
 *      chat answers as Völundr on any machine, in any home, without a config step.
 *   5. the older layouts, kept so a repo shaped differently still finds its own.
 */
const LEGACY_PERSONA_PATHS = [
  "apps/smidja/smidja_data/prompt_engineering/orchestrator/system.md",
  ".agents/skills/smidja/skills/volundr/prompt/volundr-system.md",
];
const APP_PERSONA_PATH = "apps/smidja-factory/apps/visualizer/prompts/volundr.md";
const LEGACY_APP_PERSONA_PATH = "apps/smidja-factory/apps/visualizer/prompts/kaia.md";
const HOME_PERSONA_PATH = ".agents/skills/smidja/volundr/persona.md";
const LEGACY_HOME_PERSONA_PATH = ".agents/skills/smidja/kaia/persona.md";

/** The nearest ancestor of `start` that holds `rel`, or null. */
function findUp(start: string, rel: string): string | null {
  let dir = start;
  for (let i = 0; i < 8; i++) {
    const candidate = join(dir, rel);
    if (existsSync(candidate)) return candidate;
    const up = dirname(dir);
    if (up === dir) break;
    dir = up;
  }
  return null;
}

/** The persona file the chat must be given, or null when nothing can be found. */
export function volundrPersonaFile(root: string): string | null {
  const explicit = (process.env.VOLUNDR_PERSONA ?? process.env.KAIA_PERSONA)?.trim();
  if (explicit && existsSync(explicit)) return explicit;
  for (const rel of [HOME_PERSONA_PATH, LEGACY_HOME_PERSONA_PATH, APP_PERSONA_PATH, LEGACY_APP_PERSONA_PATH]) {
    const abs = join(root, rel);
    if (existsSync(abs)) return abs;
  }
  const shipped = findUp(import.meta.dir, APP_PERSONA_PATH);
  if (shipped) return shipped;
  for (const rel of LEGACY_PERSONA_PATHS) {
    const abs = join(root, rel);
    if (existsSync(abs)) return abs;
  }
  return null;
}

/** The historical name of `volundrPersonaFile`, kept as an alias so a wrapper or a
 *  test written before 2026-11-14 keeps working (never remove a feature). */
export const kaiaPersonaFile = volundrPersonaFile;

/** The persona, appended to pi's base prompt, plus the flag that keeps the chat
 *  from adopting the identity of whatever AGENTS.md sits in its working directory. */
function volundrPromptArgs(cwd: string): string[] {
  const persona = volundrPersonaFile(cwd);
  const args: string[] = ["--no-context-files"];
  if (persona) args.push("--append-system-prompt", persona);
  return args;
}

/**
 * GET /api/chat/models — models the CHAT pi process can actually resolve, from
 * pi's own catalog (`pi --list-models`), e.g. opencode-go/qwen3.6-plus. The
 * roster model ids (roster-api) are for smidja runs, not the chat -- a roster
 * id like lmstudio/qwen3.5-9b may not exist in a machine's pi catalog.
 */
export { piModels } from "./model-catalog.ts";

/**
 * POST /api/chat/session — launch a smidja run for the chosen team + task.
 * Builds a resolved roster config (reusing resolve-config.py), optionally injecting
 * an orchestrator model override, then launches `smidja run` detached in the repo.
 *
 * Returns the smidja_id so the UI can switch to live progress.
 */
export async function startSession(
  req: SessionStartRequest,
  dbPath: string,
  binaryPath = "scripts/smidja",
): Promise<SessionStartResponse> {
  const root = repoRootOf(dbPath);
  const config = await buildTeamConfig(root, req.roster, req.orchestratorModel);
  const task = req.task.trim();
  if (!task) throw new Error("task is empty");

  const proc = Bun.spawn(
    [binaryPath, "run", "sdlc", task, "--config", config],
    {
      stdout: "pipe",
      stderr: "pipe",
      cwd: root,
      env: envWith({}),
    },
  );

  // Return immediately with a provisional id; the run's real smidja_id is
  // extracted from output on a subsequent poll if needed.
  const adwId = `chat-${Date.now().toString(36)}`;
  // Swallow all errors here — this is fire-and-forget background logging and
  // an unhandled rejection would crash the whole trace server (observed).
  proc.exited
    .then(async (code) => {
      try {
        const err = code === 0 ? "" : await new Response(proc.stderr).text().catch(() => "");
        if (code !== 0) console.error(`[chat] smidja run exit ${code}: ${err.slice(0, 500)}`);
        else if (VERBOSE) {
          const out = await new Response(proc.stdout).text().catch(() => "");
          console.error(`[chat] smidja started:\n${out.slice(0, 500)}`);
        }
      } catch (logError) {
        if (VERBOSE) console.error(`[chat] post-run logging failed: ${logError}`);
      }
    })
    .catch((launchError) => {
      if (VERBOSE) console.error(`[chat] smidja run launch error: ${launchError}`);
    });

  return {
    session_id: adwId,
    roster: req.roster,
    model: req.orchestratorModel ?? "",
    smidja_id: adwId,
  };
}

/** Build a concrete roster config, injecting an orchestrator override if given. */
async function buildTeamConfig(root: string, roster: string, override?: string): Promise<string> {
  const resolveScript = join(root, "scripts", "resolve-config.py");
  if (!existsSync(resolveScript)) {
    throw new Error(`resolve-config.py not found at ${resolveScript}`);
  }
  let cfgPath: string;
  const base = Bun.spawn(
    ["uv", "run", "--with", "pyyaml", "python", resolveScript],
    { stdout: "pipe", stderr: "pipe", cwd: root, env: envWith({ SMIDJA_ROSTER: roster }) },
  );
  const [baseOut, baseErr] = await Promise.all([
    new Response(base.stdout).text(),
    new Response(base.stderr).text(),
  ]);
  const baseExit = await base.exited;
  if (baseExit !== 0) throw new Error(`resolve roster '${roster}' failed (${baseExit}): ${baseErr.trim()}`);

  cfgPath = baseOut.trim();
  if (!cfgPath) throw new Error(`resolve roster '${roster}' produced no config`);

  if (!override) return cfgPath;

  // Inject a per-agent orchestrator override into the resolved config.
  const script = `
import sys, os, yaml, tempfile
cfg = yaml.safe_load(open(sys.argv[1]))
for a in cfg.get("agents", []):
    if a.get("name") == "orchestrator":
        a["model"] = os.environ["SMIDJA_CHAT_ORCHESTRATOR"]
fd, path = tempfile.mkstemp(suffix=".config.yaml", prefix="smidja-chat-orch-")
with os.fdopen(fd, "w") as f:
    yaml.safe_dump(cfg, f, sort_keys=False)
print(path)
`;
  const inject = Bun.spawn(["uv", "run", "--with", "pyyaml", "python", "-c", script, cfgPath], {
    stdout: "pipe",
    stderr: "pipe",
    cwd: root,
    env: envWith({ SMIDJA_CHAT_ORCHESTRATOR: override }),
  });
  const [injOut, injErr] = await Promise.all([
    new Response(inject.stdout).text(),
    new Response(inject.stderr).text(),
  ]);
  const injExit = await inject.exited;
  if (injExit !== 0) throw new Error(`orchestrator override failed (${injExit}): ${injErr.trim()}`);
  return injOut.trim();
}

/** Inject guidance (steer) into the active session's steer.md — mirrors the existing route. */
export async function steer(dbPath: string, adwId: string, message: string): Promise<{ ok: boolean }> {
  if (!SAFE_SESSION.test(adwId)) throw new Error("invalid session id");
  const steerFile = join(dirname(dbPath), "sessions", adwId, "steer.md");
  const append = `\n> ${new Date().toISOString()}\n${message.trim()}\n`;
  if (existsSync(steerFile)) {
    await Bun.file(steerFile).write((await Bun.file(steerFile).text()) + append);
  } else {
    throw new Error(`session ${adwId} not found (no steer file yet)`);
  }
  return { ok: true };
}

/**
 * WayOfTeams MCP keys from the repo's .env (written by the settings page), so
 * the CHAT's pi process gets the @wayofmono/wayofteams-tools surface directly —
 * independent of whether the user installed it for their own interactive pi.
 * Never leaks values into logs; missing .env → empty.
 */
function wotEnv(root: string): Record<string, string> {
  const env: Record<string, string> = {};
  try {
    const file = join(root, ".env");
    if (!existsSync(file)) return env;
    const text = readFileSync(file, "utf8");
    for (const line of text.split(/\r?\n/)) {
      const m = /^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/.exec(line.trim());
      if (!m) continue;
      const key = m[1];
      if (
        key === "WAYOFTEAMS_MCP_TOKEN" ||
        key === "WOTEAMS_MCP_URL" ||
        key === "WOTEAMS_AGENT_NAME" ||
        key === "WOTEAMS_AGENT_ID"
      ) {
        env[key] = m[2];
      }
    }
  } catch {
    /* unreadable .env → chat just runs without WOT keys */
  }
  return env;
}
