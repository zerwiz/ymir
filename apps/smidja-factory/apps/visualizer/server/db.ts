/**
 * SQLite reader over a target repo's smidja.db.
 *
 * The read connection is opened readonly and every query on it is a SELECT —
 * the writers are the tracers of running smidja processes, and WAL lets us read
 * straight through their inserts.
 *
 * ONE exception, opened lazily on its own connection: `setArchived`. Archiving
 * is review triage — "I have looked at this run" — which has to outlive a
 * browser, so it lives on the session row rather than in localStorage. It is
 * the only write this process can make, it touches exactly one column, and it
 * never runs unless a human clicks the button.
 */
import { Database } from "bun:sqlite";
import { existsSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import type {
  AgentSession,
  AgentStartPayload,
  DecisionsBucket,
  DecisionsResponse,
  Envelope,
  Event,
  EventsPage,
  GateResult,
  ModelProviderStat,
  Phase,
  Session,
  SessionDetail,
  SessionSummary,
  SessionUsage,
  StatsResponse,
} from "../shared/types.ts";

export const DEFAULT_DB_RELATIVE = "apps/smidja/smidja_data/smidja.db";
const MAX_LIMIT = 1000;
const DEFAULT_LIMIT = 500;

/**
 * Commercial model catalog for the stats "Commercial comparison" panel.
 * Rates are standard pay-as-you-go API prices per 1M tokens (input/output),
 * from the tokens-optimization spec. Where the spec quotes a range, the
 * midpoint is used. `cache` is the share of the input price billed on a
 * cache read (published caching rate per provider: OpenAI/DeepSeek/Meta 50%,
 * Google 25%, Anthropic 10%).
 */
interface VendorModelDef {
  id: string;
  name: string;
  provider: string;
  tier: 1 | 2 | 3;
  rank: number;
  pin: number;
  po: number;
  cache: number;
}

const VENDOR_MODELS: VendorModelDef[] = [
  // Tier 1 — heavyweight flagships & enterprise intelligence
  { id: "gpt-5.5-pro",   name: "GPT-5.5 Pro",         provider: "OpenAI",        tier: 1, rank: 1,  pin: 30.0,  po: 180.0, cache: 0.5 },
  { id: "o3-pro",       name: "o3-pro",              provider: "OpenAI",        tier: 1, rank: 2,  pin: 20.0,  po: 80.0,  cache: 0.5 },
  { id: "claude-opus",  name: "Claude Opus 4.6 / 5",  provider: "Anthropic",     tier: 1, rank: 3,  pin: 5.0,   po: 25.0,  cache: 0.1 },
  { id: "gpt-5.5",      name: "GPT-5.5",             provider: "OpenAI",        tier: 1, rank: 4,  pin: 5.0,   po: 30.0,  cache: 0.5 },
  { id: "llama-3.1-405b", name: "Llama 3.1 405B",   provider: "Meta (Hosted)", tier: 1, rank: 5,  pin: 3.75,  po: 3.75,  cache: 0.5 },
  { id: "gpt-5.4",      name: "GPT-5.4",             provider: "OpenAI",        tier: 1, rank: 6,  pin: 2.5,   po: 15.0,  cache: 0.5 },
  { id: "gpt-4o",       name: "GPT-4o",              provider: "OpenAI",        tier: 1, rank: 7,  pin: 2.5,   po: 10.0,  cache: 0.5 },
  { id: "gemini-3.1-pro", name: "Gemini 3.1 Pro",   provider: "Google",        tier: 1, rank: 8,  pin: 2.0,   po: 12.0,  cache: 0.25 },
  { id: "o3",           name: "o3",                  provider: "OpenAI",        tier: 1, rank: 9,  pin: 2.0,   po: 8.0,   cache: 0.5 },
  { id: "claude-sonnet", name: "Claude Sonnet 4.6 / 5", provider: "Anthropic", tier: 1, rank: 10, pin: 2.5,   po: 12.5,  cache: 0.1 },
  // Tier 2 — mid-range & high-efficiency workhorses
  { id: "mistral-large-3", name: "Mistral Large 3",  provider: "Mistral AI",    tier: 2, rank: 11, pin: 0.5,   po: 1.5,   cache: 0.5 },
  { id: "claude-haiku", name: "Claude Haiku 4.5",    provider: "Anthropic",     tier: 2, rank: 12, pin: 1.0,   po: 5.0,   cache: 0.1 },
  { id: "gemini-2.5-pro", name: "Gemini 2.5 Pro",   provider: "Google",        tier: 2, rank: 13, pin: 1.25,  po: 10.0,  cache: 0.25 },
  { id: "o4-mini",      name: "o4-mini",             provider: "OpenAI",        tier: 2, rank: 14, pin: 0.55,  po: 2.2,   cache: 0.5 },
  { id: "deepseek-r1",  name: "DeepSeek R1",         provider: "DeepSeek",      tier: 2, rank: 15, pin: 0.55,  po: 2.19,  cache: 0.5 },
  { id: "gemini-3-flash-preview", name: "Gemini 3 Flash Preview", provider: "Google", tier: 2, rank: 16, pin: 0.5, po: 3.0, cache: 0.25 },
  { id: "command-r-plus", name: "Command R+",        provider: "Cohere",        tier: 2, rank: 17, pin: 2.5,   po: 10.0,  cache: 0.5 },
  { id: "gpt-5.4-mini", name: "GPT-5.4 Mini",        provider: "OpenAI",        tier: 2, rank: 18, pin: 0.75,  po: 4.5,   cache: 0.5 },
  { id: "deepseek-v4",  name: "DeepSeek V4",         provider: "DeepSeek",      tier: 2, rank: 19, pin: 0.3,   po: 0.5,   cache: 0.5 },
  { id: "codestral",    name: "Codestral",           provider: "Mistral AI",    tier: 2, rank: 20, pin: 0.3,   po: 0.9,   cache: 0.5 },
  { id: "deepseek-chat-v3.2", name: "DeepSeek-Chat (V3.2)", provider: "DeepSeek", tier: 2, rank: 21, pin: 0.28, po: 0.42, cache: 0.5 },
  { id: "llama-3.3-70b", name: "Llama 3.3 70B",      provider: "Meta (Hosted)", tier: 2, rank: 22, pin: 0.41,  po: 0.52,  cache: 0.5 },
  { id: "mistral-medium-3.5", name: "Mistral Medium 3.5", provider: "Mistral AI", tier: 2, rank: 23, pin: 1.5, po: 7.5, cache: 0.5 },
  { id: "gpt-4.1",      name: "GPT-4.1",             provider: "OpenAI",        tier: 2, rank: 24, pin: 2.0,   po: 8.0,   cache: 0.5 },
  { id: "qwen-2.5-72b", name: "Qwen 2.5 72B",        provider: "Alibaba (Hosted)", tier: 2, rank: 25, pin: 0.35, po: 0.4, cache: 0.5 },
  // Tier 3 — flash, mini & edge engines
  { id: "gemini-3.7-flash", name: "Gemini 3.7 Flash", provider: "Google",      tier: 3, rank: 26, pin: 0.75,  po: 3.75,  cache: 0.25 },
  { id: "gemini-3.6-flash", name: "Gemini 3.6 Flash", provider: "Google",      tier: 3, rank: 27, pin: 0.75,  po: 3.75,  cache: 0.25 },
  { id: "gpt-4.1-mini", name: "GPT-4.1 Mini",        provider: "OpenAI",        tier: 3, rank: 28, pin: 0.4,   po: 1.6,   cache: 0.5 },
  { id: "llama-4-maverick", name: "Llama 4 Maverick", provider: "Meta (Hosted)", tier: 3, rank: 29, pin: 0.25, po: 0.875, cache: 0.5 },
  { id: "gpt-5-mini",   name: "GPT-5 Mini",          provider: "OpenAI",        tier: 3, rank: 30, pin: 0.25,  po: 2.0,   cache: 0.5 },
  { id: "gemini-3.1-flash-lite", name: "Gemini 3.1 Flash-Lite", provider: "Google", tier: 3, rank: 31, pin: 0.25, po: 1.5, cache: 0.25 },
  { id: "gpt-5.4-nano", name: "GPT-5.4 Nano",        provider: "OpenAI",        tier: 3, rank: 32, pin: 0.2,   po: 1.25,  cache: 0.5 },
  { id: "mistral-small-4", name: "Mistral Small 4",  provider: "Mistral AI",    tier: 3, rank: 33, pin: 0.15,  po: 0.6,   cache: 0.5 },
  { id: "gpt-4o-mini",  name: "GPT-4o mini",         provider: "OpenAI",        tier: 3, rank: 34, pin: 0.15,  po: 0.6,   cache: 0.5 },
  { id: "gpt-4.1-nano", name: "GPT-4.1 Nano",        provider: "OpenAI",        tier: 3, rank: 35, pin: 0.1,   po: 0.4,   cache: 0.5 },
  { id: "gemini-2.5-flash-lite", name: "Gemini 2.5 Flash-Lite", provider: "Google", tier: 3, rank: 36, pin: 0.1, po: 0.4, cache: 0.25 },
  { id: "llama-4-scout", name: "Llama 4 Scout",       provider: "Meta (Hosted)", tier: 3, rank: 37, pin: 0.165, po: 0.5, cache: 0.5 },
  { id: "ministral-8b", name: "Ministral 8B",         provider: "Mistral AI",    tier: 3, rank: 38, pin: 0.1,   po: 0.1,   cache: 0.5 },
  { id: "llama-3.2-3b", name: "Llama 3.2 3B",         provider: "Meta (Hosted)", tier: 3, rank: 39, pin: 0.02,  po: 0.02,  cache: 0.5 },
  { id: "ministral-3b", name: "Ministral 3B",         provider: "Mistral AI",    tier: 3, rank: 40, pin: 0.04,  po: 0.04,  cache: 0.5 },
];

const TIER_LABEL: Record<number, string> = {
  1: "Tier 1 — heavyweight flagships & enterprise intelligence",
  2: "Tier 2 — mid-range & high-efficiency workhorses",
  3: "Tier 3 — flash, mini & edge engines",
};

/**
 * Model ids local runs resolve to. Anything not under one of these prefixes
 * is treated as an online/cloud API — the stats panel's local-vs-online split
 * hangs off this. pi runs land on `lmstudio/…`; opencode picks up cloud
 * providers (`opencode/…`, `opencode-go/…`) which are online.
 */
const LOCAL_MODEL_PREFIXES = ["lmstudio/", "ollama/", "localhost/", "vllm/", "unsloth/"];
const isLocalModel = (model: string) =>
  LOCAL_MODEL_PREFIXES.some((p) => model.toLowerCase().startsWith(p));

/** The fix per failure class — what an operator should change to make it work. */
const FIXES: Record<string, string> = {
  JSON_CONTRACT: "use a stronger model for the agent (deepseek-v4-flash via ocrd), or harden its user.md: 'Respond with ONLY valid JSON matching <Type>'",
  EMPTY_COMMIT: "drop the redundant commit phase, or gate it on `git status --porcelain` being non-empty",
  STOPPED: "run was killed (SIGTERM) — re-run with more time or resume with --smidja-id",
  AGENT_EXIT: "agent process exited 1 — check the raw stream for the failing tool call",
  HALLUCINATED_BUILD: "builder must actually run tools before reporting — enforce the tool-use mandate in builder/system.md",
  HALLUCINATED_COORDINATION: "orchestrator must dispatch subagents before reporting — enforce in orchestrator/system.md",
  UNKNOWN: "inspect the run with `smidja audit` / `smidja diagnose`",
};

/** Map a failed phase + error to a failure class (mirrors smidja diagnose). */
export function classifyFailure(phase: string, error: string | null): string {
  const err = error ?? "";
  if (err.includes("never produced valid") || err.includes("JSON")) return "JSON_CONTRACT";
  if (err.includes("nothing to commit")) return "EMPTY_COMMIT";
  if (err === "143" || err === "130") return "STOPPED";
  if (err === "1") return "AGENT_EXIT";
  if (phase === "build") return "HALLUCINATED_BUILD";
  if (phase === "orchestrate") return "HALLUCINATED_COORDINATION";
  return "UNKNOWN";
}

/**
 * Resolve the db path: --db arg wins, then CMD_DB, then <cwd>/apps/smidja/smidja_data/smidja.db.
 * The db lives in the TARGET repo, so cwd is the repo the visualizer is pointed at.
 */
export function resolveDbPath(argv: string[] = Bun.argv): string {
  const flagIndex = argv.indexOf("--db");
  const inline = argv.find((a) => a.startsWith("--db="));
  const raw =
    (flagIndex !== -1 ? argv[flagIndex + 1] : undefined) ??
    inline?.slice("--db=".length) ??
    process.env.CMD_DB ??
    DEFAULT_DB_RELATIVE;

  return isAbsolute(raw) ? raw : resolve(process.cwd(), raw);
}

/**
 * The target repo's root, found by walking up from the db to a marker the repo
 * always carries (`.agents/`, else `.git/`). Counting dirnames was brittle: the
 * smithy moved from `<repo>/smidja/` to `<repo>/apps/smidja/`, and a fixed count
 * would have to change in every module that derived anything from it.
 */
export function repoRootOf(dbPath: string): string {
  let dir = dirname(dbPath);
  for (let i = 0; i < 8; i++) {
    if (existsSync(join(dir, ".agents")) || existsSync(join(dir, ".git"))) return dir;
    const up = dirname(dir);
    if (up === dir) break;
    dir = up;
  }
  return resolve(dirname(dirname(dirname(dbPath))));   // legacy fallback
}

export class smidjaDb {
  readonly path: string;
  /**
   * Where the smidja session dirs live: `{data_dir}/sessions/{smidja_id}/{agent}/`.
   * The db sits in the same data_dir (config's `observability.db` defaults to
   * `apps/smidja/smidja_data/smidja.db`), so deriving it as a sibling of the db file keeps
   * working when the whole data_dir is relocated.
   */
  readonly sessionsDir: string;
  readonly journalMode: string;
  private readonly db: Database;
  /** Opened on first archive and kept; null until then. */
  /// ghost: Kaia auto-admission one-shots (smidja_prompt 'What Kaia already
  /// remembers…' / 'You are admitting smidja session…') are plumbing, already
  /// recorded inside the parent run as handoff/admitted events. Hide them from
  /// the session list unless CMD_SHOW_ADMISSIONS=1.
  private admissionFilter(): string {
    if (process.env.CMD_SHOW_ADMISSIONS === "1") return "";
    const isName = this.hasColumn("sessions", "smidja_name");
    const nameCond = isName
      ? "smidja_name = 'smidja_prompt' AND"
      : "";
    return (
      " AND NOT COALESCE(" +
      nameCond +
      " (request LIKE 'What Kaia already remembers%' OR request LIKE 'You are admitting smidja session%'), 0)"
    );
  }
  private writer: Database | null = null;
  /** Cache for optionalColumn(), keyed "table.column". Only ever false → true. */
  private readonly columnCache = new Map<string, boolean>();

  constructor(path: string) {
    if (!existsSync(path)) {
      throw new Error(
        `smidja.db not found at ${path}\n` +
          `Point the visualizer at a target repo: --db <path> or CMD_DB=<path>, ` +
          `or run it from a repo root containing ${DEFAULT_DB_RELATIVE}`,
      );
    }
    this.path = path;
    this.sessionsDir = resolve(dirname(path), "sessions");
    this.db = new Database(path, { readonly: true });

    // WAL is set by the tracer when it creates the db; a readonly connection
    // cannot change it, so we assert rather than set, and always take the
    // busy_timeout so a concurrent writer never turns into a failed request.
    this.db.exec("PRAGMA busy_timeout = 5000");
    this.db.exec("PRAGMA synchronous = NORMAL");
    const mode = this.db
      .query<{ journal_mode: string }, []>("PRAGMA journal_mode")
      .get();
    this.journalMode = mode?.journal_mode ?? "unknown";
    if (this.journalMode.toLowerCase() !== "wal") {
      console.warn(
        `[db] journal_mode is "${this.journalMode}", expected "wal" — ` +
          `live reads during agent writes may block`,
      );
    }

  }

  /**
   * A SELECT fragment for a column the tracer adds by migration.
   *
   * We open readonly and cannot run those ALTERs ourselves, so selecting one
   * blindly would throw "no such column" on every request against a db an older
   * tracer wrote. Instead we probe and substitute NULL, which reads downstream
   * as "this db predates the column" — the same thing the UI shows for a row
   * the migration didn't backfill.
   *
   * The probe re-runs while the column is missing, because the tracer's ALTER
   * can land while we're serving: a startup-only check would keep returning
   * NULL for the rest of the process even after the data arrived. Once seen,
   * a column never goes away, so it latches.
   */
  private hasColumn(table: string, column: string): boolean {
    const key = `${table}.${column}`;
    if (!this.columnCache.get(key)) {
      const cols = this.db
        .query<{ name: string }, []>(`PRAGMA table_info(${table})`)
        .all();
      this.columnCache.set(key, cols.some((c) => c.name === column));
    }
    return this.columnCache.get(key) ?? false;
  }

  private optionalColumn(table: string, column: string): string {
    return this.hasColumn(table, column) ? column : `NULL AS ${column}`;
  }

  /** Does the table exist? A fresh/new db has no schema until the tracer runs. */
  private hasTable(table: string): boolean {
    const row = this.db
      .query<{ n: number }, [string]>(
        "SELECT COUNT(*) AS n FROM sqlite_master WHERE type='table' AND name=?",
      )
      .get(table);
    return (row?.n ?? 0) > 0;
  }

  close(): void {
    this.writer?.close();
    this.db.close();
  }

  /**
   * Archive or restore a session — the only write in this process.
   *
   * busy_timeout matters: a run may be mid-insert on the same WAL db, and a
   * click should wait its turn rather than fail. Returns false when the id
   * does not exist, so the route can 404 instead of silently succeeding.
   */
  setArchived(adwId: string, archived: boolean): boolean {
    if (!this.hasColumn("sessions", "archived")) {
      throw new Error("this db predates the archived column — run any smidja once to migrate it");
    }
    if (!this.writer) {
      this.writer = new Database(this.path);
      this.writer.exec("PRAGMA busy_timeout=5000;");
    }
    this.writer
      .query("UPDATE sessions SET archived = ? WHERE smidja_id = ?")
      .run(archived ? 1 : 0, adwId);
    return this.session(adwId) !== null;
  }

  /** Live processes of a run — what a Stop button must SIGTERM, children first.
   *
   * Rows keep `ended_at NULL` until the smidja finalizes them; that does not
   * happen if the smidja was killed from code predating the SIGTERM handler,
   * crashed, or was SIGKILL'd. A still-open row can then point at a process
   * that is already dead, and dead pids must not be signalled (Stop/Pause
   * acting on ghosts). Each row is checked against the live process table. */
  liveProcesses(adwId: string): { kind: string; name: string; pid: number; command: string }[] {
    const rows = this.db
      .query<
        { kind: string; name: string; pid: number; command: string },
        [string]
      >(
        "SELECT kind, name, pid, command FROM processes WHERE smidja_id = ? AND ended_at IS NULL ORDER BY id",
      )
      .all(adwId);
    return rows.filter((r) => pidAlive(r.pid));
  }

  /**
   * Server-side half of Stop: close a run's process rows and mark the session
   * finished. The running smidja does this itself on SIGTERM (session.py's
   * `_finalize_when_killed`), but only when it runs code with that handler and
   * the signal lands cleanly. When it does not (old code, crash, SIGKILL) the
   * rows would say "running" for ever. Idempotent: a run already settled by
   * the smidja (or a session already terminal) is left untouched. Phases that are
   * still `running` are closed as `fail` too, so a stopped run does not show a
   * phase that claims to be in flight long after its processes are gone.
   */
  finalizeStopped(adwId: string): void {
    const row = this.db
      .query<{ status: string | null }, [string]>("SELECT status FROM sessions WHERE smidja_id = ?")
      .get(adwId);
    if (!row) return;
    if (row.status === "success" || row.status === "fail") return;
    this.ensureWriter();
    const now = new Date().toISOString();
    this.writer!.exec("BEGIN");
    try {
      this.writer!
        .query("UPDATE processes SET ended_at = ? WHERE smidja_id = ? AND ended_at IS NULL")
        .run(now, adwId);
      this.writer!
        .query(
          "UPDATE phases SET status = 'fail', error = COALESCE(error, 'stopped'), ended_at = ? " +
            "WHERE smidja_id = ? AND status = 'running'",
        )
        .run(now, adwId);
      this.writer!
        .query("UPDATE sessions SET status = 'fail', ended_at = ? WHERE smidja_id = ?")
        .run(now, adwId);
      this.writer!.exec("COMMIT");
    } catch (error) {
      this.writer!.exec("ROLLBACK");
      throw error;
    }
  }

  /** Lazily open the writable connection (same pattern as setArchived). */
  private ensureWriter(): void {
    if (!this.writer) {
      this.writer = new Database(this.path);
      this.writer.exec("PRAGMA busy_timeout=5000;");
      this.writer.exec("PRAGMA journal_mode=wal;");
    }
  }

  /**
   * Reconcile stale `running` rows against reality before they are served.
   *
   * A run is `running` until its smidja finalizes it. If that smidja was killed
   * from code with no SIGTERM finalizer, crashed, or was SIGKILL'd, the row
   * stays `running` forever with open process rows — the trace claims work is
   * in flight that is already dead, and the L1 card keeps offering Stop/Pause
   * that can only act on ghosts. A running session always has its own smidja
   * process registered, so: for every session still marked running, if none of
   * its registered pids are alive any more, finalize it as failed. Idempotent
   * and safe for genuinely-live runs (their smidja pid is alive). Cheap: it only
   * scans the small set of non-terminal sessions. Called at startup and on the
   * L1 list route.
   */
  reconcileStaleRunning(): number {
    // A fresh/new db (0 bytes) has no tables yet — the tracer creates them on
    // its first run. Reading against an empty schema would crash the server
    // ("no such table"), so a brand-new smidja.db is treated as having
    // nothing to reconcile. Tables appear as soon as the first agent runs.
    if (!this.hasTable("sessions")) return 0;
    const running = this.db
      .query<{ smidja_id: string }, []>(
        "SELECT DISTINCT smidja_id FROM sessions WHERE status = 'running'",
      )
      .all();
    let closed = 0;
    for (const { smidja_id } of running) {
      const procs = this.db
        .query<{ pid: number }, [string]>(
          "SELECT pid FROM processes WHERE smidja_id = ? AND ended_at IS NULL",
        )
        .all(smidja_id);
      if (procs.length === 0) continue; // no process rows — leave it for the winner
      if (procs.some((p) => pidAlive(p.pid))) continue; // still genuinely live
      this.finalizeStopped(smidja_id);
      closed += 1;
    }
    // A session that is already terminal but still has `running` phases means a
    // run was finalized (usually by a stop) after its last phase had been closed
    // out of order, or by an older finalizer that left the phase behind. Those
    // phases can never complete — their session is done — so close them as fail.
    closed += this.closeOrphanPhases();
    return closed;
  }

  /** Close any `running` phases whose session is already terminal (success/fail). */
  private closeOrphanPhases(): number {
    const orphans = this.db
      .query<{ smidja_id: string }, []>(
        "SELECT ph.smidja_id FROM phases ph JOIN sessions s ON s.smidja_id = ph.smidja_id " +
          "WHERE ph.status = 'running' AND s.status IN ('success','fail')",
      )
      .all();
    if (orphans.length === 0) return 0;
    this.ensureWriter();
    const now = new Date().toISOString();
    this.writer!.exec("BEGIN");
    try {
      for (const { smidja_id } of orphans) {
        this.writer!
          .query(
            "UPDATE phases SET status = 'fail', error = COALESCE(error, 'stopped'), ended_at = ? " +
              "WHERE smidja_id = ? AND status = 'running'",
          )
          .run(now, smidja_id);
      }
      this.writer!.exec("COMMIT");
    } catch (error) {
      this.writer!.exec("ROLLBACK");
      throw error;
    }
    return orphans.length;
  }

  /**
   * Which runs are live right now — the L1 view needs to know a card is
   * running before it offers Pause/Stop. Dead pids (stale open rows) are
   * excluded so a run whose processes have gone is not still offered Stop.
   */
  liveRunIds(): string[] {
    const rows = this.db
      .query<{ smidja_id: string; pid: number }, []>(
        "SELECT DISTINCT smidja_id, pid FROM processes WHERE ended_at IS NULL",
      )
      .all();
    const seen = new Set<string>();
    for (const r of rows) {
      if (pidAlive(r.pid)) seen.add(r.smidja_id);
    }
    return [...seen];
  }

  /**
   * Decisions — the self-improving surface. Groups the trace by failure class
   * and model so an operator can see what to change to make the system work
   * better, not just that it failed.
   */
  decisions(): DecisionsResponse {
    if (!this.hasTable("sessions")) {
      return { total_failed: 0, decisions: [], generated_at: new Date().toISOString() };
    }
    const failed = this.db
      .query<{ smidja_id: string; smidja_name: string; model: string | null; phase: string; error: string; ran_at: string }, []>(
        `SELECT s.smidja_id, s.smidja_name, ag.model, ph.name AS phase, ph.error,
                COALESCE(s.started_at, '') AS ran_at
         FROM sessions s
         JOIN phases ph ON ph.smidja_id = s.smidja_id AND ph.status = 'fail'
         LEFT JOIN agent_sessions ag ON ag.smidja_id = s.smidja_id AND ag.agent = ph.owner
         WHERE s.status IN ('fail','running')
         ORDER BY s.started_at DESC`,
      )
      .all();

    const buckets = new Map<string, DecisionsBucket>();
    for (const row of failed) {
      const cls = classifyFailure(row.phase, row.error);
      const key = `${cls}|${row.model ?? 'unknown'}`;
      if (!buckets.has(key)) {
        buckets.set(key, {
          diagnosis: cls,
          model: row.model ?? 'unknown',
          count: 0,
          last_seen: '',
          runs: [],
          fix: FIXES[cls] ?? 'inspect the run',
        });
      }
      const b = buckets.get(key)!;
      b.count += 1;
      b.runs.push(row.smidja_id);
      if (row.ran_at > b.last_seen) b.last_seen = row.ran_at;
    }
    const decisions = [...buckets.values()].toSorted((a, b) => b.count - a.count);
    const total_failed = failed.length;
    return { total_failed, decisions, generated_at: new Date().toISOString() };
  }

  /**
   * Statistics — runs, tokens, cost, cache-hit ratio, and commercial savings.
   * The token metrics follow the LLM Token Optimization template
   * (assets/llm tokens optimization.md): cache-hit ratio = cached reads /
   * total ingested; commercial savings compare actual spend against OpenAI
   * GPT-4o and Google Gemini rates.
   */
  stats(): StatsResponse {
    if (!this.hasTable("sessions")) {
      const empty = {
        runs: 0, success: 0, fail: 0, running: 0, tokens: 0, cost: 0,
      };
      return {
        totals: empty,
        usage: { input: 0, output: 0, cache_read: 0, cache_write: 0, total: 0 },
        cache_hit_ratio: 0,
        avg_cache_hit_per_run: 0,
        vendors: { gpt4o: { cached_cost: 0, total_cost: 0, savings: 0, savings_pct: 0 }, gemini: { cached_cost: 0, total_cost: 0, savings: 0, savings_pct: 0 } },
        vendor_catalog: [],
        providers: { local: { events: 0, sessions: 0, tokens: 0, cost: 0, input: 0, output: 0, cache_read: 0 }, online: { events: 0, sessions: 0, tokens: 0, cost: 0, input: 0, output: 0, cache_read: 0 }, per_model: [] },
        by_chain: [],
        by_model: [],
        generated_at: new Date().toISOString(),
      };
    }
    const sessions = this.db
      .query<{ smidja_id: string; smidja_name: string; status: string | null; engineer: string | null; total_tokens: number | null; total_cost: number | null; started_at: string | null }, []>(
        `SELECT smidja_id, smidja_name, status, engineer, total_tokens, total_cost, started_at
         FROM sessions ORDER BY started_at DESC`,
      )
      .all();

    const totals = { runs: 0, success: 0, fail: 0, running: 0, tokens: 0, cost: 0 };
    for (const s of sessions) {
      totals.runs += 1;
      if (s.status === "success") totals.success += 1;
      else if (s.status === "fail") totals.fail += 1;
      else if (s.status === "running") totals.running += 1;
      totals.tokens += s.total_tokens ?? 0;
      totals.cost += s.total_cost ?? 0;
    }

    // token breakdown + cache-hit ratio from agent_end events (per agent),
    // plus per-model attribution so stats can split local vs online.
    const usage = {
      input: 0, output: 0, cache_read: 0, cache_write: 0, total: 0,
    };
    const cacheHitRuns: number[] = [];
    interface ModelAgg {
      events: number;
      sessions: Set<string>;
      tokens: number;
      cost: number;
      input: number;
      output: number;
      cache_read: number;
      coding_agent: string | null;
    }
    const modelAggs = new Map<string, ModelAgg>();
    // agent_start carries the model/coding_agent for the agent_end that follows.
    const agentModel = new Map<string, string | null>();
    const agentCoding = new Map<string, string | null>();
    // Every model that ever STARTED — so runs that never reported usage (no
    // agent_end telemetry, e.g. some scouts) still land in the per-model list.
    const started = new Map<string, { events: number; sessions: Set<string>; coding_agent: string | null }>();
    const emptyAgg = (): ModelAgg => ({
      events: 0, sessions: new Set(), tokens: 0, cost: 0,
      input: 0, output: 0, cache_read: 0, coding_agent: null,
    });
    for (const s of sessions) {
      const evs = this.eventsRaw(s.smidja_id);
      let r = 0, t = 0;
      for (const e of evs) {
        if (e.type === "agent_start") {
          const sp = e.payload as { model?: string; coding_agent?: string };
          if (sp?.model) {
            const key = `${s.smidja_id}|${e.name}`;
            if (!agentModel.has(key)) {
              const st = started.get(sp.model) ?? { events: 0, sessions: new Set<string>(), coding_agent: sp.coding_agent ?? null };
              st.events += 1;
              st.sessions.add(s.smidja_id);
              st.coding_agent = sp.coding_agent ?? st.coding_agent;
              started.set(sp.model, st);
            }
            agentModel.set(key, sp.model);
            agentCoding.set(key, sp.coding_agent ?? null);
          }
          continue;
        }
        if (e.type !== "agent_end") continue;
        const p = e.payload as { usage?: { input_tokens?: number; output_tokens?: number; cache_read_tokens?: number; cache_write_tokens?: number; total_tokens?: number; input_cost?: number; output_cost?: number; cache_read_cost?: number; cache_write_cost?: number }; cost?: number };
        const u = p?.usage;
        if (!u) continue;
        usage.input += u.input_tokens ?? 0;
        usage.output += u.output_tokens ?? 0;
        usage.cache_read += u.cache_read_tokens ?? 0;
        usage.cache_write += u.cache_write_tokens ?? 0;
        usage.total += u.total_tokens ?? 0;
        r += u.cache_read_tokens ?? 0;
        t += (u.input_tokens ?? 0) + (u.cache_read_tokens ?? 0);
        const model = e.name ? agentModel.get(`${s.smidja_id}|${e.name}`) : undefined;
        if (!model) continue;
        const usageCost = (u.input_cost ?? 0) + (u.output_cost ?? 0) + (u.cache_read_cost ?? 0) + (u.cache_write_cost ?? 0);
        const agg = modelAggs.get(model) ?? emptyAgg();
        agg.events += 1;
        agg.sessions.add(s.smidja_id);
        agg.tokens += u.total_tokens ?? 0;
        agg.cost += usageCost || (p.cost ?? 0);
        agg.input += u.input_tokens ?? 0;
        agg.output += u.output_tokens ?? 0;
        agg.cache_read += u.cache_read_tokens ?? 0;
        const coding = e.name ? agentCoding.get(`${s.smidja_id}|${e.name}`) : undefined;
        agg.coding_agent = coding ?? agg.coding_agent;
        modelAggs.set(model, agg);
      }
      if (t > 0) cacheHitRuns.push(r / t);
    }

    // Runs that started but never reported usage get listed with calls only
    // (tokens/cost 0) instead of vanishing from the panel.
    for (const [model, st] of started) {
      if (modelAggs.has(model)) continue;
      const agg = emptyAgg();
      agg.events = st.events;
      agg.sessions = st.sessions;
      agg.coding_agent = st.coding_agent;
      modelAggs.set(model, agg);
    }
    const ingested = usage.input + usage.cache_read;
    const cacheHitRatio = ingested > 0 ? usage.cache_read / ingested : 0;

    // commercial savings (rates per 1M from the tokens-optimization spec)
    const vendor = (pin: number, pcr: number, po: number) => {
      const std = (usage.input / 1_000_000) * pin;
      const cached = (usage.cache_read / 1_000_000) * pcr;
      const out = (usage.output / 1_000_000) * po;
      const total = std + cached + out;
      const savings = total - totals.cost;
      // "% saved" = what we did not pay, as a share of what the vendor would charge
      const savings_pct = total > 0 ? savings / total : 0;
      return { cached_cost: cached, total_cost: total, savings, savings_pct };
    };
    const gpt4o = vendor(2.5, 1.25, 10.0);
    const gemini = vendor(1.25, 0.3125, 5.0);

    // Every catalog model, computed against the same usage — the UI's
    // dropdown lets an operator ask "what would THIS run have cost on X?".
    const vendor_catalog = VENDOR_MODELS.map((m) => {
      const v = vendor(m.pin, m.pin * m.cache, m.po);
      return {
        id: m.id,
        name: m.name,
        provider: m.provider,
        tier: m.tier,
        rank: m.rank,
        tier_label: TIER_LABEL[m.tier],
        input_price: m.pin,
        output_price: m.po,
        cache_price: m.pin * m.cache,
        ...v,
      };
    });

    // local vs online rollup — local = own hardware (LM Studio/Ollama/… via
    // pi and other local runners), online = cloud APIs.
    const providerAgg = () => ({ events: 0, sessions: 0, tokens: 0, cost: 0, input: 0, output: 0, cache_read: 0 });
    const providers = { local: providerAgg(), online: providerAgg() };
    for (const [model, agg] of modelAggs) {
      const p = providers[isLocalModel(model) ? "local" : "online"];
      p.events += agg.events;
      p.sessions += agg.sessions.size;
      p.tokens += agg.tokens;
      p.cost += agg.cost;
      p.input += agg.input;
      p.output += agg.output;
      p.cache_read += agg.cache_read;
    }
    const per_model: ModelProviderStat[] = [...modelAggs.entries()]
      .map(([model, agg]) => ({
        model,
        kind: isLocalModel(model) ? ("local" as const) : ("online" as const),
        coding_agent: agg.coding_agent,
        events: agg.events,
        tokens: agg.tokens,
        cost: agg.cost,
      }))
      .toSorted((a, b) => b.tokens - a.tokens);

    // per-chain and per-model rollups
    const byChain = new Map<string, { runs: number; success: number; tokens: number; cost: number }>();
    const byModel = new Map<string, { runs: number; success: number; tokens: number; cost: number }>();
    for (const s of sessions) {
      const chain = (s.smidja_name ?? "smidja").split(" + ")[0];
      const chainAgg = byChain.get(chain) ?? { runs: 0, success: 0, tokens: 0, cost: 0 };
      chainAgg.runs += 1;
      if (s.status === "success") chainAgg.success += 1;
      chainAgg.tokens += s.total_tokens ?? 0;
      chainAgg.cost += s.total_cost ?? 0;
      byChain.set(chain, chainAgg);

      const modelAgg = byModel.get(s.smidja_name ?? "?") ?? { runs: 0, success: 0, tokens: 0, cost: 0 };
      modelAgg.runs += 1;
      if (s.status === "success") modelAgg.success += 1;
      modelAgg.tokens += s.total_tokens ?? 0;
      modelAgg.cost += s.total_cost ?? 0;
      byModel.set(s.smidja_name ?? "?", modelAgg);
    }

    return {
      totals,
      usage,
      cache_hit_ratio: cacheHitRatio,
      avg_cache_hit_per_run: cacheHitRuns.length ? cacheHitRuns.reduce((a, b) => a + b, 0) / cacheHitRuns.length : 0,
      vendors: { gpt4o, gemini },
      vendor_catalog,
      providers: { ...providers, per_model },
      by_chain: [...byChain.entries()].map(([chain, agg]) => Object.assign({ chain }, agg)).toSorted((a, b) => b.runs - a.runs),
      by_model: [...byModel.entries()].map(([model, agg]) => Object.assign({ model }, agg)).toSorted((a, b) => b.runs - a.runs),
      generated_at: new Date().toISOString(),
    };
  }

  /** Sessions, most recent first, each with its phase statuses for the progress dots. */
  sessions(limit = 200, includeAll = false): SessionSummary[] {
    // Fresh/new db: no schema yet — the tracer creates it on first agent run.
    // Return an empty list instead of crashing on "no such table: sessions".
    if (!this.hasTable("sessions")) return [];
    // includeAll restores the old list behavior: every run (archived ones and
    // Kaia's plumbing one-shots) is listed, so the chat sidebar's "Past
    // sessions" shows everything. Additive — the default stays the current
    // cleaned list.
    const filters: string[] = [];
    if (!includeAll) {
      const admission = this.admissionFilter().replace(/^ AND /, ""); // keeps its own leading " AND " -> strip for the JOIN
      filters.push(
        `COALESCE(${this.hasColumn("sessions", "archived") ? "archived" : "0"}, 0) = 0`,
        admission,
      );
    }
    const clean = filters.filter(Boolean);
    const where = clean.length ? `WHERE ${clean.join(" AND ")}` : "";
    const rows = this.db
      .query<Session, [number]>(
        `SELECT smidja_id, ${this.optionalColumn("sessions", "smidja_name")}, request,
                status, engineer, started_at, ended_at,
                total_tokens, total_cost,
                ${this.optionalColumn("sessions", "archived")}
           FROM sessions
          ${where}
          ORDER BY started_at DESC, rowid DESC
          LIMIT ?`,
      )
      .all(clamp(limit, 1, MAX_LIMIT));

    if (rows.length === 0) return [];

    // Embed each session's phases so the L1 progress dots cost no extra request.
    const ids = rows.map((row) => row.smidja_id);
    const placeholders = ids.map(() => "?").join(", ");
    const phaseRows = this.db
      .query<Phase, string[]>(
        `SELECT phase_id, smidja_id, seq, name, kind, owner, description, status,
                attempt, retries, error, started_at, ended_at
           FROM phases WHERE smidja_id IN (${placeholders}) ORDER BY seq, rowid`,
      )
      .all(...ids);

    const byAdw = new Map<string, Phase[]>();
    for (const phase of phaseRows) {
      const list = byAdw.get(phase.smidja_id);
      if (list) list.push(phase);
      else byAdw.set(phase.smidja_id, [phase]);
    }

    // Agents come along too: an L1 card draws a per-agent dot timeline, and its
    // dots are colored per agent — without this it would be one request per card.
    const agentsByAdw = this.agentsFor(ids);

    const summaries: SessionSummary[] = [];
    for (const session of rows) {
      const phases = byAdw.get(session.smidja_id) ?? [];
      summaries.push(
        Object.assign(session, {
          phases,
          phase_count: phases.length,
          agents: agentsByAdw.get(session.smidja_id) ?? [],
          // Derived from the session's first agent for the chat sidebar's past
          // list (SessionLaunch.model) — null when the db predates the column.
          model: agentsByAdw.get(session.smidja_id)?.[0]?.model ?? null,
        }),
      );
    }
    return summaries;
  }

  session(adwId: string): Session | null {
    return (
      this.db
        .query<Session, [string]>(
          `SELECT smidja_id, ${this.optionalColumn("sessions", "smidja_name")}, request,
                  status, engineer, started_at, ended_at,
                  total_tokens, total_cost
             FROM sessions WHERE smidja_id = ?`,
        )
        .get(adwId) ?? null
    );
  }

  phases(adwId: string): Phase[] {
    return this.db
      .query<Phase, [string]>(
        `SELECT phase_id, smidja_id, seq, name, kind, owner, description, status,
                attempt, retries, error, started_at, ended_at
           FROM phases WHERE smidja_id = ? ORDER BY seq, rowid`,
      )
      .all(adwId);
  }

  agentSessions(adwId: string): AgentSession[] {
    return this.agentsFor([adwId]).get(adwId) ?? [];
  }

  /**
   * Agents per session, for a set of ids at once: the agent_sessions rows plus
   * anything that has started but not finished.
   *
   * agents.py writes the agent_sessions row only after the envelope persists, so
   * a running agent has no row there — precisely the case the live view exists
   * for. Its model, color and session_id are already on the agent_start event,
   * so a lane is labelled and colored from the moment the agent spawns.
   */
  private agentsFor(adwIds: string[]): Map<string, AgentSession[]> {
    const byAdw = new Map<string, AgentSession[]>();
    if (adwIds.length === 0) return byAdw;
    const placeholders = adwIds.map(() => "?").join(", ");

    const append = (adwId: string, agent: AgentSession) => {
      const list = byAdw.get(adwId);
      if (list) list.push(agent);
      else byAdw.set(adwId, [agent]);
    };

    const color = this.optionalColumn("agent_sessions", "color");
    const ctxUsed = this.optionalColumn("agent_sessions", "context_tokens");
    const ctxWindow = this.optionalColumn("agent_sessions", "context_window");

    const completed = this.db
      .query<AgentSession, string[]>(
        `SELECT smidja_id, agent, coding_agent, model, session_id, ${color},
                ${ctxUsed}, ${ctxWindow}, created_at, last_used_at
           FROM agent_sessions WHERE smidja_id IN (${placeholders})
          ORDER BY created_at, agent`,
      )
      .all(...adwIds);
    for (const row of completed) append(row.smidja_id, row);

    const started = this.db
      .query<
        {
          smidja_id: string;
          agent: string | null;
          payload_json: string | null;
          started_at: string | null;
        },
        string[]
      >(
        `SELECT e.smidja_id, p.owner AS agent, e.payload_json, e.started_at
           FROM events e JOIN phases p ON p.phase_id = e.phase_id
          WHERE e.smidja_id IN (${placeholders}) AND e.type = 'agent_start'
          ORDER BY e.rowid`,
      )
      .all(...adwIds);

    for (const row of started) {
      if (!row.agent) continue;
      // A finished row is authoritative; only fill genuine gaps.
      if (byAdw.get(row.smidja_id)?.some((a) => a.agent === row.agent)) continue;
      let payload: AgentStartPayload = {};
      try {
        payload = JSON.parse(row.payload_json ?? "{}") as AgentStartPayload;
      } catch {
        // A malformed payload just means no label — never a failed request.
      }
      append(row.smidja_id, {
        smidja_id: row.smidja_id,
        agent: row.agent,
        coding_agent: null,
        model: payload.model ?? null,
        session_id: payload.session_id ?? null,
        color: payload.color ?? null,
        // Occupancy is only known once the agent's turn closes.
        context_tokens: null,
        context_window: null,
        created_at: row.started_at,
        last_used_at: row.started_at,
      });
    }
    return byAdw;
  }

  /** Session + phases + agents in one shot — L2 needs all three to draw lanes. */
  sessionDetail(adwId: string): SessionDetail | null {
    const session = this.session(adwId);
    if (!session) return null;

    return {
      session,
      usage: this.usage(adwId),
      phases: this.phases(adwId),
      agents: this.agentSessions(adwId),
    };
  }

  /**
   * Raw tokens read and written, beside the billed headline.
   *
   * Derived from the `agent_end` payloads rather than stored, so every run
   * already in the db gets the split without a migration or a re-run.
   *
   * `total_tokens` is a SPEND number: every turn re-sends the whole
   * conversation, so an 86k conversation over 49 turns bills millions. These
   * two say what actually moved — material read for the first time, and
   * material generated. The gap between them and the headline is cached
   * re-reads, which is usually most of it.
   */
  usage(adwId: string): SessionUsage {
    const rows = this.db
      .query<{ payload_json: string | null }, [string]>(
        "SELECT payload_json FROM events WHERE smidja_id = ? AND type = 'agent_end'",
      )
      .all(adwId);

    let read = 0;
    let written = 0;
    for (const row of rows) {
      if (!row.payload_json) continue;
      try {
        const u = (JSON.parse(row.payload_json) as { usage?: Record<string, number> }).usage;
        if (!u) continue;
        // RAW reads only: material entering the context for the first time,
        // billed either as uncached input or as a cache write. Cache reads are
        // the same tokens served again on later turns — counting them here
        // would rebuild the very inflation this split exists to expose.
        read += (u.input_tokens ?? 0) + (u.cache_write_tokens ?? 0);
        written += u.output_tokens ?? 0;
      } catch {
        /* a payload written by an older tracer simply contributes nothing */
      }
    }
    return { read, written };
  }

  /**
   * The polling query. Rowid cursor, insertion order, bounded page — the same
   * mechanism serves the live tail and lazy-paged history.
   */
  /**
   * All raw events for a session — the full record, not a page. Used by the
   * stats rollups (token breakdown per agent_end).
   */
  eventsRaw(adwId: string): { type: string; name: string | null; payload: Record<string, unknown> }[] {
    const rows = this.db
      .query<{ type: string; name: string | null; payload_json: string | null }, [string]>(
        "SELECT type, name, payload_json FROM events WHERE smidja_id = ? ORDER BY rowid",
      )
      .all(adwId);
    return rows.map((r) => ({ type: r.type, name: r.name, payload: (r.payload_json ? JSON.parse(r.payload_json) : {}) as Record<string, unknown> }));
  }

  events(adwId: string, after = 0, limit = DEFAULT_LIMIT): EventsPage {
    const cappedLimit = clamp(limit, 1, MAX_LIMIT);
    const events = this.db
      .query<Event, [string, number, number]>(
        `SELECT rowid, event_id, smidja_id, phase_id, parent_id, type, name,
                payload_json, tokens, started_at, ended_at
           FROM events
          WHERE smidja_id = ? AND rowid > ?
          ORDER BY rowid
          LIMIT ?`,
      )
      .all(adwId, Math.max(0, after), cappedLimit);

    return {
      events,
      cursor: events.length > 0 ? events[events.length - 1]!.rowid : Math.max(0, after),
      has_more: events.length === cappedLimit,
    };
  }

  envelopes(adwId: string): Envelope[] {
    return this.db
      .query<Envelope, [string]>(
        `SELECT envelope_id, smidja_id, phase_id, agent, output_type, payload_json,
                valid, attempt, created_at
           FROM envelopes WHERE smidja_id = ? ORDER BY created_at, rowid`,
      )
      .all(adwId);
  }

  gates(adwId: string): GateResult[] {
    const checks = this.optionalColumn("gate_results", "checks_json");
    return this.db
      .query<GateResult, [string]>(
        `SELECT id, smidja_id, phase_id, attempt, gate, passed, violations_json,
                ${checks}, created_at
           FROM gate_results WHERE smidja_id = ? ORDER BY id`,
      )
      .all(adwId);
  }

  sessionCount(includeAll = false): number {
    // Fresh/new db: no schema yet — the tracer creates it on first agent run.
    if (!this.hasTable("sessions")) return 0;
    // includeAll mirrors sessions(limit, includeAll): count every run so the
    // "Past sessions" total agrees with ?scope=all. Default stays the cleaned
    // count. Additive.
    const where = includeAll ? "" : `WHERE 1=1 ${this.admissionFilter()}`;
    const row = this.db
      .query<{ n: number }, []>(`SELECT COUNT(*) AS n FROM sessions ${where}`)
      .get();
    return row?.n ?? 0;
  }
}

function clamp(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  return Math.min(max, Math.max(min, Math.trunc(value)));
}

/**
 * Is a pid still in the process table? `kill(pid, 0)` sends no signal and only
 * probes: it succeeds if the process exists (or is a zombie we can't reap), and
 * throws ESRCH once it is gone. It is the cheapest reliable liveness check and
 * is what the Stop/Pause endpoints trust before they signal anything.
 */
function pidAlive(pid: number): boolean {
  if (!Number.isInteger(pid) || pid <= 1) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return (error as NodeJS.ErrnoException).code === "EPERM"; // exists but owned by other
  }
}
