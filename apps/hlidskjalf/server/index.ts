/**
 * Hlidskjalf gate API — a read-only view of the Brokk runtime (plan 29).
 *
 * The runtime is file-based: state/, config/, workspace/memory/, .agents/. This
 * server reads those artifacts and the runtime status scripts, and serves the
 * shapes the SPA already declares in src/services/api.ts. It is read-only; no
 * endpoint mutates the runtime.
 *
 *   bun run apps/hlidskjalf/server/index.ts        # API on :3889
 *   PORT=3889 bun run server/index.ts
 */
import { appendFileSync, existsSync, mkdirSync, readFileSync, readdirSync, statSync, unlinkSync, writeFileSync } from 'node:fs';

import { Database } from 'bun:sqlite';
import { basename, dirname, extname, join, relative, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { homedir } from 'node:os';
import { createVoiceHandler, voiceAccess } from './voice.ts';
import { createRoddHandler } from './rodd.ts';
import { serverSeats as resolveServerSeats } from './server-seats.ts';
import { A2A_PROTOCOL, type AgentInterface } from '../../../packages/contracts/src/index.ts';
import { readDigest } from './digest.ts';
import { readSoakHealth } from './health.ts';

const PORT = Number(process.env.PORT ?? 3889);
const HERE = import.meta.dir;
const ROOT = resolve(HERE, '../../..'); // the checkout this app is served from
const AGENTS_DIR = join(ROOT, '.agents/agents');
const SUBAGENTS_DIR = join(ROOT, '.agents/subagents');
const AGENTS_ALT = existsSync(AGENTS_DIR) ? AGENTS_DIR : SUBAGENTS_DIR;
const CONFIG_DIR = join(ROOT, '.agents/config');
const STATE_DIR = join(ROOT, 'state');
// The ledger lives in the HOARD, never in the checkout (Rule 04 / migration
// 0004): $YMIR_HOARD, else $YMIR_HOME/hodd, else the recorded home's hodd.
/** $YMIR_HOME — the hoard's home: env -> the recorded choice -> ONE default
 * (Rule 07; bin/vault/hoard-lib.sh owns the record file and the default name). */
const HOME_DIR = process.env.YMIR_HOME ?? (() => {
  try {
    const rec = readFileSync(join(process.env.XDG_CONFIG_HOME ?? join(homedir(), '.config'), 'ymir', 'home'), 'utf8').trim().split('\n')[0].trim();
    if (rec) return rec;
  } catch {
    // no record yet — fall through to the one documented default
  }
  return join(homedir(), 'Documents', 'ymirhome');
})();
const HOARD = process.env.YMIR_HOARD ?? join(process.env.YMIR_HOME ?? join(homedir(), 'Documents', 'ymirhome'), 'hodd');
const RUNES = join(HOARD, 'memory/runes_audit.md');
const rodd = createRoddHandler({ root: ROOT, home: process.env.SKIRNIR_HOME ?? HOME_DIR });
const voice = createVoiceHandler({ root: ROOT, home: process.env.SKIRNIR_HOME ?? HOME_DIR,
  temp: process.env.SKIRNIR_VOICE_TMP ?? join(HOARD, 'state/runtime/skirnir-voice') });
const WELL = join(ROOT, '.agents/memory/well/episodes.jsonl');
// The engram store lives in the hoard (never the tree); the well lane reads its
// supersede TIMESTAMPS only — never a fact's text (plan 60 Part 9's ward).
const WELL_DB = join(HOARD, 'memory/kaia.engram');
const MASTERPLAN = join(ROOT, 'docs/masterplan.md');

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });

/* ---- Gná, the mail desk (plan 116) ---------------------------------------- *
 * The desk is a service of its own on loopback (hodd/bin/gna-agent/gna_desk.py),
 * not a branch inside this file: mail carries a per-account security boundary and
 * that must not live in a 2,700-line monolith. This gate only forwards, with the
 * desk's own token, and passes its refusals through unchanged — an account-less
 * query answers 400 naming what is missing, never an empty queue. */
// The desk's address: one door, one port fact. GNA_DESK_URL wins; else the port
// the desk itself defaults to (GNA_DESK_PORT, 8494 — the register in
// .agents/config/units.yaml retires 8490). The gate asked 8490 while the desk
// listened on 8494, so every mail surface read "the desk did not answer"
// (measured 2026-11-14, plan 275 item 25).
const MAIL_DESK =
  process.env.GNA_DESK_URL ?? `http://127.0.0.1:${process.env.GNA_DESK_PORT ?? '8494'}`;
const MAIL_TOKEN_FILE = join(HOARD, 'state/gna-desk.token');

function mailDeskToken(): string {
  try {
    return readFileSync(MAIL_TOKEN_FILE, 'utf8').trim();
  } catch {
    return '';
  }
}

async function mailDesk(path: string, params: Record<string, string> = {}): Promise<Response> {
  const token = mailDeskToken();
  if (!token) {
    return json({
      error: 'the desk has no token yet — raise it with: python3 hodd/bin/gna-agent/gna_desk.py',
    }, 503);
  }
  const qs = new URLSearchParams(params).toString();
  try {
    const r = await fetch(`${MAIL_DESK}${path}${qs ? `?${qs}` : ''}`, {
      headers: { authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(15000),
    });
    const body = await r.json().catch(() => ({ error: 'the desk sent no JSON' }));
    return json(body, r.status);
  } catch (e) {
    return json({ error: `the desk did not answer at ${MAIL_DESK}: ${(e as Error).message}` }, 503);
  }
}

function read(path: string): string {
  try {
    return readFileSync(path, 'utf8');
  } catch {
    return '';
  }
}

function run(cmd: string[]): string {
  try {
    // Bound every runtime probe so a stuck script can never hang a request.
    const p = Bun.spawnSync(['timeout', '12', ...cmd], {
      cwd: ROOT,
      stdout: 'pipe',
      stderr: 'pipe',
    });
    return new TextDecoder().decode(p.stdout ?? new Uint8Array()).trim();
  } catch {
    return '';
  }
}

/* ---- caches: a request must never re-scan a growing file or re-spawn ------- *
 * The gate reads append-only ledgers and probes live runtime scripts on every
 * request. Both grow without bound, so an uncached read is O(file) per request.
 * These two helpers memoise the reads and move the probes off the event loop. */
const MEMO = new Map<string, { t: number; v: unknown }>();
const INFLIGHT = new Map<string, Promise<unknown>>();

/** Serve a repeated pure read from memory for `ttlMs`. */
function memo<T>(key: string, ttlMs: number, fn: () => T): T {
  const hit = MEMO.get(key);
  const now = Date.now();
  if (hit && now - hit.t < ttlMs) return hit.v as T;
  const v = fn();
  MEMO.set(key, { t: now, v });
  return v;
}

/** Async memo: concurrent callers share one in-flight promise, never a throng. */
function memoAsync<T>(key: string, ttlMs: number, fn: () => Promise<T>): Promise<T> {
  const hit = MEMO.get(key);
  const now = Date.now();
  if (hit && now - hit.t < ttlMs) return Promise.resolve(hit.v as T);
  const running = INFLIGHT.get(key);
  if (running) return running as Promise<T>;
  const p = fn()
    .then((v) => {
      MEMO.set(key, { t: Date.now(), v });
      INFLIGHT.delete(key);
      return v;
    })
    .catch((e) => {
      INFLIGHT.delete(key);
      throw e;
    });
  INFLIGHT.set(key, p);
  return p;
}

/** Read-only subprocess probe, off the event loop. `timeout` still bounds a
 *  stuck script, but the loop is never blocked waiting on it, and a brief cache
 *  means concurrent polls share one spawn. Mutating actions keep `run()`. */
async function runAsync(cmd: string[], ttlMs = 3000, killAfterS = 12): Promise<string> {
  return memoAsync('run:' + cmd.join('\u0000'), ttlMs, async () => {
    try {
      const proc = Bun.spawn(['timeout', String(killAfterS), ...cmd], {
        cwd: ROOT,
        stdout: 'pipe',
        stderr: 'pipe',
      });
      const out = await new Response(proc.stdout).text();
      await proc.exited;
      return out.trim();
    } catch {
      return '';
    }
  });
}

/* ---- Yggdrasil worktrees ------------------------------------------------- */
async function worktrees(): Promise<Array<{ id: string; branch: string; path: string; head: string; agent: string }>> {
  const out = await runAsync(['git', 'worktree', 'list', '--porcelain']);
  const rows: Array<{ id: string; branch: string; path: string; head: string; agent: string }> = [];
  let cur: { path?: string; head?: string; branch?: string } = {};
  const push = () => {
    if (!cur.path) return;
    const p = cur.path;
    const id = p.includes('/.yggdrasil/') ? p.split('/.yggdrasil/')[1] : '(main)';
    rows.push({ id, branch: cur.branch ?? '-', path: p, head: (cur.head ?? '').slice(0, 8), agent: id === '(main)' ? '-' : id });
  };
  for (const line of out.split('\n')) {
    if (line.startsWith('worktree ')) { push(); cur = { path: line.slice(9).trim() }; }
    else if (line.startsWith('HEAD ')) cur.head = line.slice(5).trim();
    else if (line.startsWith('branch ')) cur.branch = line.slice(7).trim().replace('refs/heads/', '');
    else if (line.trim() === 'detached') cur.branch = 'detached';
  }
  push();
  return rows;
}

/* ---- frontmatter (YAML subset) ------------------------------------------- */
function frontmatter(text: string): Record<string, unknown> {
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  if (!m) return {};
  const out: Record<string, unknown> = {};
  let listKey: string | null = null;
  for (const line of m[1].split('\n')) {
    if (/^\s*-\s+/.test(line) && listKey) {
      (out[listKey] as unknown[]).push(line.replace(/^\s*-\s+/, '').replace(/^["']|["']$/g, ''));
      continue;
    }
    const kv = line.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!kv) continue;
    const [, k, v] = kv;
    if (v === '') {
      out[k] = [];
      listKey = k;
    } else {
      out[k] = v.replace(/^["']|["']$/g, '');
      listKey = null;
    }
  }
  return out;
}

/* ---- /api/agents --------------------------------------------------------- */
function agents() {
  const model = read(join(CONFIG_DIR, 'eindri-harness')).trim() || 'opencode-go/deepseek-v4-flash';
  const files = existsSync(AGENTS_ALT)
    ? readdirSync(AGENTS_ALT).filter((f) => f.endsWith('.md') && f !== 'galdr.md')
    : [];
  return files.map((f) => {
    const text = read(join(AGENTS_ALT, f));
    const fm = frontmatter(text);
    const id = String(fm.name ?? f.replace(/\.md$/, ''));
    const norse = String(fm.norse_name ?? fm.name ?? id);
    // Real, sourced fields only — no fabricated status/trace/tasks.
    const registered = existsSync(join(ROOT, '.opencode/agents', `${id}.md`));
    const a2a: AgentInterface = { protocol: A2A_PROTOCOL, endpoint: `local://${id}`, signed: false };
    return {
      id,
      name: norse.charAt(0).toUpperCase() + norse.slice(1),
      role: String(fm.descriptor ?? fm.role ?? 'agent'),
      realm: 'work',
      domain: String(fm.domain ?? 'ymirlabs'),
      status: registered ? 'nominal' : 'degraded',
      capabilities: Array.isArray(fm.capabilities) ? fm.capabilities : [],
      skills: [],
      interface: a2a,
      model: String(fm.model ?? '') || model,
      uptime: 0,
      tasksDone: 0,
      traceability: 0,
    };
  });
}

/* ---- /api/a2a/messages — the herdr traffic between agents ------------------ *
 * Plan 275 item 8, at the Allfather's word: *"the a2a task stream also should show
 * the herdr communication between agents"*. The sends are recorded by
 * bin/agents/msg-log.sh in the hoard's state root, so this door reads the same file
 * the sender wrote — no second record, no inference. A missing log is an empty list
 * with `recorded: 0`, never a fabricated event, and a torn line is skipped.
 */
const STATE_ROOT = process.env.YMIR_STATE_DIR ?? join(HOME_DIR, 'state');
const FLEET_LOG = join(
  process.env.YMIR_MSG_LOG ?? join(STATE_ROOT, 'fleet/messages.jsonl'),
);

function a2aMessages(limit: number): { messages: unknown[]; recorded: number } {
  let lines: string[] = [];
  try {
    lines = readFileSync(FLEET_LOG, 'utf8').split('\n').filter((l) => l.trim());
  } catch {
    return { messages: [], recorded: 0 };
  }
  const messages: unknown[] = [];
  for (const line of lines.slice(-Math.max(limit, 1))) {
    try {
      messages.push(JSON.parse(line));
    } catch {
      // one torn line never blanks the stream
    }
  }
  // newest first: the panel shows what was just said without scrolling
  return { messages: messages.reverse(), recorded: lines.length };
}

/* ---- /api/tasks (forge orders) ------------------------------------------- */
function orders_uncached() {
  const text = read(MASTERPLAN);
  const out: { id: string; title: string; phase: string; status: string }[] = [];
  const lines = text.split('\n');
  let cur: { id: string; title: string; phase: string; status: string } | null = null;
  for (const line of lines) {
    const h = line.match(/^\*\*(W\d{4}) — (.+?)\*\*\s*$/);
    if (h) {
      if (cur) out.push(cur);
      cur = { id: h[1], title: h[2].trim(), phase: 'P?', status: 'ADDED' };
      continue;
    }
    if (!cur) continue;
    const ph = line.match(/^- Phase:\s*([^·]+)/);
    if (ph) cur.phase = ph[1].trim();
    const st = line.match(/^- Status:\s*([A-Z/]+)/);
    if (st && !/^\+/.test(line)) cur.status = st[1];
    const note = line.match(/^\s*-\s+\d{4}-\d{2}-\d{2}\s+([A-Z]+)\b/);
    if (note) cur.status = note[1];
  }
  if (cur) out.push(cur);
  return out;
}

function orders() {
  return memo('orders', 2000, orders_uncached);
}

function tasks_orders(): Task[] {
  const now = new Date().toISOString();
  return orders().map((o, i) => ({
    id: o.id,
    title: o.title,
    state: o.status === 'COMPLETED' ? 'COMPLETED' : o.status === 'BLOCKED' ? 'INPUT_REQUIRED' : 'WORKING',
    realm: 'wayof' as RealmId,
    agent: 'Brokk',
    agentId: 'brokk',
    order: o.phase,
    progress: o.status === 'COMPLETED' ? 100 : 25,
    startedAt: now,
    updatedAt: now,
    artifacts: [],
    log: [`${o.id} · ${o.status} · ${o.phase}`],
  }));
}

/* ---- the ERRANDS, read from the records the launcher wrote ---------------- *
 * Plan 275 item 17, at the Allfather's word: *"i dont see the herdr tasks here
 * either"*. The board was built ONLY from Forge orders (`docs/masterplan.md`), so
 * nine errands seated in herdr panes left every column empty.
 *
 * The evidence is in the home's state root, and none of it is inferred:
 *   <id>.meta    id, window/herdr_pane_id, harness, model, kind, mode, launched
 *   <id>.status  the agent's own claim — "working: …", "done: …", "failed: …"
 * A task without a `.meta` is not an errand and is never invented here.
 */
// The SPA's own vocabulary (`src/types.ts`). The gate is a single file served by bun,
// which strips types rather than checking them — declaring them here keeps the shape
// written down beside the code that fills it instead of nowhere at all.
type TaskState =
  | 'SUBMITTED' | 'WORKING' | 'COMPLETED' | 'FAILED'
  | 'REJECTED' | 'CANCELED' | 'INPUT_REQUIRED' | 'AUTH_REQUIRED';
type RealmId = string;
interface Task {
  id: string;
  title: string;
  state: TaskState;
  realm: RealmId;
  agent: string;
  agentId: string;
  order: string;
  progress: number;
  startedAt: string;
  updatedAt: string;
  artifacts: string[];
  log: string[];
}

const EIN_STATE_MAP: Record<string, TaskState> = {
  working: 'WORKING',
  launching: 'WORKING',
  seat: 'WORKING',
  seated: 'WORKING',
  running: 'WORKING',
  submitted: 'SUBMITTED',
  pending: 'SUBMITTED',
  queued: 'SUBMITTED',
  paused: 'INPUT_REQUIRED',
  question: 'INPUT_REQUIRED',
  needs: 'INPUT_REQUIRED',
  blocked: 'INPUT_REQUIRED',
  stalled: 'FAILED',
  failed: 'FAILED',
  error: 'FAILED',
  done: 'COMPLETED',
  delivered: 'COMPLETED',
  shipped: 'COMPLETED',
  merged: 'COMPLETED',
  verified: 'COMPLETED',
};

function einState(claim: string): TaskState {
  const head = claim.split(/[\s:]/)[0]?.toLowerCase() ?? '';
  return EIN_STATE_MAP[head] ?? (claim ? 'WORKING' : 'SUBMITTED');
}

function errandTasks(): Task[] {
  let files: string[] = [];
  try {
    files = readdirSync(STATE_ROOT).filter((f) => f.endsWith('.meta'));
  } catch {
    return [];
  }
  const rows: (Task & { launched: number })[] = [];
  for (const f of files) {
    const id = f.slice(0, -5);
    const kv: Record<string, string> = {};
    try {
      for (const line of readFileSync(join(STATE_ROOT, f), 'utf8').split('\n')) {
        const at = line.indexOf('=');
        if (at > 0) kv[line.slice(0, at).trim()] = line.slice(at + 1);
      }
    } catch {
      continue;
    }
    let claims: string[] = [];
    try {
      claims = readFileSync(join(STATE_ROOT, `${id}.status`), 'utf8')
        .split('\n')
        .map((l) => l.trim())
        .filter(Boolean);
    } catch {
      /* an errand that has not spoken yet */
    }
    const claim = claims[claims.length - 1] ?? '';
    const launched = Number(kv.launched ?? 0) || 0;
    const pane = kv.herdr_pane_id || kv.window || '';
    const harness = kv.harness || 'agent';
    const state = einState(claim);
    rows.push({
      id,
      title: id.replace(/-/g, ' '),
      state,
      realm: 'work' as RealmId,
      // WHO is standing in the pane, not the forge's owner: the errand's own launch record.
      agent: `${harness}${kv.model ? ` · ${kv.model}` : ''}`,
      agentId: id,
      order: pane ? `${kv.mode || kv.kind || 'erdri'} · ${pane}` : kv.mode || kv.kind || 'errand',
      progress: state === 'COMPLETED' ? 100 : state === 'WORKING' ? 50 : state === 'SUBMITTED' ? 10 : 0,
      startedAt: launched ? new Date(launched * 1000).toISOString() : '',
      updatedAt: launched ? new Date(launched * 1000).toISOString() : '',
      artifacts: kv.worktree ? [kv.worktree] : [],
      log: [claim || 'no claim yet', `${kv.harness || 'agent'}${kv.model ? ` on ${kv.model}` : ''}${pane ? ` in ${pane}` : ''}`],
      launched,
    });
  }
  // Newest first, and only the tail of the ledger: a board is what is in flight, not
  // a history of every errand this home has ever run (1,000+ records otherwise).
  rows.sort((a, b) => b.launched - a.launched);
  return rows.slice(0, 60).map(({ launched: _l, ...t }) => t);
}

function tasks(): Task[] {
  // The ERRANDS first — they are the live work the Allfather asked to see — then the
  // forge's orders, whose ids are distinct. Neither list is invented from the other.
  const errands = errandTasks();
  const seen = new Set(errands.map((t) => t.id));
  return [...errands, ...tasks_orders().filter((t) => !seen.has(t.id))];
}

/* ---- /api/runes ---------------------------------------------------------- */
function runes_uncached() {
  return read(RUNES)
    .split('\n')
    .filter((l) => l.trim().startsWith('{'))
    .map((l, i) => {
      try {
        const e = JSON.parse(l);
        const level = /fail|error/i.test(e.event ?? '') ? 'danger' : /warn|stale/i.test(e.event ?? '') ? 'warn' : /briefing|written/i.test(e.event ?? '') ? 'ok' : 'info';
        return {
          id: e.checksum ? String(e.checksum).slice(0, 12) : `rune-${i}`,
          ts: e.timestamp ?? '',
          agent: e.actor ?? 'brokk',
          module: e.event ?? '',
          event: e.message ?? '',
          checksum: String(e.checksum ?? '').slice(0, 12),
          realm: e.realm || 'wayof',
          order: e.order ?? '',
          level,
        };
      } catch {
        return null;
      }
    })
    .filter(Boolean)
    .reverse();
}

function runes() {
  return memo('runes', 3000, runes_uncached);
}

/* ---- /api/well ----------------------------------------------------------- */
const MIMIR_URL = process.env.MIMIRSBRUNN_URL ?? 'http://127.0.0.1:4602';

function wellTitle(body: string, i = 0): string {
  return (body.split('\n')[0] ?? '').replace(/^#+\s*/, '').slice(0, 80) || `episode ${i}`;
}

/** The local JSONL well — used when the engram bridge is down. */
function localWell(q = '') {
  const rows = read(WELL)
    .split('\n')
    .filter((l) => l.trim().startsWith('{'))
    .map((l, i) => {
      try {
        const e = JSON.parse(l);
        const body = String(e.content ?? '');
        return {
          id: e.hash ?? `ep-${i}`,
          title: wellTitle(body, i),
          body: body.slice(0, 600),
          score: 0.9,
          mode: 'hybrid',
          agentScope: e.source ?? 'assets/data',
          ts: e.timestamp ?? '',
          tags: Array.isArray(e.tags) ? e.tags : [],
        };
      } catch {
        return null;
      }
    })
    .filter(Boolean) as { title: string; body: string }[];
  const ql = q.toLowerCase();
  const filtered = q ? rows.filter((r) => `${r.title} ${r.body}`.toLowerCase().includes(ql)) : rows;
  return filtered.slice(0, 60).reverse();
}

/** Drink from the well: the engram bridge answers when it is up, else the file. */
async function well(q = '') {
  try {
    const url = q
      ? `${MIMIR_URL}/recall?q=${encodeURIComponent(q)}&k=60`
      : `${MIMIR_URL}/recent?limit=60`;
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (res.ok) {
      const data = (await res.json()) as {
        results?: { score?: number; episode?: { id?: string; content?: string; timestamp?: string; tags?: string[]; actors?: string[]; agent_id?: string } }[];
        episodes?: { id?: string; content?: string; timestamp?: string; tags?: string[]; actors?: string[]; agent_id?: string }[];
      };
      if (data.results) {
        return data.results.map((r) => {
          const e = r.episode ?? {};
          const body = String(e.content ?? '');
          return {
            id: e.id ?? '',
            title: wellTitle(body),
            body: body.slice(0, 600),
            score: r.score ?? 0,
            mode: 'hybrid',
            agentScope: (e.actors ?? [])[0] ?? e.agent_id ?? 'well',
            ts: e.timestamp ?? '',
            tags: e.tags ?? [],
          };
        });
      }
      if (data.episodes) {
        return data.episodes.map((e) => {
          const body = String(e.content ?? '');
          return {
            id: e.id ?? '',
            title: wellTitle(body),
            body: body.slice(0, 600),
            score: 0.9,
            mode: 'recent',
            agentScope: (e.actors ?? [])[0] ?? e.agent_id ?? 'well',
            ts: e.timestamp ?? '',
            tags: e.tags ?? [],
          };
        });
      }
    }
  } catch {
    /* bridge down — fall through to the local file */
  }
  return localWell(q);
}

/* ---- /api/mimir/health --------------------------------------------------- */
// The well lane's decay axis (plan 60 Part 9): the DAYS a fact was superseded,
// read straight from the engram store — timestamps only, never `subject`,
// `predicate`, `object` or episode content. `/api/well` serves episodes, not
// facts; this is the one fact-shaped datum the grid needs, and it carries no
// private text. A missing store is an empty list, and the lane says so.
function wellSupersedeDates(store?: unknown): string[] {
  const dbPath = typeof store === 'string' && store ? store : WELL_DB;
  try {
    if (!existsSync(dbPath)) return [];
    const db = new Database(dbPath, { readonly: true });
    try {
      const rows = db
        .query("select distinct substr(superseded_at,1,10) as d from facts where superseded_at is not null order by d")
        .all() as { d?: string }[];
      return rows.map((r) => r.d ?? '').filter(Boolean);
    } finally {
      db.close();
    }
  } catch {
    return [];
  }
}

async function mimirHealth() {
  let base: Record<string, unknown> = { status: 'down', store: null, episodes: 0, agents: [] };
  try {
    const res = await fetch(`${MIMIR_URL}/health`, { signal: AbortSignal.timeout(4000) });
    if (res.ok) base = (await res.json()) as Record<string, unknown>;
  } catch {
    /* down */
  }
  return { ...base, superseded_dates: wellSupersedeDates(base.store) };
}

/** One full episode from the well — the Allfather reads the whole memory. */
async function wellEpisode(id: string) {
  if (!id) return null;
  try {
    const res = await fetch(`${MIMIR_URL}/episode?id=${encodeURIComponent(id)}`, { signal: AbortSignal.timeout(6000) });
    if (res.ok) return await res.json();
  } catch {
    /* bridge down */
  }
  return null;
}

/* ---- /api/processes ------------------------------------------------------ */
async function processes() {
  const out: unknown[] = [];
  const cron = await runAsync(['bash', 'bin/time/nornir-cron-start.sh', '--status']);
  const bridge = await runAsync(['bash', 'bin/bridge/bifrost-bridge.sh', '--status']);
  out.push({
    id: 'nornir-cron', name: 'Nornir cron', daemon: 'scheduler', manager: 'pm2',
    status: cron.includes('running') ? 'nominal' : 'down', cpu: 0, mem: 12, restarts: 0,
    uptime: 3600, realm: 'platform',
  });
  out.push({
    id: 'bifrost-bridge', name: 'Bifrost model bridge', daemon: 'opencode-go bridge', manager: 'systemd',
    status: bridge.includes('"up"') ? 'nominal' : 'down', cpu: 0, mem: 18, restarts: 0,
    uptime: 3600, realm: 'platform',
  });
  // The fleet's daemons across PM2/Docker/systemd, read-only from Valhalla.
  for (const r of parseToon(await runAsync(['bash', 'bin/agents/valhalla.sh', 'list']))) {
    const st = /running|active|online/i.test(r.status)
      ? 'nominal'
      : /exit|fail|inactive|dead|stop/i.test(r.status)
        ? 'down'
        : 'degraded';
    out.push({
      id: r.id,
      name: r.name,
      daemon: r.manager,
      manager: r.manager,
      status: st,
      cpu: Number(r.cpu) || 0,
      mem: Number(r.mem) || 0,
      restarts: Number(r.restarts) || 0,
      uptime: Number(r.uptime) || 0,
      realm: 'platform',
    });
  }
  return out;
}

/* ---- /api/smidja (the smithy's own trace, read-only) --------------------- */
// The smithy's db lives where the RUNTIME keeps it: $YMIR_HOME first (the data
// belongs outside the repo), else the app tree it moved into. It sat at the repo
// root's old path for a year; when the tree moved, this reader quietly opened
// nothing and every statistic showed zero - a gate with nothing to say.
const SMIDJA_DB = (() => {
  if (process.env.SMIDJA_DB) return process.env.SMIDJA_DB;
  const candidates = [
    join(process.env.YMIR_HOME ?? join(homedir(), 'Documents', 'ymirhome'), 'smidja', 'smidja.db'),
    join(ROOT, 'apps', 'smidja', 'smidja_data', 'smidja.db'),
  ];
  return candidates.find((c) => existsSync(c)) ?? candidates[1];
})();

function smidja(): Database | null {
  try {
    if (!existsSync(SMIDJA_DB)) return null;
    return new Database(SMIDJA_DB, { readonly: true });
  } catch {
    return null;
  }
}

function smidjaHealth() {
  const db = smidja();
  if (!db) return { db: 'absent', sessions: 0 };
  try {
    const r = db.query('select count(*) c from sessions').get() as { c?: number };
    return { db: 'present', sessions: r?.c ?? 0 };
  } catch {
    return { db: 'present', sessions: 0 };
  } finally {
    db.close();
  }
}

function smidjaSessions(limit = 100) {
  const db = smidja();
  if (!db) return [];
  try {
    return db
      .query(
        'select smidja_id, smidja_name, status, engineer, total_tokens, total_cost, started_at, ended_at from sessions order by started_at desc limit ?',
      )
      .all(limit);
  } catch {
    return [];
  } finally {
    db.close();
  }
}

function smidjaSession(id: string) {
  const db = smidja();
  if (!db) return null;
  try {
    const session = db.query('select * from sessions where smidja_id = ?').get(id);
    if (!session) return null;
    return {
      session,
      phases: db.query('select * from phases where smidja_id = ? order by seq, rowid').all(id),
      events: db
        .query('select rowid, event_id, phase_id, parent_id, type, name, payload_json, tokens, started_at, ended_at from events where smidja_id = ? order by rowid limit 2000')
        .all(id),
      envelopes: db.query('select * from envelopes where smidja_id = ? order by created_at, rowid').all(id),
      gates: db.query('select * from gate_results where smidja_id = ? order by id').all(id),
      agents: db.query('select * from agent_sessions where smidja_id = ? order by created_at, agent').all(id),
    };
  } catch {
    return null;
  } finally {
    db.close();
  }
}

function smidjaDecisions() {
  const db = smidja();
  if (!db) return { total_failed: 0, decisions: [] };
  try {
    const decisions = db
      .query(
        "select ph.name phase, ph.error, ag.model, count(*) count from phases ph left join agent_sessions ag on ag.smidja_id=ph.smidja_id and ag.agent=ph.owner where ph.status='fail' group by ph.name, ph.error, ag.model order by count desc",
      )
      .all();
    return { total_failed: decisions.length, decisions };
  } catch {
    return { total_failed: 0, decisions: [] };
  } finally {
    db.close();
  }
}

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

// Commercial model catalog — rates are standard pay-as-you-go API prices per 1M
// tokens (input/output), midpoint where the spec quotes a range. `cache` is the
// share of the input price billed on a cache read (OpenAI/DeepSeek/Meta 50%,
// Google 25%, Anthropic 10%). Ported 1:1 from the Smiðja visualizer db.ts.
const VENDOR_MODELS: VendorModelDef[] = [
  { id: 'gpt-5.5-pro', name: 'GPT-5.5 Pro', provider: 'OpenAI', tier: 1, rank: 1, pin: 30.0, po: 180.0, cache: 0.5 },
  { id: 'o3-pro', name: 'o3-pro', provider: 'OpenAI', tier: 1, rank: 2, pin: 20.0, po: 80.0, cache: 0.5 },
  { id: 'claude-opus', name: 'Claude Opus 4.6 / 5', provider: 'Anthropic', tier: 1, rank: 3, pin: 5.0, po: 25.0, cache: 0.1 },
  { id: 'gpt-5.5', name: 'GPT-5.5', provider: 'OpenAI', tier: 1, rank: 4, pin: 5.0, po: 30.0, cache: 0.5 },
  { id: 'llama-3.1-405b', name: 'Llama 3.1 405B', provider: 'Meta (Hosted)', tier: 1, rank: 5, pin: 3.75, po: 3.75, cache: 0.5 },
  { id: 'gpt-5.4', name: 'GPT-5.4', provider: 'OpenAI', tier: 1, rank: 6, pin: 2.5, po: 15.0, cache: 0.5 },
  { id: 'gpt-4o', name: 'GPT-4o', provider: 'OpenAI', tier: 1, rank: 7, pin: 2.5, po: 10.0, cache: 0.5 },
  { id: 'gemini-3.1-pro', name: 'Gemini 3.1 Pro', provider: 'Google', tier: 1, rank: 8, pin: 2.0, po: 12.0, cache: 0.25 },
  { id: 'o3', name: 'o3', provider: 'OpenAI', tier: 1, rank: 9, pin: 2.0, po: 8.0, cache: 0.5 },
  { id: 'claude-sonnet', name: 'Claude Sonnet 4.6 / 5', provider: 'Anthropic', tier: 1, rank: 10, pin: 2.5, po: 12.5, cache: 0.1 },
  { id: 'mistral-large-3', name: 'Mistral Large 3', provider: 'Mistral AI', tier: 2, rank: 11, pin: 0.5, po: 1.5, cache: 0.5 },
  { id: 'claude-haiku', name: 'Claude Haiku 4.5', provider: 'Anthropic', tier: 2, rank: 12, pin: 1.0, po: 5.0, cache: 0.1 },
  { id: 'gemini-2.5-pro', name: 'Gemini 2.5 Pro', provider: 'Google', tier: 2, rank: 13, pin: 1.25, po: 10.0, cache: 0.25 },
  { id: 'o4-mini', name: 'o4-mini', provider: 'OpenAI', tier: 2, rank: 14, pin: 0.55, po: 2.2, cache: 0.5 },
  { id: 'deepseek-r1', name: 'DeepSeek R1', provider: 'DeepSeek', tier: 2, rank: 15, pin: 0.55, po: 2.19, cache: 0.5 },
  { id: 'gemini-3-flash-preview', name: 'Gemini 3 Flash Preview', provider: 'Google', tier: 2, rank: 16, pin: 0.5, po: 3.0, cache: 0.25 },
  { id: 'command-r-plus', name: 'Command R+', provider: 'Cohere', tier: 2, rank: 17, pin: 2.5, po: 10.0, cache: 0.5 },
  { id: 'gpt-5.4-mini', name: 'GPT-5.4 Mini', provider: 'OpenAI', tier: 2, rank: 18, pin: 0.75, po: 4.5, cache: 0.5 },
  { id: 'deepseek-v4', name: 'DeepSeek V4', provider: 'DeepSeek', tier: 2, rank: 19, pin: 0.3, po: 0.5, cache: 0.5 },
  { id: 'codestral', name: 'Codestral', provider: 'Mistral AI', tier: 2, rank: 20, pin: 0.3, po: 0.9, cache: 0.5 },
  { id: 'deepseek-chat-v3.2', name: 'DeepSeek-Chat (V3.2)', provider: 'DeepSeek', tier: 2, rank: 21, pin: 0.28, po: 0.42, cache: 0.5 },
  { id: 'llama-3.3-70b', name: 'Llama 3.3 70B', provider: 'Meta (Hosted)', tier: 2, rank: 22, pin: 0.41, po: 0.52, cache: 0.5 },
  { id: 'mistral-medium-3.5', name: 'Mistral Medium 3.5', provider: 'Mistral AI', tier: 2, rank: 23, pin: 1.5, po: 7.5, cache: 0.5 },
  { id: 'gpt-4.1', name: 'GPT-4.1', provider: 'OpenAI', tier: 2, rank: 24, pin: 2.0, po: 8.0, cache: 0.5 },
  { id: 'qwen-2.5-72b', name: 'Qwen 2.5 72B', provider: 'Alibaba (Hosted)', tier: 2, rank: 25, pin: 0.35, po: 0.4, cache: 0.5 },
  { id: 'gemini-3.7-flash', name: 'Gemini 3.7 Flash', provider: 'Google', tier: 3, rank: 26, pin: 0.75, po: 3.75, cache: 0.25 },
  { id: 'gemini-3.6-flash', name: 'Gemini 3.6 Flash', provider: 'Google', tier: 3, rank: 27, pin: 0.75, po: 3.75, cache: 0.25 },
  { id: 'gpt-4.1-mini', name: 'GPT-4.1 Mini', provider: 'OpenAI', tier: 3, rank: 28, pin: 0.4, po: 1.6, cache: 0.5 },
  { id: 'llama-4-maverick', name: 'Llama 4 Maverick', provider: 'Meta (Hosted)', tier: 3, rank: 29, pin: 0.25, po: 0.875, cache: 0.5 },
  { id: 'gpt-5-mini', name: 'GPT-5 Mini', provider: 'OpenAI', tier: 3, rank: 30, pin: 0.25, po: 2.0, cache: 0.5 },
  { id: 'gemini-3.1-flash-lite', name: 'Gemini 3.1 Flash-Lite', provider: 'Google', tier: 3, rank: 31, pin: 0.25, po: 1.5, cache: 0.25 },
  { id: 'gpt-5.4-nano', name: 'GPT-5.4 Nano', provider: 'OpenAI', tier: 3, rank: 32, pin: 0.2, po: 1.25, cache: 0.5 },
  { id: 'mistral-small-4', name: 'Mistral Small 4', provider: 'Mistral AI', tier: 3, rank: 33, pin: 0.15, po: 0.6, cache: 0.5 },
  { id: 'gpt-4o-mini', name: 'GPT-4o mini', provider: 'OpenAI', tier: 3, rank: 34, pin: 0.15, po: 0.6, cache: 0.5 },
  { id: 'gpt-4.1-nano', name: 'GPT-4.1 Nano', provider: 'OpenAI', tier: 3, rank: 35, pin: 0.1, po: 0.4, cache: 0.5 },
  { id: 'gemini-2.5-flash-lite', name: 'Gemini 2.5 Flash-Lite', provider: 'Google', tier: 3, rank: 36, pin: 0.1, po: 0.4, cache: 0.25 },
  { id: 'llama-4-scout', name: 'Llama 4 Scout', provider: 'Meta (Hosted)', tier: 3, rank: 37, pin: 0.165, po: 0.5, cache: 0.5 },
  { id: 'ministral-8b', name: 'Ministral 8B', provider: 'Mistral AI', tier: 3, rank: 38, pin: 0.1, po: 0.1, cache: 0.5 },
  { id: 'llama-3.2-3b', name: 'Llama 3.2 3B', provider: 'Meta (Hosted)', tier: 3, rank: 39, pin: 0.02, po: 0.02, cache: 0.5 },
  { id: 'ministral-3b', name: 'Ministral 3B', provider: 'Mistral AI', tier: 3, rank: 40, pin: 0.04, po: 0.04, cache: 0.5 },
];

const TIER_LABEL: Record<number, string> = {
  1: 'Tier 1 — heavyweight flagships & enterprise intelligence',
  2: 'Tier 2 — mid-range & high-efficiency workhorses',
  3: 'Tier 3 — flash, mini & edge engines',
};

const LOCAL_MODEL_PREFIXES = ['lmstudio/', 'ollama/', 'localhost/', 'vllm/', 'unsloth/'];
const isLocalModel = (model: string) =>
  LOCAL_MODEL_PREFIXES.some((p) => model.toLowerCase().startsWith(p));

function emptyStats() {
  const provider = () => ({ events: 0, sessions: 0, tokens: 0, cost: 0, input: 0, output: 0, cache_read: 0 });
  const vendorCost = { cached_cost: 0, total_cost: 0, savings: 0, savings_pct: 0 };
  return {
    totals: { runs: 0, success: 0, fail: 0, running: 0, tokens: 0, cost: 0 },
    usage: { input: 0, output: 0, cache_read: 0, cache_write: 0, total: 0 },
    cache_hit_ratio: 0,
    avg_cache_hit_per_run: 0,
    vendors: { gpt4o: { ...vendorCost }, gemini: { ...vendorCost } },
    vendor_catalog: [] as unknown[],
    providers: { local: provider(), online: provider(), per_model: [] as unknown[] },
    by_chain: [] as unknown[],
    by_model: [] as unknown[],
    generated_at: new Date().toISOString(),
  };
}

/** Statistics — runs, tokens, cost, cache-hit ratio, and commercial savings.
 *  Ported 1:1 from the Smiðja visualizer `db.ts` `stats()`: usage comes from
 *  `agent_end` event payloads, model attribution from `agent_start` events. */
function smidjaStats_uncached() {
  const db = smidja();
  if (!db) return emptyStats();
  try {
    const hasSessions = db
      .query("select name from sqlite_master where type='table' and name='sessions'")
      .get();
    if (!hasSessions) return emptyStats();

    const sessions = db
      .query('select smidja_id, smidja_name, status, engineer, total_tokens, total_cost, started_at from sessions order by started_at desc')
      .all() as Array<{
      smidja_id: string;
      smidja_name: string | null;
      status: string | null;
      engineer: string | null;
      total_tokens: number | null;
      total_cost: number | null;
      started_at: string | null;
    }>;

    const totals = { runs: 0, success: 0, fail: 0, running: 0, tokens: 0, cost: 0 };
    for (const s of sessions) {
      totals.runs += 1;
      if (s.status === 'success') totals.success += 1;
      else if (s.status === 'fail') totals.fail += 1;
      else if (s.status === 'running') totals.running += 1;
      totals.tokens += s.total_tokens ?? 0;
      totals.cost += s.total_cost ?? 0;
    }

    const usage = { input: 0, output: 0, cache_read: 0, cache_write: 0, total: 0 };
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
    const agentModel = new Map<string, string | null>();
    const agentCoding = new Map<string, string | null>();
    const started = new Map<string, { events: number; sessions: Set<string>; coding_agent: string | null }>();
    const emptyAgg = (): ModelAgg => ({
      events: 0,
      sessions: new Set(),
      tokens: 0,
      cost: 0,
      input: 0,
      output: 0,
      cache_read: 0,
      coding_agent: null,
    });

    for (const s of sessions) {
      const evs = db
        .query('select type, name, payload_json from events where smidja_id = ? order by rowid')
        .all(s.smidja_id) as Array<{ type: string; name: string | null; payload_json: string | null }>;
      let r = 0;
      let t = 0;
      for (const e of evs) {
        let payload: Record<string, unknown> = {};
        try {
          payload = e.payload_json ? JSON.parse(e.payload_json) : {};
        } catch {
          payload = {};
        }
        if (e.type === 'agent_start') {
          const sp = payload as { model?: string; coding_agent?: string };
          if (sp?.model) {
            const key = `${s.smidja_id}|${e.name}`;
            if (!agentModel.has(key)) {
              const st =
                started.get(sp.model) ?? { events: 0, sessions: new Set<string>(), coding_agent: sp.coding_agent ?? null };
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
        if (e.type !== 'agent_end') continue;
        const p = payload as {
          usage?: {
            input_tokens?: number;
            output_tokens?: number;
            cache_read_tokens?: number;
            cache_write_tokens?: number;
            total_tokens?: number;
            input_cost?: number;
            output_cost?: number;
            cache_read_cost?: number;
            cache_write_cost?: number;
          };
          cost?: number;
        };
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
        const usageCost =
          (u.input_cost ?? 0) + (u.output_cost ?? 0) + (u.cache_read_cost ?? 0) + (u.cache_write_cost ?? 0);
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

    const vendor = (pin: number, pcr: number, po: number) => {
      const std = (usage.input / 1_000_000) * pin;
      const cached = (usage.cache_read / 1_000_000) * pcr;
      const out = (usage.output / 1_000_000) * po;
      const total = std + cached + out;
      const savings = total - totals.cost;
      const savings_pct = total > 0 ? savings / total : 0;
      return { cached_cost: cached, total_cost: total, savings, savings_pct };
    };
    const gpt4o = vendor(2.5, 1.25, 10.0);
    const gemini = vendor(1.25, 0.3125, 5.0);

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

    const providerAgg = () => ({ events: 0, sessions: 0, tokens: 0, cost: 0, input: 0, output: 0, cache_read: 0 });
    const providers = { local: providerAgg(), online: providerAgg() };
    for (const [model, agg] of modelAggs) {
      const p = providers[isLocalModel(model) ? 'local' : 'online'];
      p.events += agg.events;
      p.sessions += agg.sessions.size;
      p.tokens += agg.tokens;
      p.cost += agg.cost;
      p.input += agg.input;
      p.output += agg.output;
      p.cache_read += agg.cache_read;
    }
    const per_model = [...modelAggs.entries()]
      .map(([model, agg]) => ({
        model,
        kind: isLocalModel(model) ? ('local' as const) : ('online' as const),
        coding_agent: agg.coding_agent,
        events: agg.events,
        tokens: agg.tokens,
        cost: agg.cost,
      }))
      .sort((a, b) => b.tokens - a.tokens);

    const byChain = new Map<string, { runs: number; success: number; tokens: number; cost: number }>();
    const byModel = new Map<string, { runs: number; success: number; tokens: number; cost: number }>();
    for (const s of sessions) {
      const chain = (s.smidja_name ?? 'smidja').split(' + ')[0];
      const chainAgg = byChain.get(chain) ?? { runs: 0, success: 0, tokens: 0, cost: 0 };
      chainAgg.runs += 1;
      if (s.status === 'success') chainAgg.success += 1;
      chainAgg.tokens += s.total_tokens ?? 0;
      chainAgg.cost += s.total_cost ?? 0;
      byChain.set(chain, chainAgg);

      const modelAgg = byModel.get(s.smidja_name ?? '?') ?? { runs: 0, success: 0, tokens: 0, cost: 0 };
      modelAgg.runs += 1;
      if (s.status === 'success') modelAgg.success += 1;
      modelAgg.tokens += s.total_tokens ?? 0;
      modelAgg.cost += s.total_cost ?? 0;
      byModel.set(s.smidja_name ?? '?', modelAgg);
    }

    return {
      totals,
      usage,
      cache_hit_ratio: cacheHitRatio,
      avg_cache_hit_per_run: cacheHitRuns.length ? cacheHitRuns.reduce((a, b) => a + b, 0) / cacheHitRuns.length : 0,
      vendors: { gpt4o, gemini },
      vendor_catalog,
      providers: { ...providers, per_model },
      by_chain: [...byChain.entries()].map(([chain, agg]) => Object.assign({ chain }, agg)).sort((a, b) => b.runs - a.runs),
      by_model: [...byModel.entries()].map(([model, agg]) => Object.assign({ model }, agg)).sort((a, b) => b.runs - a.runs),
      generated_at: new Date().toISOString(),
    };
  } catch {
    return emptyStats();
  } finally {
    db.close();
  }
}

function smidjaStats() {
  return memo('smidjaStats', 3000, smidjaStats_uncached);
}

/* ---- /api/reviews (real PRs + compliance as checks) ---------------------- */
// Glitnir's truth (audited 2026-09-24): the old route could never show an
// APPROVED card (no review state was ever fetched), counted the synthetic lint
// card in "Open PRs", swallowed every gh failure silently, and relied on the
// cwd's git remote for repo detection (a packaged install has no .git, so gh
// found nothing and the board was blank). Now: reviewDecision + mergeable are
// fetched, the repo is passed explicitly, a gh failure is REPORTED not
// swallowed, and the payload distinguishes real PR cards from the lint card.
async function reviews() {
  const cards: unknown[] = [];
  let ghError = '';

  // 1. Real pull requests — Glitnir's cards. `--repo` is explicit so the read
  //    works from a packaged install (no .git to detect a remote from); the
  //    default is the repo itself (Rule 07 — one documented default).
  try {
    const repo =
      (run(['git', '-C', ROOT, 'remote', 'get-url', 'origin']).match(/[:/]([^/:]+\/[^/]+?)(?:\.git)?$/) ?? [])[1] ?? 'zerwiz/ymir';
    const list = JSON.parse(
      (await runAsync([
        'gh', 'pr', 'list', '--repo', repo, '--state', 'open', '--limit', '50',
        '--json', 'number,title,author,headRefName,isDraft,updatedAt,additions,deletions,statusCheckRollup,reviewDecision,mergeable',
      ], 15000)) || '[]',
    ) as Array<{
      number: number;
      title: string;
      author?: { login?: string };
      headRefName?: string;
      isDraft?: boolean;
      updatedAt?: string;
      additions?: number;
      deletions?: number;
      reviewDecision?: string;
      mergeable?: string;
      statusCheckRollup?: Array<{ name?: string; context?: string; status?: string; conclusion?: string }>;
    }>;
    for (const pr of list) {
      const checks = (pr.statusCheckRollup ?? []).map((c) => ({
        name: c.name ?? c.context ?? 'check',
        state:
          c.conclusion === 'SUCCESS' || c.status === 'IN_PROGRESS' || c.status === 'QUEUED'
            ? 'nominal'
            : c.conclusion
              ? 'down'
              : 'nominal',
      }));
      const failing = checks.some((c) => c.state === 'down');
      const approved = pr.reviewDecision === 'APPROVED' && !failing;
      cards.push({
        id: `pr-${pr.number}`,
        number: pr.number,
        title: pr.title,
        repo,
        author: pr.author?.login ?? 'unknown',
        realm: 'work',
        // draft → open (awaiting the Allfather); CI failing → changes (blocked);
        // GitHub APPROVED + green → approved (ready to seal).
        state: pr.isDraft ? 'open' : failing ? 'changes' : approved ? 'approved' : 'open',
        mergeable: pr.mergeable ?? undefined,
        checks,
        checklist: [{ label: `branch ${pr.headRefName ?? '?'}`, done: true }],
        additions: pr.additions ?? 0,
        deletions: pr.deletions ?? 0,
        updatedAt: pr.updatedAt ?? new Date().toISOString(),
      });
    }
  } catch (e) {
    // The Allfather must SEE a dead gh, never a silent blank board.
    ghError = e instanceof Error ? e.message : String(e);
  }

  // 2. The compliance card (lint + governed-path checks) always stands, but IT
  //    IS NOT A PULL REQUEST — the board counts real PRs (number > 0) apart.
  const out = await runAsync(['bash', 'bin/agents/brokk-lint.sh', '--quiet'], 60000);
  const compliance = await runAsync(['bash', '.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh', '--json'], 60000);
  let gates: { id: string; status: string; detail: string }[] = [];
  try {
    gates = JSON.parse(compliance).checks ?? [];
  } catch {
    /* ignore */
  }
  const lintOk = out.trim() === '';
  const failing = !lintOk || gates.some((g) => g.status !== 'PASS');
  cards.push({
    id: 'lint', number: 0, title: 'Brokk lint + compliance gate', repo: 'Ymir', author: 'brokk', realm: 'work',
    // A gate with any failing check is never APPROVED — it awaits the Allfather's seal.
    state: failing ? 'changes' : 'open',
    checks: [
      { name: 'lint', state: lintOk ? 'nominal' : 'down' },
      ...gates.map((g) => ({ name: g.id, state: g.status === 'PASS' ? 'nominal' : 'down' })),
    ],
    checklist: [
      { label: `lint: ${lintOk ? 'clean' : 'issues found'}`, done: lintOk },
      ...gates.map((g) => ({ label: `${g.id}: ${g.detail}`, done: g.status === 'PASS' })),
    ],
    additions: 0, deletions: 0, updatedAt: new Date().toISOString(),
  });
  return { cards, ghError };
}

/* ---- /api/files (realm tree) --------------------------------------------- */
/** Resolve a workspace id to its on-disk scope: a company container when the
 *  workspace names one, else its repo-root workspace scope. */
function workspaceRoot(realm: string): string {
  // THE HOARD FIRST (Rule 04). A realm's tree lives at $YMIR_HOME/svartalfaheim/
  // <realm>; the checkout is only a legacy fallback for a home not yet migrated.
  // Skrymir was browsing the repo's own directories and reading files whose links
  // point into the hoard — which is why a listed file answered "not found".
  // The realm's OWN tree first. A workspace may name a company, but the operator's
  // projects live under svartalfaheim/<realm>/projects — the company mapping is a
  // display owner, not the shelf. This is why Skrymir showed whynotproductions and
  // not the work tree that holds the meetings.
  const realmTree = join(HOME_DIR, 'svartalfaheim', realm);
  if (existsSync(realmTree)) return realmTree;
  const ws = workspaces().find((w) => w.id === realm);
  if (ws?.company) {
    const company = join(HOME_DIR, 'svartalfaheim', ws.company);
    if (existsSync(company)) return company;
  }
  const scope = join(HOME_DIR, 'workspace', realm);
  if (existsSync(scope)) return scope;
  const slug = realm.toLowerCase().replace(/[^a-z0-9]/g, '');
  const legacy = join(ROOT, 'svartalfaheim', slug);
  if (slug && slug !== realm && existsSync(legacy)) return legacy;
  const legacyScope = join(ROOT, 'workspace', realm);
  if (existsSync(legacyScope)) return legacyScope;
  return realmTree; // the hoard, even when empty: a home is never the repo's
}

/* ---- Skrymir: the WHOLE home, one folder at a time (plan 275 item 21) ----- *
 * The browser showed ONE realm (workspaceRoot('work')), so the Personal and
 * Svein trees were invisible and the home's own shelves never appeared. The
 * realms are folders under svartalfaheim/, not modes: Skrymir's root IS the
 * home. Two things follow and both are load-bearing:
 *   - a folder is read WHEN IT IS OPENED (one level per request), so the whole
 *     home is never walked to paint a tree;
 *   - the key and the vault are never listed and never read — hodd/secrets,
 *     the vault folder and its mount, and .git are hidden by name, and a path
 *     that resolves outside the home is refused.
 */
function homeRoot(): string {
  return resolve(HOME_DIR);
}

/** Relativised shelves Skrymir must never show (RULES/04 and 15). */
function hiddenShelves(): string[] {
  const out = ['hodd/secrets', 'vault', '.git'];
  const mnt = process.env.YMIR_VAULT_MNT ?? join(homedir(), 'Vault');
  const rel = relative(homeRoot(), resolve(mnt)).replace(/^\.\//, '');
  if (rel && !rel.startsWith('..') && !rel.startsWith('/')) out.push(rel);
  return out;
}

function hiddenPath(rel: string): boolean {
  const clean = rel.replace(/^\/+/, '').replace(/\/+$/, '');
  if (!clean) return false;
  if (clean.split('/').some((p) => p === '.git')) return true;
  return hiddenShelves().some((h) => clean === h || clean.startsWith(`${h}/`));
}

/** The absolute target for a home-relative path, or null when it escapes. */
function homeTarget(rel: string): string | null {
  const base = homeRoot();
  const full = resolve(base, rel || '.');
  if (full !== base && !full.startsWith(`${base}/`)) return null;
  if (hiddenPath(rel)) return null;
  return full;
}

/** ONE directory level, for the folder that was just opened. */
function files(pathOrRealm: string) {
  // Back-compat: an old client sends ?realm=work; that is the realm folder, and
  // the realm is a folder here, never a mode.
  const rel = pathOrRealm || '';
  const full = homeTarget(rel);
  if (!full) return { name: rel || 'ymirhome', type: 'dir', path: rel, children: [], error: 'not shown: the vault and the secrets are never listed' };
  if (!existsSync(full)) return { name: rel.split('/').pop() || 'ymirhome', type: 'dir', path: rel, children: [], error: 'not found' };
  const children: unknown[] = [];
  let entries: string[] = [];
  try {
    entries = readdirSync(full).sort((a, b) => a.localeCompare(b));
  } catch {
    return { name: rel.split('/').pop() || 'ymirhome', type: 'dir', path: rel, children, error: 'unreadable' };
  }
  for (const e of entries) {
    if (e.startsWith('.')) continue; // dot entries are state, keys and the repo: never a browser's business
    const childRel = rel ? `${rel}/${e}` : e;
    if (hiddenPath(childRel)) continue;
    const target = join(full, e);
    let st;
    try {
      st = statSync(target);
    } catch {
      continue; // a broken link is not a row
    }
    if (st.isDirectory()) children.push({ name: e, type: 'dir', path: childRel, lazy: true });
    else children.push({ name: e, type: 'file', path: childRel, size: st.size, updated: st.mtime.toISOString() });
  }
  return { name: rel ? rel.split('/').pop()! : basename(homeRoot()), type: 'dir', path: rel, children };
}

/* ---- /api/file — read one file of the home, read-only --------------------- */
function fileContent(rel: string) {
  const full = homeTarget(rel);
  if (!full) return { error: 'outside the home, or a shelf Skrymir never shows' };
  if (!existsSync(full)) return { error: 'not found' };
  let st;
  try {
    st = statSync(full);
  } catch {
    return { error: 'unreadable' };
  }
  if (!st.isFile()) return { error: 'not a file' };
  if (st.size > 512 * 1024) return { path: rel, size: st.size, body: '', note: 'file too large to preview' };
  return { path: rel, size: st.size, updated: st.mtime.toISOString(), body: read(full) };
}

/* ---- /api/skills — the live skill index (read-only) ---------------------- */
function skills() {
  const dir = join(ROOT, '.agents/skills');
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((d) => existsSync(join(dir, d, 'SKILL.md')) || existsSync(join(dir, d, 'AGENTS.md')))
    .map((d) => {
      const p = existsSync(join(dir, d, 'SKILL.md')) ? join(dir, d, 'SKILL.md') : join(dir, d, 'AGENTS.md');
      const fm = frontmatter(read(p));
      const name = String(fm.name ?? d);
      const description = String(fm.description ?? '').slice(0, 240);
      const aett = name.includes('-') ? name.split('-')[0] : 'galdr';
      return { id: `skl-${d}`, name, aett, description, capabilities: [], validated: true, domain: 'ymirlabs', createdAt: '' };
    });
}

/* ---- /api/runtime -------------------------------------------------------- */
// The page a PERSON reads (plan 275 item 25). The digest itself is an agent's
// context — TOON tables, 163 liveness rows mostly long finished — so the raw text
// is returned for the fold and the facts are drawn on the page from `view`.
// The services section is item 27: which release each long-running service is
// actually running from, and a warning when that is not the pin.
async function releaseMatrix(): Promise<{ pin: string; services: unknown[]; error?: string }> {
  try {
    const proc = Bun.spawn(['bash', 'bin/engine/release-services.sh', 'status', '--json'], {
      cwd: ROOT, stdout: 'pipe', stderr: 'pipe',
    });
    const out = await new Response(proc.stdout).text();
    await proc.exited;
    const parsed = JSON.parse(out) as { pin?: string; services?: unknown[] };
    return { pin: parsed.pin ?? '', services: parsed.services ?? [] };
  } catch (e) {
    return { pin: '', services: [], error: `the release matrix could not be read: ${(e as Error).message}` };
  }
}

/** Mail that asks for the Allfather — the desk's own count, or an honest null. */
async function mailWaiting(): Promise<{ needs: number; unsure: number; accounts: string[]; error?: string }> {
  const token = mailDeskToken();
  if (!token) return { needs: 0, unsure: 0, accounts: [], error: 'the desk has no token yet' };
  try {
    const list = await fetch(`${MAIL_DESK}/accounts`, {
      headers: { authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(4000),
    });
    const accounts = ((await list.json()) as { accounts?: string[] }).accounts ?? [];
    let needs = 0;
    let unsure = 0;
    for (const account of accounts) {
      const r = await fetch(`${MAIL_DESK}/queue?account=${encodeURIComponent(account)}&hours=72`, {
        headers: { authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(4000),
      });
      const q = (await r.json().catch(() => ({}))) as { counts?: { needs_you?: number; unsure?: number } };
      needs += q.counts?.needs_you ?? 0;
      unsure += q.counts?.unsure ?? 0;
    }
    return { needs, unsure, accounts };
  } catch (e) {
    return { needs: 0, unsure: 0, accounts: [], error: `the desk did not answer: ${(e as Error).message}` };
  }
}

/**
 * The digest takes ten to fifteen seconds (it runs the whole session-start
 * script), and a page must not wait that long to answer. So it is read in the
 * BACKGROUND and the page says `reading: true` until it lands: the fast parts
 * (services, mail, markers) are answered every time, and the digest is served
 * from the last read while a fresh one is being made. `RUNTIME_TTL` is how old a
 * read may be before another is started.
 */
const RUNTIME_TTL = 60_000;
let digestRead: { at: number; digest: string } | null = null;
let digestInflight: Promise<void> | null = null;

function readDigestInBackground(): void {
  if (digestInflight) return;
  digestInflight = (async () => {
    try {
      // 60 s is the script's own ceiling, not a promise it is fast
      const digest = await runAsync(['bash', 'bin/time/saga-session-start.sh'], 0, 60);
      digestRead = { at: Date.now(), digest };
    } catch {
      digestRead = { at: Date.now(), digest: '' };
    } finally {
      digestInflight = null;
    }
  })();
}

async function runtime() {
  const fresh = !!digestRead && Date.now() - digestRead.at < RUNTIME_TTL;
  if (!fresh) readDigestInBackground();
  const [services, mail] = await Promise.all([releaseMatrix(), mailWaiting()]);
  const markers = {
    lock: read(join(STATE_DIR, '.lock')).trim(),
    started: existsSync(join(STATE_DIR, '.session-start-complete')),
    armed: existsSync(join(STATE_DIR, '.supervision-armed')),
  };
  const digest = digestRead?.digest ?? '';
  return {
    digest,
    view: digest ? readDigest(digest) : null,
    reading: !digest,
    services,
    mail,
    markers,
    doc: 'docs/session-start.md',
  };
}

/* ---- /api/soak ----------------------------------------------------------- */
// Plan 286 P6 — the Health view's data. Two sources, one reading: the leak
// ledger's per-service trends (RSS, fds, watches, children, GPU, restarts) and
// each app's LAST soak from `state/soak/<app>/`. Both are judged by plan 286
// §5's budgets inside health.ts, so the page never invents a verdict.
// Memoised for 30 s: the ledger is append-only and grows every five minutes, and
// the app registry is a shell door — neither may be re-read on every request.
function soakHealth() {
  const appNames = run(['bin/desktop/ymir-app', '--list'])
    .split('\n')
    .map((s) => s.trim())
    .filter(Boolean);
  return memo('soak-health', 30_000, () => readSoakHealth({ homeDir: HOME_DIR, appNames }));
}

/* ---- /api/cron ----------------------------------------------------------- */
// The schedule the LOOP reads — never the repo's template. The board used to
// read join(ROOT,'.agents/config'), which ships ONLY cron.yaml.example, so it
// painted "0 jobs" while the loop ran the home's real schedule (2026-09-24).
// bin/time/nornir-cron-start.sh resolves the config first from $YMIR_HOME/config;
// the board resolves the same way.
function cronConfigPath(): { path: string; source: string } {
  const home = join(HOME_DIR, 'config', 'cron.yaml');
  if (existsSync(home)) return { path: home, source: 'home' };
  const repo = join(CONFIG_DIR, 'cron.yaml');
  if (existsSync(repo)) return { path: repo, source: 'repo' };
  const example = join(CONFIG_DIR, 'cron.yaml.example');
  if (existsSync(example)) return { path: example, source: 'example' };
  return { path: '', source: 'none' };
}

interface CronJobLine { at: string; role: string; command: string; }
// Mirror the loop's parse exactly (bin/time/nornir-cron-start.sh): a `@role[,role]`
// gate may sit BEFORE the time (`@heart 06:00 bin/x`) or AFTER (`06:00 @heart
// bin/x`); no gate means any role. One reality for scheduler, API, and board.
function parseCronJobs(cfg: string): CronJobLine[] {
  const jobs: CronJobLine[] = [];
  for (const raw of cfg.split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    let rest = line;
    let role = '';
    if (line.startsWith('@')) {
      role = line.split(/\s+/)[0].slice(1);
      rest = line.slice(line.indexOf(' ') + 1).trim();
    }
    const m = rest.match(/^(\d{2}:\d{2})\s+(.+)$/);
    if (!m) continue;
    let tail = m[2];
    if (tail.startsWith('@')) {
      role = tail.split(/\s+/)[0].slice(1);
      tail = tail.slice(tail.indexOf(' ') + 1).trim();
    }
    if (!tail) continue;
    jobs.push({ at: m[1], role, command: tail });
  }
  return jobs;
}
function roleWords(role: string): string[] { return role ? role.split(',') : []; }
function jobApplies(job: CronJobLine, roles: string[]): boolean {
  if (!job.role) return true;               // no gate: any role
  return roleWords(job.role).some((w) => roles.includes(w));
}

async function cron() {
  const { path, source } = cronConfigPath();
  const cfg = path ? read(path) : '';
  const jobs = parseCronJobs(cfg);
  const status = await runAsync(['bash', 'bin/time/nornir-cron-start.sh', '--status']);
  const running = status.includes('running');
  const pid = (status.match(/pid=(\d+)/) ?? [])[1] ?? '';
  // Why a stopped loop is stopped — the log's last word, so 'DOWN' carries a
  // reason, never a bare verdict.
  const log = read(join(STATE_DIR, 'cron.log'));
  const sleepLines = log.split('\n').filter((l) => l.includes('cron retired') || l.includes('cron run'));
  const why = running ? '' : (sleepLines.length
    ? ((sleepLines[sleepLines.length - 1].match(/cron retired - (.+)$/) ?? [])[1] ?? 'stopped')
    : 'never started this session');
  // The seat's own roles, so the board can say which jobs run HERE (plan 51).
  let roles: string[] = [];
  try { roles = ((JSON.parse(await runAsync(['bash', 'bin/fleet/topology.sh', '--json'])) as { roles?: string[] }).roles ?? []) as string[]; } catch { /* no topology */ }
  // Last fire per job, from the loop's date-guard stamps.
  const last: Record<string, string> = {};
  const stampDir = join(STATE_DIR, '.cron-fired');
  for (const j of jobs) {
    const f = join(stampDir, j.command.replace(/[^A-Za-z0-9._-]/g, '_'));
    if (existsSync(f)) last[j.command] = read(f).trim();
  }
  const applies = jobs.filter((j) => jobApplies(j, roles)).length;
  return {
    running, pid, why, source, roles,
    jobs: jobs.map((j) => ({ at: j.at, role: j.role, command: j.command, status: running ? 'scheduled' : 'stopped', applies: jobApplies(j, roles) })),
    last,
  };
}

// The server crons the board must show beside the local ones (plan 54, 2026-09-24). The seats are the
// fleet's heart and forge hosts, read from the registry in the hoard — never names in this public file
// (plan 278; YMIR_CRON_SERVER_SEATS still wins). One ssh round-trip per seat — read-on-demand,
// machine-local, BatchMode only.
function serverSeats(): { seat: string; host: string }[] {
  return resolveServerSeats(HOARD);
}

async function cronSeats() {
  const { path } = cronConfigPath();
  const localJobs = parseCronJobs(path ? read(path) : '');
  const rows = [];
  for (const s of serverSeats()) {
    const out = await runAsync(
      ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=3', s.host,
        `bash -lc 'G=$HOME/ymir; [ -d "$G/bin" ] || G=$(dirname "$(ls -d "$HOME"/*ymir*/bin 2>/dev/null | head -1)" 2>/dev/null); cd "$G" 2>/dev/null || exit 1; bash bin/time/nornir-cron-start.sh --status; bash bin/fleet/topology.sh --json 2>/dev/null'`],
      8000);
    if (!out) {
      rows.push({ seat: s.seat, host: s.host, reachable: false, running: false, pid: '', roles: [], jobs: localJobs.length, applies: 0, error: 'unreachable (ssh ring)' });
      continue;
    }
    const running = out.includes('running');
    const pid = (out.match(/pid=(\d+)/) ?? [])[1] ?? '';
    let roles: string[] = [];
    try { roles = ((JSON.parse(out.slice(out.indexOf('{'))) as { roles?: string[] }).roles ?? []) as string[]; } catch { /* no topology answer */ }
    rows.push({
      seat: s.seat, host: s.host, reachable: true, running, pid, roles,
      jobs: localJobs.length,
      applies: localJobs.filter((j) => jobApplies(j, roles)).length,
    });
  }
  return rows;
}

/** Forget every cached answer for one command. An ACTION must never be answered
 *  by a status read taken before it ran (the status call is memoised for 3 s). */
function forgetMemo(fragment: string): void {
  for (const key of [...MEMO.keys()]) if (key.includes(fragment)) MEMO.delete(key);
}

/** Start or stop this seat's scheduler — the SAME script the session start runs
 *  (`bin/time/nornir-cron-start.sh`). The board gains a hand, never a second
 *  opinion about how the loop is raised: `start` is idempotent, `stop` kills the
 *  pid the script itself owns. */
async function cronAct(action: 'start' | 'stop') {
  forgetMemo('nornir-cron-start.sh');
  const argv = ['bash', 'bin/time/nornir-cron-start.sh'];
  if (action === 'stop') argv.push('--stop');
  const said = await runAsync(argv, 0);
  forgetMemo('nornir-cron-start.sh');
  return { ok: true, action, said, ...(await cron()) };
}

/* ---- /api/calendar (Mánagandr, the read reckoning) ----------------------- */
// The reader (`tools/calendar/reader.mjs`, its own errand) refreshes the Google
// grant and writes ONE rolling cache under the hoard's state. This route only
// READS that file — there is no write path here, and none anywhere in the gate.
// `state` is the honest word: a missing cache is NOT an empty calendar.
const CALENDAR_CACHE = process.env.MANAGANDR_CACHE ?? join(HOARD, 'state', 'calendar', 'cache.json');
// Freshness window for the cache; env-driven (Rule 07), one documented default.
const CALENDAR_TTL_S = Number(process.env.MANAGANDR_CALENDAR_TTL_SECONDS ?? 6 * 60 * 60);

interface CalendarEventOut {
  id: string;
  title: string;
  start: string;
  end: string | null;
  allDay: boolean;
  cancelled: boolean;
  calendarId: string;
  /** Present only when the cache carries it — a count, never names. */
  attendees?: number;
}
interface CalendarAnswer {
  as_of: string | null;
  state: 'ok' | 'unknown' | 'absent';
  /** Where the answer came from: 'google' | 'cache' | 'fixture' | 'none'. */
  source?: string;
  events: CalendarEventOut[];
}

function pickField(obj: Record<string, unknown>, ...keys: string[]): unknown {
  for (const k of keys) if (obj[k] !== undefined && obj[k] !== null) return obj[k];
  return undefined;
}

/** Normalise one raw cache event to the pinned shape; a stray becomes null. */
function normalizeEvent(raw: unknown, i: number): CalendarEventOut | null {
  if (!raw || typeof raw !== 'object') return null;
  const e = raw as Record<string, unknown>;
  const start = pickField(e, 'start', 'start_at', 'startTime');
  if (typeof start !== 'string' || !start) return null;
  const rawEnd = pickField(e, 'end', 'end_at', 'endTime');
  const end = typeof rawEnd === 'string' ? rawEnd : null;
  const allDayFlag = pickField(e, 'allDay', 'all_day', 'isAllDay');
  // An all-day event is flagged, or is a bare date with no time component.
  const allDay = allDayFlag === true || (end === null && /^\d{4}-\d{2}-\d{2}$/.test(start));
  const status = String(pickField(e, 'status', 'state') ?? '');
  const cancelledFlag = pickField(e, 'cancelled', 'canceled');
  const cancelled = cancelledFlag === true || /cancel/i.test(status);
  const attendeesRaw = pickField(e, 'attendees', 'attendee_count', 'attendeeCount');
  const attendees = Array.isArray(attendeesRaw)
    ? attendeesRaw.length
    : typeof attendeesRaw === 'number'
      ? attendeesRaw
      : undefined;
  const out: CalendarEventOut = {
    id: String(pickField(e, 'id', 'eventId', 'event_id') ?? `ev-${i}`),
    title: String(pickField(e, 'title', 'summary', 'name') ?? '(untitled)'),
    start,
    end: allDay ? null : end,
    allDay,
    cancelled,
    calendarId: String(pickField(e, 'calendarId', 'calendar_id', 'calendar') ?? 'primary'),
  };
  if (attendees !== undefined) out.attendees = attendees;
  return out;
}

function calendar(): CalendarAnswer {
  // No cache at all: the token is Phase 0 and has not been granted. This is NOT
  // an empty day — the gate must say "not granted", never paint a blank grid.
  if (!existsSync(CALENDAR_CACHE)) return { as_of: null, state: 'absent', events: [] };
  let parsed: unknown;
  try {
    parsed = JSON.parse(readFileSync(CALENDAR_CACHE, 'utf8'));
  } catch {
    // The file is there but unreadable — unknown, never absent and never empty.
    return { as_of: null, state: 'unknown', events: [] };
  }
  const obj = (parsed && typeof parsed === 'object' ? parsed : {}) as Record<string, unknown>;
  const rawAsOf = pickField(obj, 'as_of', 'asOf', 'generated_at', 'generatedAt', 'fetched_at', 'updated_at', 'at');
  const asOf = typeof rawAsOf === 'string' && rawAsOf ? rawAsOf : null;
  const source = String(pickField(obj, 'source') ?? 'unknown');
  const rawEvents = pickField(obj, 'events', 'items');
  const list = Array.isArray(rawEvents) ? rawEvents : Array.isArray(parsed) ? parsed : [];
  const events = list.map(normalizeEvent).filter(Boolean) as CalendarEventOut[];
  // Freshness is provable only from a readable as_of inside the TTL; anything
  // else is unknown — the cache exists but cannot be trusted for freshness.
  const t = asOf ? Date.parse(asOf) : NaN;
  const fresh = Number.isFinite(t) && Date.now() - t <= CALENDAR_TTL_S * 1000;
  // A FIXTURE is invented data, and a fresh timestamp does not make it real. It
  // is served as `unknown` with its source named, never as `ok` — the grid must
  // never paint "Invented All-Day Gathering" as the Allfather's diary. This
  // happened once (a probe omitted --cache and wrote 5 invented events into the
  // hoard's cache); the reader now refuses that write, and this refuses to
  // present it.
  if (source === 'fixture') {
    return { as_of: asOf, state: 'unknown', source, events };
  }
  return { as_of: asOf, state: fresh ? 'ok' : 'unknown', source, events };
}


/* ---- /api/snotra (the meeting record, plan 93) --------------------------- */
// Reads the store and the project meeting shelves. Draft/send call the Snotra
// doors; they never write a record and never send without the approval call.
const SNOTRA_STORE = process.env.SNOTRA_MEETINGS_DIR ?? join(HOARD, 'life', 'meetings');
const SNOTRA_ROOTS = [SNOTRA_STORE, join(HOME_DIR, 'svartalfaheim')];

interface SnotraMeetingOut {
  id: string; title: string; started_at: string | null; workspace: string;
  source: string; state: string; decisions: number; actions: number;
  has_record: boolean; dir: string; scope: string;
  participants: { name: string; email: string | null }[];
  draft?: string | null;
}

function snotraDirs(): { dir: string; file: string }[] {
  const out: { dir: string; file: string }[] = [];
  const push = (dir: string) => {
    for (const f of ['record.json', 'meeting.json']) {
      const p = join(dir, f);
      if (existsSync(p)) { out.push({ dir, file: p }); return; }
    }
  };
  try {
    for (const lane of readdirSync(SNOTRA_STORE, { withFileTypes: true })) {
      if (!lane.isDirectory()) continue;
      const laneDir = join(SNOTRA_STORE, lane.name);
      for (const m of readdirSync(laneDir, { withFileTypes: true })) {
        if (m.isDirectory()) push(join(laneDir, m.name));
      }
    }
  } catch { /* store absent is not an error */ }
  // Private meetings: the hoard's own shelf.
  try {
    for (const m of readdirSync(join(HOARD, 'workspaces', 'meetings'), { withFileTypes: true })) {
      if (m.isDirectory()) push(join(HOARD, 'workspaces', 'meetings', m.name));
    }
  } catch { /* no private shelf */ }
  try {
    for (const realm of readdirSync(SNOTRA_ROOTS[1], { withFileTypes: true })) {
      if (!realm.isDirectory()) continue;
      const companyMeetings = join(SNOTRA_ROOTS[1], realm.name, 'meetings');
      if (existsSync(companyMeetings)) {
        for (const m of readdirSync(companyMeetings, { withFileTypes: true })) {
          if (m.isDirectory()) push(join(companyMeetings, m.name));
        }
      }
      const projects = join(SNOTRA_ROOTS[1], realm.name, 'projects');
      if (!existsSync(projects)) continue;
      for (const project of readdirSync(projects, { withFileTypes: true })) {
        if (!project.isDirectory()) continue;
        const meetings = join(projects, project.name, 'meetings');
        if (!existsSync(meetings)) continue;
        for (const m of readdirSync(meetings, { withFileTypes: true })) {
          if (m.isDirectory()) push(join(meetings, m.name));
        }
      }
    }
  } catch { /* no project meetings */ }
  return out;
}

function snotraMeetings(): SnotraMeetingOut[] {
  const rows: SnotraMeetingOut[] = [];
  for (const { dir, file } of snotraDirs()) {
    try {
      const d = JSON.parse(readFileSync(file, 'utf8')) as Record<string, any>;
      const m = (d.meeting && typeof d.meeting === 'object') ? d.meeting : d;
      const participants = (d.participants ?? m.participants ?? []) as any[];
      rows.push({
        id: String(m.id ?? m.meeting_id ?? dir.split('/').pop()),
        title: String(m.title ?? m.summary ?? '(untitled)'),
        started_at: m.started_at ?? m.start ?? null,
        workspace: String(m.workspace ?? (dir.includes('/hodd/workspaces/meetings/') ? 'private'
          : dir.includes('/personal/') ? 'personal'
          : (dir.match(/svartalfaheim\/([^/]+)\/(?:meetings|projects)\//) ?? [])[1] ?? 'work')),
        scope: dir.includes('/hodd/workspaces/meetings/') ? 'private'
          : dir.includes('/projects/') ? 'project'
          : dir.includes('/hodd/life/meetings/') ? 'store'
          : 'company',
        source: String(m.source ?? 'manual'),
        state: String(m.state ?? d.state ?? 'captured'),
        decisions: Array.isArray(d.decisions) ? d.decisions.length : 0,
        actions: Array.isArray(d.actions) ? d.actions.length : 0,
        has_record: existsSync(join(dir, 'minutes.md')) || existsSync(join(dir, 'record.md')),
        dir,
        participants: participants.map((p: any) => ({ name: String(p.name ?? ''), email: p.email ?? null })),
      });
    } catch { /* a broken record is skipped, never crashes the shelf */ }
  }
  return rows.sort((a, b) => String(b.started_at ?? '').localeCompare(String(a.started_at ?? '')));
}

function snotraFind(id: string): SnotraMeetingOut | undefined {
  return snotraMeetings().find((m) => m.id === id || m.dir.endsWith('/' + id));
}

function snotraDraft(id: string): { draftId: string } | { error: string } {
  const m = snotraFind(id);
  if (!m) return { error: `no meeting ${id}` };
  const body = join(m.dir, 'followup-email.md');
  if (!existsSync(body)) return { error: 'no follow-up body (run the record pipeline first)' };
  const att: string[] = [];
  for (const f of ['minutes.md', 'record.md', 'decisions.md', 'actions.md']) {
    const p = join(m.dir, f);
    if (existsSync(p)) att.push('--attach', p);
  }
  const record = join(m.dir, 'record.json');
  const args = [join(ROOT, 'systems/snotra/services/letters/mail-send.sh'), 'draft',
    '--from-record', record, '--subject', `${m.title} — Meeting Record`,
    '--body', body, ...att, '--record', m.id];
  const r = spawnSync('bash', args, { encoding: 'utf8', timeout: 120_000 });
  const out = `${r.stdout ?? ''}${r.stderr ?? ''}`;
  const hit = out.match(/^draft\t(r-\d+)/m);
  if (!hit) return { error: out.trim().split('\n').slice(-2).join(' · ') || 'draft failed' };
  return { draftId: hit[1] };
}

function snotraSend(draftId: string): { sent: string } | { error: string } {
  if (!/^r-\d+$/.test(draftId)) return { error: 'invalid draft id' };
  const r = spawnSync('bash', [join(ROOT, 'systems/snotra/services/letters/mail-send.sh'), 'send', draftId],
    { encoding: 'utf8', timeout: 120_000 });
  const out = `${r.stdout ?? ''}${r.stderr ?? ''}`;
  const hit = out.match(/^sent\t(\S+)/m);
  if (!hit) return { error: out.trim().split('\n').slice(-2).join(' · ') || 'send failed' };
  return { sent: hit[1] };
}

/* ---- /api/loaders, /api/checks, /api/settings ---------------------------- */
function parseToon(text: string): Record<string, string>[] {
  const rows: Record<string, string>[] = [];
  const lines = text.split('\n');
  const header = lines.find((l) => /\{[^}]+\}:/.test(l));
  if (!header) return rows;
  const keys = (header.match(/\{([^}]+)\}/) ?? ['', ''])[1].split(',');
  const start = lines.indexOf(header);
  for (let i = start + 1; i < lines.length; i++) {
    const l = lines[i];
    if (!/^\s{2,}"/.test(l)) break;
    const vals = l.trim().split(/","/).map((v) => v.replace(/^"|"$/g, ''));
    const row: Record<string, string> = {};
    keys.forEach((k, idx) => (row[k.trim()] = vals[idx] ?? ''));
    rows.push(row);
  }
  return rows;
}

async function loaders() {
  return parseToon(await runAsync(['bash', 'bin/seat/valknut-load.sh', '--status']));
}
async function checks() {
  try {
    return (JSON.parse(await runAsync(['bash', '.agents/skills/galdr-ymirsystem/scripts/compliance-check.sh', '--json'], 60000)).checks ?? []) as unknown[];
  } catch {
    return [];
  }
}
function settings() {
  const dir = CONFIG_DIR;
  if (!existsSync(dir)) return [];
  return readdirSync(dir).map((f) => {
    const v = read(join(dir, f)).trim().slice(0, 120);
    return { key: f, set: v.length > 0, value: v };
  });
}

/* ---- the live tail (Snotra) — a FRONT for snotra-live.sh, never a second --- *
 * pipeline. The SCRIPT owns the truth: the gate asks it and reports what the
 * script says. Nothing here re-implements transcription, slice timing or engine
 * discovery. The document stays in the hoard (`$YMIR_HOME/hodd/life/meetings/`);
 * only these three authenticated routes read it, and only for the operator. */
const LIVE_SCRIPT = 'systems/snotra/services/ear/snotra-live.sh';

/** A `stop` this gate spawned, still running. `stop` joins every slice into one
 *  WAV, re-transcribes the recording, asks the rail for a summary, writes the
 *  minutes and carves a Rune — MINUTES on a long meeting. So the POST answers at
 *  once, and this is how the surface says "closing the book…" rather than
 *  "stopped": the script silences ffmpeg in its first seconds, so `status`
 *  alone would report stopped while the minutes are still being written. */
let liveClosing: { since: number; done: Promise<unknown> } | null = null;

/** Parse the script's one TOON row: `live_tail{state:listening,doc:/path,…}`. */
function parseLiveRow(out: string): Record<string, string> {
  const row: Record<string, string> = {};
  const m = out.match(/live_tail\{([^}]*)\}/);
  if (!m) return row;
  for (const part of m[1].split(',')) {
    const i = part.indexOf(':');
    if (i > 0) row[part.slice(0, i).trim()] = part.slice(i + 1).trim();
  }
  return row;
}

/** The newest `[hh:mm:ss] text` lines of the document the SCRIPT named. A read
 *  only — the words are the operator's own, never copied into the tree. */
function liveLines(doc: string, max = 40): string[] {
  if (!doc || !existsSync(doc)) return [];
  return read(doc)
    .split('\n')
    .filter((l) => /^\[\d{2}:\d{2}:\d{2}\]/.test(l))
    .slice(-max);
}

/** The honest state: `closing` outranks the script's own `stopped`, because the
 *  gate KNOWS a drain is in flight and the surface must never claim a state the
 *  work contradicts. */
async function liveStatus() {
  const out = await runAsync(['bash', LIVE_SCRIPT, 'status'], 1200);
  const row = parseLiveRow(out);
  const listening = row.state === 'listening';
  const doc = row.doc ?? '';
  return {
    state: liveClosing ? ('closing' as const) : listening ? ('listening' as const) : ('idle' as const),
    pid: row.ffmpeg || undefined,
    slices: row.slices_done ? Number(row.slices_done) : undefined,
    doc: doc || undefined,
    lines: listening || liveClosing ? liveLines(doc) : [],
    /** The script's own sentence after the row (the newest line, or its refusal). */
    said: out.split('\n').slice(1).join('\n').trim() || undefined,
  };
}

/* ---- /api/stream (SSE): new runes AND new agent-to-agent messages --------- *
 * Two ledgers, one stream. The Runes tail has been here since the start; the fleet
 * message log (bin/agents/msg-log.sh) joins it so the footer shows the herdr traffic
 * between agents as it happens (plan 275 item 8). Both are read by BYTE cursor, and
 * a file that shrank (rotated, replaced) restarts its cursor at 0 rather than
 * silently going dark.
 */
function tailLines(
  path: string,
  from: number,
): { at: number; lines: string[] } {
  let size: number;
  try {
    size = statSync(path).size;
  } catch {
    return { at: from, lines: [] };
  }
  const cursor = size < from ? 0 : from;
  if (size <= cursor) return { at: cursor, lines: [] };
  let tail = '';
  try {
    // BYTES, not characters: the cursor is a byte offset from statSync, and slicing a
    // JS string by it lands mid-character the moment a row carries `Hœnir` or `Smíðja`.
    // Every line after the first multibyte rune was silently lost to that (2026-11-14).
    tail = readFileSync(path).subarray(cursor).toString('utf8');
  } catch {
    return { at: cursor, lines: [] };
  }
  return { at: size, lines: tail.split('\n').filter((l) => l.trim()) };
}

function stream() {
  let runeCursor = 0;
  try {
    runeCursor = statSync(RUNES).size;
  } catch {
    /* no ledger yet */
  }
  // A stream opened now shows what is said NEXT; the A2A panel carries the history.
  let msgCursor = 0;
  try {
    msgCursor = statSync(FLEET_LOG).size;
  } catch {
    /* nothing has been sent yet */
  }
  let tick: ReturnType<typeof setInterval> | null = null;
  return new Response(
    new ReadableStream({
      start(controller) {
        const enc = new TextEncoder();
        const send = (ev: unknown) => controller.enqueue(enc.encode(`data: ${JSON.stringify(ev)}\n\n`));
        tick = setInterval(() => {
          const runeTail = tailLines(RUNES, runeCursor);
          runeCursor = runeTail.at;
          for (const line of runeTail.lines) {
            if (!line.trim().startsWith('{')) continue;
            try {
              const e = JSON.parse(line);
              send({
                id: String(e.checksum ?? Date.now()).slice(0, 12),
                ts: e.timestamp ?? new Date().toISOString(),
                kind: 'rune',
                from: e.actor ?? 'brokk',
                module: e.event ?? '',
                message: e.message ?? '',
                checksum: String(e.checksum ?? '').slice(0, 8),
              });
            } catch {
              /* a torn ledger line never stops the stream */
            }
          }

          const msgTail = tailLines(FLEET_LOG, msgCursor);
          msgCursor = msgTail.at;
          for (const line of msgTail.lines) {
            try {
              const m = JSON.parse(line);
              send({
                id: `msg-${m.epoch ?? Date.now()}-${String(m.to ?? '').replace(/[^\w:]/g, '')}`,
                ts: m.ts ?? new Date().toISOString(),
                kind: 'ratatoskr',
                from: m.from ?? 'agent',
                to: m.to ?? '',
                state: 'SUBMITTED',
                message: m.text ?? '',
                // The fleet's own page: a message between agents belongs to Fleet,
                // not to whichever gate happened to be open when it arrived.
                gate: 'fleet',
              });
            } catch {
              /* one torn row is skipped, not fatal */
            }
          }
        }, 2000);
      },
      cancel() {
        if (tick) { clearInterval(tick); tick = null; }
      },
    }),
    { headers: { 'content-type': 'text/event-stream', 'cache-control': 'no-store', connection: 'keep-alive' } },
  );
}

/* ---- /api/chat — Kaia, the oracle by the well ---------------------------- */
const CHAT_DIR = join(STATE_DIR, 'chat');
const CHAT_WINDOW = 40; // rolling context — the last 40 messages
const SAFE_SESSION = /^[A-Za-z0-9._-]+$/;
// Kaia speaks through the models the operator actually connected. The root Pi
// catalog (`~/.pi/agent/models.json`) is the source of truth for the llama.cpp
// router (`:8080`) and LM Studio; the Bifrost bridge (`:4603`) is the online
// fallback. We never guess a llama.cpp model id — we read the one `.pi` uses.
const PI_MODELS_PATH = join(homedir(), '.pi/agent/models.json');
const PI_SETTINGS_PATH = join(homedir(), '.pi/agent/settings.json');
const CHAT_BASES = [
  process.env.CHAT_BASE_URL,
  'http://127.0.0.1:8080/v1',
  'http://127.0.0.1:4603/v1',
].filter(Boolean) as string[];
const CHAT_MODEL_ENV = process.env.CHAT_MODEL;
const modelFor: Record<string, string> = {};

interface ChatTarget {
  base: string;
  model: string;
  key?: string;
  label: string;
  kind: 'local' | 'online';
}
interface ChatCatalogEntry extends ChatTarget {
  id: string;
  name: string;
  provider: string;
}

async function listModels(base: string): Promise<string[]> {
  const res = await fetch(`${base}/models`);
  const data = (await res.json()) as { data?: { id?: string }[] };
  return (data.data ?? []).map((m) => m.id ?? '').filter(Boolean);
}

/**
 * The keys Pi itself uses. `models.json` carries base + model and often NO key —
 * the provider's credential lives in `auth.json` as `{provider: {type, key}}`.
 * Reading only the catalog sent every rail call without an Authorization header,
 * so the local router answered 401 while the rail was up and serving: the chat
 * fell through to Bifrost and reported "no model backend answered".
 */
const PI_AUTH_PATH = join(homedir(), '.pi/agent/auth.json');
function piAuthKeys(): Record<string, string> {
  const out: Record<string, string> = {};
  try {
    const raw = JSON.parse(read(PI_AUTH_PATH)) as Record<string, { key?: string } | string>;
    for (const [pkey, pv] of Object.entries(raw)) {
      const key = typeof pv === 'string' ? pv : pv?.key;
      if (key) out[pkey] = key;
    }
  } catch {
    /* no auth file — an unauthenticated provider stays unauthenticated */
  }
  return out;
}

/** Providers from the root Pi catalog: the exact base/model/key Pi uses. */
function piCatalog(): ChatCatalogEntry[] {
  const out: ChatCatalogEntry[] = [];
  try {
    const raw = JSON.parse(read(PI_MODELS_PATH)) as {
      providers?: Record<string, { baseUrl?: string; apiKey?: string; models?: { id?: string }[] }>;
    };
    const authKeys = piAuthKeys();
    for (const [pkey, pv] of Object.entries(raw.providers ?? {})) {
      const base = pv.baseUrl ?? '';
      if (!base) continue;
      const kind: 'local' | 'online' = /(127\.0\.0\.1|localhost)/.test(base) ? 'local' : 'online';
      const models = (pv.models ?? []).map((m) => m.id ?? '').filter(Boolean);
      const single = models.length === 1;
      for (const mid of models) {
        out.push({
          id: single ? pkey : `${pkey}/${mid}`,
          name: mid,
          provider: pkey,
          kind,
          base,
          model: mid,
          key: pv.apiKey || authKeys[pkey],
          label: mid,
        });
      }
    }
  } catch {
    /* no Pi catalog — fall back to live probing */
  }
  return out;
}

async function resolveModel(base: string): Promise<string> {
  if (CHAT_MODEL_ENV) return CHAT_MODEL_ENV;
  if (modelFor[base]) return modelFor[base];
  const ids = await listModels(base);
  const pick = ids.find((i) => /gemma|qwen|deepseek|hermes/i.test(i)) ?? ids[0];
  if (!pick) throw new Error('no models advertised');
  modelFor[base] = pick;
  return pick;
}

/** Order the backends to try for a chosen model (or the operator's default). */
function resolveChatTarget(model?: string): ChatTarget[] {
  const cat = piCatalog();
  if (model) {
    // One model name can be advertised by several engines (LM Studio :1234,
    // the llama.cpp router :8080, Bifrost :4603). Return EVERY match — a dead
    // engine then falls through to a live one instead of failing the chat.
    // A provider-prefixed id (e.g. lmstudio/<m>) maps to the bare model name.
    const bare = model.includes('/') ? model.slice(model.indexOf('/') + 1) : model;
    const matches = cat.filter((e) => e.id === model || e.name === model || e.model === bare);
    if (matches.length) {
      const seen = new Set<string>();
      return matches.filter((e) => {
        const key = `${e.base}|${e.model}`;
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });
    }
    if (/^(opencode-go|opencode)\//.test(model)) {
      return [{ base: 'http://127.0.0.1:4603/v1', model, label: model, kind: 'online' }];
    }
    const raw: ChatTarget[] = [
      { base: 'http://127.0.0.1:8080/v1', model, label: model, kind: 'local' },
      { base: 'http://127.0.0.1:4603/v1', model, label: model, kind: 'online' },
    ];
    return raw;
  }
  // No choice: this seat's named default first (Rule 07 — env, never a literal in
  // the code), then the operator's Pi default, then any local catalog model.
  const targets: ChatTarget[] = [];
  // `CHAT_MODEL` names the model the chat asks when the operator has not picked
  // one. Without it the first local catalog entry won — `apodex-1.0-mini`, the
  // 21.7 GB preset — so the first message of the day swapped the rail away from
  // the model Pi itself was running (2026-10-23).
  if (CHAT_MODEL_ENV) {
    const named = cat.find(
      (e) => e.model === CHAT_MODEL_ENV || e.id === CHAT_MODEL_ENV || e.name === CHAT_MODEL_ENV,
    );
    if (named) targets.push(named);
  }
  try {
    const s = JSON.parse(read(PI_SETTINGS_PATH)) as { defaultProvider?: string; defaultModel?: string };
    const d = cat.find((e) => e.provider === s.defaultProvider && e.model === s.defaultModel) ?? cat.find((e) => e.provider === s.defaultProvider);
    if (d) targets.push(d);
  } catch {
    /* no settings */
  }
  const local = cat.find((e) => e.kind === 'local');
  if (local && !targets.some((t) => t.base === local.base && t.model === local.model)) targets.push(local);
  for (const base of CHAT_BASES) {
    if (!targets.some((t) => t.base === base)) targets.push({ base, model: '', label: '', kind: base.includes('4603') ? 'online' : 'local' });
  }
  return targets;
}

/** Try the ordered targets; return the first non-empty reply. */
async function chatCompletion(
  messages: { role: string; content: string }[],
  targets: ChatTarget[],
): Promise<{ body: string; backend: string; model: string }> {
  let lastErr = '';
  for (const t of targets) {
    try {
      const model = t.model || (await resolveModel(t.base));
      const headers: Record<string, string> = { 'content-type': 'application/json' };
      if (t.key) headers.authorization = `Bearer ${t.key}`;
      const res = await fetch(`${t.base}/chat/completions`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ model, messages, stream: false, temperature: 0.6, max_tokens: Number(process.env.YMIR_CHAT_MAX_TOKENS ?? 4096) }),   // deepseek-v4.1 spends budget on reasoning FIRST: 700 gave an empty answer
      });
      if (!res.ok) {
        lastErr = `${t.base} → ${res.status}`;
        continue;
      }
      const data = (await res.json()) as { choices?: { message?: { content?: string } }[] };
      const body = data.choices?.[0]?.message?.content?.trim();
      if (body) return { body, backend: t.base, model };
      lastErr = `${t.base} → empty`;
    } catch (err) {
      lastErr = `${t.base} → ${(err as Error).message}`;
    }
  }
  throw new Error(lastErr || 'no chat backend reachable');
}

/** The models the operator has connected: the root Pi catalog (exact ids,
 *  bases, keys), plus any live online backend. Free-typing is still allowed. */
async function chatModels(): Promise<{ id: string; name: string; provider: string; kind: 'local' | 'online' }[]> {
  const out = new Map<string, { id: string; name: string; provider: string; kind: 'local' | 'online' }>();
  for (const e of piCatalog()) out.set(e.id, { id: e.id, name: e.name, provider: e.provider, kind: e.kind });
  // Online providers Pi knows (opencode-go / opencode) — list without probing.
  try {
    const res = await fetch('http://127.0.0.1:4603/v1/models', { signal: AbortSignal.timeout(2500) });
    if (res.ok) {
      const data = (await res.json()) as { data?: { id?: string }[] };
      for (const m of data.data ?? []) {
        const id = m.id ?? '';
        if (id && !out.has(id)) out.set(id, { id, name: id, provider: 'opencode-go', kind: 'online' });
      }
    }
  } catch {
    /* bridge down */
  }
  return [...out.values()].sort((a, b) => a.id.localeCompare(b.id));
}

const KAIA_SYSTEM = [
  'You are Kaia, the oracle by the well (Mimirsbrunn), the orchestrator of the Ymir fleet.',
  'Address the Allfather directly in every reply; never respond with zero direct address.',
  'Apply Norse methodology: name subsystems for the role-matched figure; never use imported terms.',
  'Drink from the well before you answer; when a recall excerpt is provided, ground the reply in it.',
  'Be concise, direct, and action-oriented — produce outcomes, not preamble.',
  'You may dispatch Eindri in the real system; here, state plainly what you recalled and what you would dispatch.',
].join(' ');

interface ChatRow {
  id: string;
  from: 'user' | 'kaia';
  body: string;
  ts: string;
  recalling?: boolean;
  thinking?: boolean;
  error?: boolean;
  model?: string;
  agents?: string[];
}

function chatFile(session: string): string {
  const safe = SAFE_SESSION.test(session) ? session : 'default';
  return join(CHAT_DIR, `${safe}.jsonl`);
}

function chatHistory(session = 'default'): ChatRow[] {
  return read(chatFile(session))
    .split('\n')
    .filter((l) => l.trim().startsWith('{'))
    .map((l) => {
      try {
        return JSON.parse(l) as ChatRow;
      } catch {
        return null;
      }
    })
    .filter(Boolean) as ChatRow[];
}

function appendChat(session: string, row: ChatRow): void {
  mkdirSync(CHAT_DIR, { recursive: true });
  appendFileSync(chatFile(session), `${JSON.stringify(row)}\n`);
}

/** Every stored conversation, newest first; `default` always exists. */
function chatSessions(): { id: string; messages: number; updated_at: string | null }[] {
  mkdirSync(CHAT_DIR, { recursive: true });
  if (!existsSync(chatFile('default'))) appendFileSync(chatFile('default'), '');
  const ids = readdirSync(CHAT_DIR)
    .filter((f) => f.endsWith('.jsonl'))
    .map((f) => f.replace(/\.jsonl$/, ''))
    .filter((id) => SAFE_SESSION.test(id));
  return ids
    .map((id) => {
      const fp = chatFile(id);
      let messages = 0;
      let updated_at: string | null = null;
      try {
        messages = read(fp).split('\n').filter((l) => l.trim().startsWith('{')).length;
        updated_at = statSync(fp).mtime.toISOString();
      } catch {
        /* empty */
      }
      return { id, messages, updated_at };
    })
    .sort((a, b) => (b.updated_at ?? '').localeCompare(a.updated_at ?? ''));
}

function deleteChatSession(session: string): { ok: boolean } {
  try {
    unlinkSync(chatFile(session));
  } catch {
    /* already gone */
  }
  return { ok: true };
}

/** A bounded recall from the well — Kaia drinks before every dispatch.
 *  Relevance to the query first, recency as the tie-break. */
function chatRecall_uncached(query: string, limit = 6): { text: string; count: number } {
  const lines = read(WELL).split('\n').filter((l) => l.trim().startsWith('{'));
  const terms = query
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((w) => w.length > 3);
  const scored: { score: number; source: string; head: string; i: number }[] = [];
  for (const line of lines) {
    try {
      const e = JSON.parse(line) as { content?: string; source?: string };
      const content = String(e.content ?? '');
      const head = content.split('\n')[0].replace(/^#+\s*/, '').trim();
      if (!head) continue;
      const low = content.toLowerCase();
      let score = 0;
      for (const t of terms) if (low.includes(t)) score++;
      scored.push({ score, source: e.source ?? 'well', head, i: scored.length });
    } catch {
      /* skip malformed */
    }
  }
  scored.sort((a, b) => b.score - a.score || b.i - a.i);
  const picks = scored.slice(0, limit);
  return {
    text: picks.map((p) => `- (${p.source}) ${p.head.slice(0, 140)}`).join('\n'),
    count: picks.length,
  };
}

function chatRecall(query: string, limit = 6): { text: string; count: number } {
  return memo(`chatRecall:${query}:${limit}`, 3000, () => chatRecall_uncached(query, limit));
}

async function postChat(
  session: string,
  content: string,
  model?: string,
  agents?: string[],
): Promise<{ reply: ChatRow; live: boolean }> {
  mkdirSync(CHAT_DIR, { recursive: true });
  const sid = SAFE_SESSION.test(session) ? session : 'default';
  const user: ChatRow = { id: `u-${Date.now()}`, from: 'user', body: content, ts: new Date().toISOString() };
  appendChat(sid, user);

  // Rolling window of the last 40 messages — the context Kaia keeps in view.
  const history = chatHistory(sid).slice(-CHAT_WINDOW);
  const recall = chatRecall(content);
  const lanes = agents?.length ? `\n\nFocused Eindri lanes: ${agents.join(', ')}.` : '';
  const messages = [
    {
      role: 'system',
      content: `${KAIA_SYSTEM}${lanes}\n\nWell recall:\n${recall.text || '(dry — answer from first principles, and say the well was dry)'}`,
    },
    ...history.map((m) => ({ role: m.from === 'user' ? 'user' : 'assistant', content: m.body })),
  ];

  let body: string;
  let live = false;
  let usedModel: string | undefined;
  try {
    const out = await chatCompletion(messages, resolveChatTarget(model));
    body = out.body;
    usedModel = out.model;
    live = true;
  } catch (err) {
    body = `The well is local; no model backend answered (${(err as Error).message}). Recall ran; for a reply, raise a local model (llama-server on :8080) or the Bifrost bridge (\`bin/bridge/bifrost-bridge.sh\`).`;
  }

  const kaia: ChatRow = {
    id: `k-${Date.now()}`,
    from: 'kaia',
    body,
    ts: new Date().toISOString(),
    recalling: recall.count > 0,
    ...(usedModel ? { model: usedModel } : {}),
    ...(agents?.length ? { agents } : {}),
    ...(live ? {} : { error: true }),
  };
  appendChat(sid, kaia);
  return { reply: kaia, live };
}

/* ---- /api/prompts — the smithy's agent prompts, editable in the Forge ---- */
const PROMPT_ROOT = join(ROOT, 'smidja/smidja_data/prompt_engineering');

interface PromptFile {
  agent: string;
  kind: 'system' | 'user';
  path: string;
  body: string;
}

function prompts(): PromptFile[] {
  if (!existsSync(PROMPT_ROOT)) return [];
  const out: PromptFile[] = [];
  for (const agent of readdirSync(PROMPT_ROOT).sort()) {
    const dir = join(PROMPT_ROOT, agent);
    try {
      if (!statSync(dir).isDirectory()) continue;
    } catch {
      continue;
    }
    for (const kind of ['system', 'user'] as const) {
      const fp = join(dir, `${kind}.md`);
      if (existsSync(fp)) {
        out.push({ agent, kind, path: `smidja/smidja_data/prompt_engineering/${agent}/${kind}.md`, body: read(fp) });
      }
    }
  }
  return out;
}

function savePrompt(agent: string, kind: string, body: string): { ok: boolean; path: string } {
  if (!/^[A-Za-z0-9._-]+$/.test(agent) || (kind !== 'system' && kind !== 'user')) {
    throw new Error('bad prompt id');
  }
  const fp = join(PROMPT_ROOT, agent, `${kind}.md`);
  mkdirSync(dirname(fp), { recursive: true });
  writeFileSync(fp, body);
  return { ok: true, path: `smidja/smidja_data/prompt_engineering/${agent}/${kind}.md` };
}

/* ---- /api/workspaces + /api/setup — single-tenant workspaces ------------ */
function workspaces(): { id: string; name: string; kind: string; company?: string; domains: string[] }[] {
  let regPath = join(ROOT, 'registry/workspaces.yaml');
  const hoardReg = join(HOARD, 'identity/workspaces.yaml');
  try { read(hoardReg); regPath = hoardReg; } catch { /* fall back to the tracked scaffold */ }
  const txt = read(regPath);
  const out: { id: string; name: string; kind: string; company?: string; domains: string[] }[] = [];
  let cur: { id: string; name: string; kind: string; company?: string; domains: string[] } | null = null;
  for (const line of txt.split('\n')) {
    const idm = line.match(/^\s*-\s+id:\s*(\S+)/);
    if (idm) {
      if (cur) out.push(cur);
      cur = { id: idm[1], name: idm[1], kind: 'personal', domains: [] };
      continue;
    }
    if (!cur) continue;
    const nm = line.match(/^\s*name:\s*(.+)$/);
    if (nm) cur.name = nm[1].trim();
    const km = line.match(/^\s*kind:\s*(\S+)/);
    if (km) cur.kind = km[1];
    const cm = line.match(/^\s*company:\s*(\S+)/);
    if (cm) cur.company = cm[1];
    const dm = line.match(/^\s*domains:\s*\[(.*)\]/);
    if (dm) cur.domains = dm[1].split(',').map((s) => s.trim()).filter(Boolean);
  }
  if (cur) out.push(cur);
  return out.length ? out : [
    { id: 'work', name: 'Work', kind: 'work', domains: ['company', 'marketing', 'development', 'life'] },
    { id: 'personal', name: 'Personal', kind: 'personal', domains: ['me', 'life', 'development'] },
  ];
}

async function setupStatus() {
  return parseToon(await runAsync(['bash', 'bin/engine/ymir-install.sh', '--check'], 30000));
}
function setupRun() {
  return parseToon(run(['bash', 'bin/engine/ymir-install.sh', '--skip-services']));
}
function workspaceProvision(name: string, kind: string, domains: string) {
  return parseToon(run(['bash', 'bin/agents/workspace-provision.sh', name, '--kind', kind, '--domains', domains]));
}

/* ---- the halls are LOCAL (plan 275 item 30, plans 277 and 279) ------------ *
 * The three apps are not hosted: they run on this machine, they listen on
 * loopback, and the DESKTOP SESSION is the authority. The hosted era left a login
 * inside the gate (`HLIDSKJALF_AUTH`, an accounts store, invite codes, a GitHub
 * door), a chooser that asked which of three halls to enter, and a set of public
 * hostnames the gate fronted behind that login. None of it survives: nothing here
 * asks who you are, because nobody but this machine's own user can reach a
 * loopback port. Hosted, shared surfaces are Gimlé's (plan 284), not a hall's.
 */
const DIST = join(ROOT, 'apps/hlidskjalf/dist');

/** The peer address per request: Bun's Request has no socket, so it is recorded
 *  at the top of the handler. The voice and Rödd doors need it — they are the two
 *  surfaces that still judge WHERE a request came from, and they refuse anything
 *  that is not loopback. */
const REQUEST_IP = new WeakMap<Request, string>();

/** Who is behind a request: on a local seat, there is exactly one answer. */
function seatOf(req: Request): string {
  const h = new URL(req.url).hostname;
  return h === '127.0.0.1' || h === 'localhost' || h === '[::1]' ? 'operator' : 'local';
}

/** The login behind a request. The halls carry no session any more (item 30):
 *  the desktop session is the authority, so this answers only for `seatOf`. */
function loginOf(req: Request): string | null {
  return new URL(req.url).hostname === '127.0.0.1' ? 'operator' : null;
}

const STATIC_TYPES: Record<string, string> = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.map': 'application/json',
  '.json': 'application/json',
  '.webmanifest': 'application/manifest+json',
  '.xml': 'application/xml',
  '.txt': 'text/plain; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.wasm': 'application/wasm',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.apk': 'application/vnd.android.package-archive',
};

function serveStatic(pathname: string): Response {
  const rel = pathname === '/' ? 'index.html' : pathname.replace(/^\/+/, '');
  let file = join(DIST, rel);
  if (!file.startsWith(DIST) || !existsSync(file) || statSync(file).isDirectory()) file = join(DIST, 'index.html');
  const ext = extname(file).toLowerCase();
  const headers: Record<string, string> = { 'content-type': STATIC_TYPES[ext] ?? 'application/octet-stream' };
  if (ext === '.html') headers['cache-control'] = 'no-cache, no-store, must-revalidate';
  if (ext === '.apk') headers['content-disposition'] = 'attachment; filename="ymir.apk"';
  if (ext === '.apk' || ext === '.woff' || ext === '.woff2' || ext === '.ttf') headers['cache-control'] = 'public, max-age=86400';
  try {
    return new Response(readFileSync(file), { headers });
  } catch {
    return new Response('Not found', { status: 404 });
  }
}

/* ---- server -------------------------------------------------------------- */
// The halls are LOCAL. A bind beyond loopback is refused unless the operator
// says so out loud (YMIR_ALLOW_WIDE_BIND=1), because "no app opens a port beyond
// loopback" is the promise the login used to pretend to keep (item 30).
const HOST = process.env.HLIDSKJALF_HOST ?? '127.0.0.1';
const LOOPBACK_HOSTS = new Set(['127.0.0.1', 'localhost', '::1', '[::1]']);
if (!LOOPBACK_HOSTS.has(HOST) && process.env.YMIR_ALLOW_WIDE_BIND !== '1') {
  console.error(`[hlidskjalf] refusing to listen on ${HOST}: the halls are loopback only.`);
  console.error('[hlidskjalf] A hosted, shared surface belongs to Gimlé (plan 284).');
  console.error('[hlidskjalf] To override for a deliberate test: YMIR_ALLOW_WIDE_BIND=1');
  process.exit(2);
}
const server = Bun.serve({
  hostname: HOST,
  port: PORT,
  async fetch(req, srv) {
    const url = new URL(req.url);
    const p = url.pathname;
    // Bun's Request carries no socket; the peer address comes from the server.
    // Recorded per request (a WeakMap, so concurrent requests cannot mix).
    REQUEST_IP.set(req, srv.requestIP(req)?.address ?? '');
    try {
      // The halls carry no login (plan 275 item 30): no /api/login, no
      // /api/register, no invite, no GitHub door, and no host the gate fronts
      // behind one. What the face asks at boot is who this seat is, and the
      // answer is the machine's own operator.
      if (p === '/api/session') {
        return json({ login: 'operator', surface: 'local', doc: 'docs/features/hlidskjalf-the-control-plane.md' });
      }
      if (p === '/api/rodd' || p.startsWith('/api/rodd/')) {
        // The loopback and same-origin wards stay (they are the real lock on a
        // local door); the session dependence is gone with the logins.
        const refusal = voiceAccess(req, REQUEST_IP.get(req) ?? '', true);
        if (refusal) return refusal;
        return rodd(req);
      }
      if (p.startsWith('/api/skirnir/voice/')) {
        const refusal = voiceAccess(req, REQUEST_IP.get(req) ?? '', true);
        if (refusal) return refusal;
        return voice(req, seatOf(req) ?? 'operator');
      }
      if (p === '/api/health') return json({ ok: true, root: ROOT, sessions: orders().length });
      // The leak ledger and the last soak of every app (plan 286 P6): the Health
      // view on the Runtime page. Read-only, memoised — see soakHealth().
      if (p === '/api/soak') return json(soakHealth());
      if (p === '/api/mail/accounts') {
        if (req.method !== 'GET') return json({ error: 'method not allowed' }, 405);
        return mailDesk('/accounts');
      }
      if (p === '/api/mail/queue') {
        if (req.method !== 'GET') return json({ error: 'method not allowed' }, 405);
        return mailDesk('/queue', {
          account: url.searchParams.get('account') ?? '',
          hours: url.searchParams.get('hours') ?? '48',
        });
      }
      if (p === '/api/mail/message') {
        if (req.method !== 'GET') return json({ error: 'method not allowed' }, 405);
        return mailDesk('/message', {
          account: url.searchParams.get('account') ?? '',
          id: url.searchParams.get('id') ?? '',
        });
      }
      // Þráðr's status strip (plan 93): the panel asked for a door this gate never had,
      // so it printed "terminal status 404" — an error string where a truth belongs.
      // There is no pty in this process (the backend is a separate errand), so the route
      // reports the seat's real capability instead of pretending to hold a shell.
      if (p === '/api/terminal/status') return json({
        enabled: process.env.YMIR_TERMINAL === '1',
        remoteAllowed: process.env.YMIR_TERMINAL_REMOTE === '1',
        shell: process.env.SHELL || '/bin/bash',
        cwd: ROOT,
        open: 0,
        maxPerUser: Number(process.env.YMIR_TERMINAL_MAX_PER_USER ?? 2),
        idleTimeoutMs: Number(process.env.YMIR_TERMINAL_IDLE_MS ?? 900_000),
        reason: (process.env.YMIR_TERMINAL === '1')
          ? 'enabled, but this gate holds no pty — the terminal backend is plan 93'
          : 'disabled: YMIR_TERMINAL is not 1, and this gate holds no pty',
      });
      if (p === '/api/usage') {
        // What the HARNESSES spent — opencode and pi — not only the smithy's runs.
        // Memoised for a minute: the aggregate is one bounded SQL statement over a
        // 37 GB store, and a panel must not pay for it on every poll.
        return json(await memoAsync('usage', 60_000, async () => {
          try {
            const { execFileSync } = await import('node:child_process');
            const script = new URL('../../../bin/desktop/hlidskjalf-usage.sh', import.meta.url).pathname;
            const out = execFileSync(script, ['--days', process.env.YMIR_USAGE_DAYS ?? '30'], { timeout: 60_000 }).toString().trim();
            return JSON.parse(out);
          } catch (e) {
            return { error: String(e).slice(0, 120) };
          }
        }));
      }
      if (p === '/api/core-four') {
        // THE FOUR DIALS, one read (plan 199). The door does the reading; this only carries it.
        return json(await memoAsync('core-four', 30_000, async () => {
          try {
            const { execFileSync } = await import('node:child_process');
            const script = new URL('../../../bin/seat/core-four.sh', import.meta.url).pathname;
            return JSON.parse(execFileSync('bash', [script, '--json'], { timeout: 30_000, cwd: ROOT }).toString().trim());
          } catch (e) {
            return { error: String(e).slice(0, 160) };
          }
        }));
      }
      if (p === '/api/rank' && req.method === 'POST') {
        // THE HALL MAY RANK (2026-11-09, plan 229 — his word: "fix it all then").
        // Transport is bin/seat/rank.sh: one `score` question per jev category, asked of a
        // decision door. The POLICY is jev's own, imported from the vendored copy
        // (apps/odrerir/src/vendor/jev/policy.ts) rather than re-derived here — a second table
        // of thresholds is how one question gets two answers. A dark door yields no scores at
        // all, so the cards keep saying "Not ranked yet".
        const body = (await req.json().catch(() => ({}))) as { items?: { id?: string; text?: string }[] };
        const items = (body.items ?? []).filter((i) => i && i.id && i.text).slice(0, 40);
        if (!items.length) return json({ error: 'rank needs items: [{id, text}]' }, 400);
        const seed = `rank:${Bun.hash(JSON.stringify(items)).toString(36)}`;
        return json(await memoAsync(seed, 120_000, async () => {
          try {
            const { execFileSync } = await import('node:child_process');
            const script = new URL('../../../bin/seat/rank.sh', import.meta.url).pathname;
            const out = execFileSync('bash', [script], {
              input: JSON.stringify(items),
              timeout: 120_000,
              cwd: ROOT,
            }).toString().trim();
            const raw = JSON.parse(out) as {
              door?: string;
              answers?: Record<string, Record<string, unknown>>;
              failed?: string[];
              error?: string;
            };
            if (raw.error || !raw.answers) return { error: raw.error ?? 'rank: no answers', ranked: {} };
            const { rankHfs } = await import('../../odrerir/src/vendor/jev/policy.ts');
            const ranked: Record<string, unknown> = {};
            for (const [id, answers] of Object.entries(raw.answers)) {
              try {
                ranked[id] = rankHfs(answers as never);
              } catch {
                // A card with no usable answer stays unranked — never a zero in its place.
              }
            }
            return { door: raw.door, ranked, failed: raw.failed ?? [] };
          } catch (e) {
            return { error: String(e).slice(0, 160), ranked: {} };
          }
        }));
      }
      if (p === '/api/context') {
        // THIS SESSION'S SHAPE, one read (plan 229). The governed asset has declared this
        // door since plan 199 and the gate never served it (404 "no route"), so the near
        // board's window card lost its session line while bin/seat/context.sh sat behind it
        // answering correctly. A carrier, like its neighbours: run the door, cache briefly,
        // never re-implement what the door knows.
        return json(await memoAsync('context', 15_000, async () => {
          try {
            const { execFileSync } = await import('node:child_process');
            const script = new URL('../../../bin/seat/context.sh', import.meta.url).pathname;
            return JSON.parse(
              execFileSync('bash', [script, '--json'], { timeout: 30_000, cwd: ROOT }).toString().trim(),
            );
          } catch (e) {
            return { error: String(e).slice(0, 160) };
          }
        }));
      }
      if (p === '/api/pending') {
        // WHAT WAITS ON THE OPERATOR, one list (plan 199). Never cached long: it is a live question.
        return json(await memoAsync('pending', 15_000, async () => {
          try {
            const { execFileSync } = await import('node:child_process');
            const script = new URL('../../../bin/seat/pending.sh', import.meta.url).pathname;
            return JSON.parse(execFileSync('bash', [script, '--json'], { timeout: 30_000 }).toString().trim());
          } catch (e) {
            return { error: String(e).slice(0, 160), items: [] };
          }
        }));
      }
      if (p === '/api/plans') {
        // THE PLAN LEDGER, read from the record itself. Skuld's plans table has been empty
        // while the ledger carries every plan as a file (2026-11-05) — so the hall reads the
        // ledger, and Skuld stays the write door for tickets.
        return json(await memoAsync('plans', 30_000, async () => {
          const { readdirSync, readFileSync } = await import('node:fs');
          const { join } = await import('node:path');
          const home = (await import('node:os')).homedir();
          const dir = process.env.YMIR_PLANS_DIR ??
            join(home, 'Documents/ymirhome/svartalfaheim/whynotproductions/projects/ymir/plans');
          const rows: Array<{ n: number; slug: string; state: string; title: string }> = [];
          try {
            for (const f of readdirSync(dir)) {
              const m = /^(\d+)-(.+)\.md$/.exec(f);
              if (!m) continue;
              const body = readFileSync(join(dir, f), 'utf8').slice(0, 4000);
              const title = (body.split('\n').find((l) => l.startsWith('# ')) ?? '').replace(/^#\s*/, '') ||
                m[2].replace(/-/g, ' ');
              const state = /status:\s*`?([a-z -]+)/i.exec(body)?.[1]?.trim() ??
                (/#?\bopen(ed)?\b/i.test(body.slice(0, 600)) ? 'opened' : 'in progress');
              rows.push({ n: Number(m[1]), slug: m[2], state, title });
            }
          } catch {
            /* an absent ledger is an empty list, and the panel says so */
          }
          rows.sort((a, b) => b.n - a.n);
          return { count: rows.length, plans: rows.slice(0, 200) };
        }));
      }
      if (p === '/api/worktrees') return json(await worktrees());
      if (p === '/api/me') return json({ login: loginOf(req) ?? 'operator', realm: 'work' });
      if (p === '/api/workspace') {
        const realm = url.searchParams.get('realm') ?? 'work';
        return json({ realm, path: workspaceRoot(realm) });
      }
      if (p === '/api/agents') {
        // WHO IS STANDING, not who could be. The connector reads herdr's live
        // pane list, so every opencode and pi session appears on the board with
        // its kind, state and task. The roster is the fallback, never the answer.
        try {
          const { execFileSync } = await import('node:child_process');
          const script = new URL('../../../bin/desktop/hlidskjalf-agents.sh', import.meta.url).pathname;
          // cwd is ROOT and ROSTER_DIR is the absolute roster, so the connector's
          // roster path cannot resolve against the wrong directory.
          const out = execFileSync(script, [], {
            timeout: 4000,
            cwd: ROOT,
            env: { ...process.env, ROSTER_DIR: AGENTS_ALT },
          }).toString().trim();
          // An EMPTY array is not data: herdr was absent or no pane answered.
          // Fall through to the roster, exactly as the comment below promises.
          if (out.startsWith('[')) {
            const rows = JSON.parse(out) as unknown;
            if (Array.isArray(rows) && rows.length > 0) {
              return new Response(out, { headers: { 'content-type': 'application/json' } });
            }
          }
        } catch {
          // herdr absent or the connector failed: fall through to the roster
        }
        return json(agents());
      }
      if (p === '/api/tasks') return json(tasks());
      if (p === '/api/a2a/messages') {
        const n = Number(url.searchParams.get('n') ?? 60);
        return json(a2aMessages(Number.isFinite(n) ? n : 60));
      }
      /* /api/doors — WHERE AN APP AND AN AGENT CAN BE INSPECTED (plan 275 item 19).
       * The ports live in ONE table (bin/desktop/app-lib.sh) and the pane list in ONE
       * connector; this door runs the script that reads both, so the Fleet page and a
       * human at a terminal never disagree about which port answers. */
      if (p === '/api/doors') {
        return json(
          await memoAsync('doors', 10_000, async () => {
            try {
              const { execFileSync } = await import('node:child_process');
              const script = new URL('../../../bin/desktop/hlidskjalf-doors.sh', import.meta.url).pathname;
              return JSON.parse(execFileSync('bash', [script], { timeout: 20_000 }).toString().trim());
            } catch (e) {
              return { apps: [], agents: [], apps_up: 0, agents_seated: 0, error: String(e).slice(0, 120) };
            }
          }),
        );
      }
      if (p === '/api/orders') return json({ open: orders().filter((o) => o.status !== 'COMPLETED').length, orders: orders() });
      if (p === '/api/runes') return json(runes());
      if (p === '/api/well') return json(await well(url.searchParams.get('q') ?? ''));
      if (p === '/api/well/episode') return json((await wellEpisode(url.searchParams.get('id') ?? '')) ?? { error: 'not found' });
      if (p === '/api/mimir/health') return json(await mimirHealth());
      if (p === '/api/processes') return json(await processes());
      if (p === '/api/ward') return json(wardState());
      // The reviews gate shells out twice (lint + compliance), each with a 60s cap,
      // so an unmemoised poll leaves Glitnir hanging for a minute and reads as a
      // dead surface. One answer per minute is what a human review board needs.
      if (p === '/api/reviews') return json(await memoAsync('reviews', 60_000, reviews));
      // Skrymir's root is the WHOLE home (plan 275 item 21); `realm` is honoured
      // as the folder it now is, so an old client still lands somewhere true.
      if (p === '/api/files') {
        const rel = url.searchParams.get('path') ?? '';
        const realm = url.searchParams.get('realm') ?? '';
        return json(files(rel || (realm ? join('svartalfaheim', realm) : '')));
      }
      if (p === '/api/file') {
        const rel = url.searchParams.get('path') ?? '';
        const realm = url.searchParams.get('realm') ?? '';
        return json(fileContent(rel || (realm ? join('svartalfaheim', realm) : '')));
      }
      if (p === '/api/skills') return json(skills());
      if (p === '/api/runtime') {
        // No memo here: `runtime()` is cheap now (the digest is read in the
        // background and the release matrix is spawned once per poll), and the
        // page must see `reading: false` the moment the digest lands.
        return json(await runtime());
      }
      // A speed-start from the UI. It calls the same launcher the Omarchy key
      // bindings use, so the app is raised when it is already up and started
      // when it is not — one way to raise a Ymir window, not two.
      if (p === '/api/desktop' && req.method === 'POST') {
        const body = (await req.json().catch(() => ({}))) as { view?: string };
        const view = body?.view;
        // odrerir is the fourth hall: its board is read-only, but its WINDOW is an
        // Electron app like the others, so a rune must raise it, never open a tab.
        const VIEWS = ['hlidskjalf', 'smidja', 'sessrumnir', 'odrerir'] as const;
        if (!VIEWS.includes(view as (typeof VIEWS)[number])) {
          return json({ error: 'view must be hlidskjalf, smidja, sessrumnir, or odrerir' }, 400);
        }
        // Hlidskjalf and Smíðja are views of the one Electron shell; Sessrúmnir
        // is its own app with its own launcher.
        const argv = view === 'sessrumnir'
          ? ['bash', join(ROOT, 'bin', 'sessrumnir.sh'), 'start']
          : ['bash', join(ROOT, 'scripts', 'electron.sh'), 'start', '--view', view];
        const proc = Bun.spawn(argv, { stdout: 'pipe', stderr: 'pipe', env: process.env });
        const out = await new Response(proc.stdout).text();
        await proc.exited;
        return json({ view, ok: proc.exitCode === 0, output: out.trim().slice(-400) });
      }
      if (p === '/api/calendar') return json(calendar());
      if (p === '/api/cron') return json(await cron());
      if (p === '/api/cron/start' && req.method === 'POST') return json(await cronAct('start'));
      if (p === '/api/cron/stop' && req.method === 'POST') return json(await cronAct('stop'));
      if (p === '/api/cron/seats') return json(await cronSeats());
      if (p === '/api/loaders') return json(await loaders());
      if (p === '/api/checks') return json(await checks());
      if (p === '/api/smidja/health') return json(smidjaHealth());
      if (p === '/api/smidja/sessions') return json(smidjaSessions());
      if (p === '/api/smidja/decisions') return json(smidjaDecisions());
      if (p === '/api/smidja/stats') return json(smidjaStats());
      if (p === '/api/snotra/live') {
        if (req.method !== 'GET') return json({ error: 'method not allowed' }, 405);
        return json(await liveStatus());
      }
      if (p === '/api/snotra/live/start' && req.method === 'POST') {
        const b = (await req.json().catch(() => ({}))) as { slug?: string; topic?: string };
        // The script sanitises the slug itself; the gate does the SAME shaping so
        // the operator is shown the name that will actually be written.
        const slug =
          (b.slug ?? '')
            .trim()
            .replace(/[^a-zA-Z0-9._-]/g, '-')
            .replace(/^-+|-+$/g, '') || 'note';
        const topic = (b.topic ?? '').trim();
        const script = join(ROOT, LIVE_SCRIPT);
        if (!existsSync(script)) return json({ ok: false, error: 'snotra-live.sh is not on this seat' }, 500);
        // A stop that is still draining owns the ear; opening a second one now
        // would race it. The gate KNOWS this — the script's own probe cannot see
        // its own detached child.
        if (liveClosing) return json({ ok: false, error: 'the last book is still closing — wait for it' }, 409);
        // `start` returns as soon as the capture is alive, so a bounded wait is
        // right here (the /api/desktop precedent). `stop` is the slow one.
        const proc = Bun.spawnSync(['timeout', '20', 'bash', script, 'start', slug, ...(topic ? [topic] : [])], {
          cwd: ROOT,
          stdout: 'pipe',
          stderr: 'pipe',
          // THIS BUTTON IS THE SANCTIONED LOCAL-ROOM DOOR (the Allfather's word,
          // 2026-10-31: "we have a button in Hlidskjalf that should activate the
          // mic. that's the main way to the mic"). The script refuses the
          // microphone unless the caller says the room is local, so the gate is
          // the ONE place that says it — and it says it for a room of people
          // physically here, never for an online meeting (that is the bot's job).
          env: { ...process.env, SNOTRA_LOCAL_ROOM: '1' },
        });
        const out = new TextDecoder().decode(proc.stdout ?? new Uint8Array()).trim();
        const err = new TextDecoder().decode(proc.stderr ?? new Uint8Array()).trim();
        if (proc.exitCode !== 0) {
          // ONE EAR AT A TIME: the refusal is the SCRIPT'S OWN sentence (it says
          // which ear is busy), never a generic error invented by the surface.
          const said = (out || err).split('\n').find((l) => l.trim()) ?? 'the live tail refused to open';
          return json({ ok: false, error: said.trim() }, 409);
        }
        return json({ ok: true, slug, said: out });
      }
      if (p === '/api/snotra/live/stop' && req.method === 'POST') {
        const script = join(ROOT, LIVE_SCRIPT);
        if (!existsSync(script)) return json({ closing: false, error: 'snotra-live.sh is not on this seat' }, 500);
        if (liveClosing) return json({ closing: true });
        const before = parseLiveRow(await runAsync(['bash', LIVE_SCRIPT, 'status'], 0));
        if (before.state !== 'listening') {
          // The script's own wording for this door, so the surface never invents one.
          return json({ closing: false, error: 'no live tail is running' }, 409);
        }
        // DETACHED ON PURPOSE. `stop` joins every slice, re-transcribes the
        // recording, asks the rail for a summary, writes the minutes and carves
        // a Rune — MINUTES on a long meeting. A browser waiting on that POST
        // times out and looks broken while the work is fine. Answer now, let the
        // surface poll `closing` until the script has finished.
        const proc = Bun.spawn(['bash', script, 'stop'], { cwd: ROOT, stdout: 'ignore', stderr: 'ignore', env: process.env });
        liveClosing = { since: Date.now(), done: proc.exited.then(() => { liveClosing = null; }) };
        return json({ closing: true });
      }
      if (p.startsWith('/api/smidja/sessions/')) {
        const id = decodeURIComponent(p.slice('/api/smidja/sessions/'.length));
        const detail = smidjaSession(id);
        return detail ? json(detail) : json({ error: `no session ${id}` }, 404);
      }
      if (p === '/api/snotra/meetings' && req.method === 'GET') return json({ meetings: snotraMeetings() });
      if (p === '/api/snotra/meeting' && req.method === 'GET') {
        const id = url.searchParams.get('id') ?? '';
        const m = snotraFind(id);
        if (!m) return json({ error: 'no meeting' }, 404);
        const body = ['minutes.md', 'record.md'].map((f) => join(m.dir, f)).find(existsSync);
        const src = ['record.json', 'meeting.json'].map((f) => join(m.dir, f)).find(existsSync);
        let detail: Record<string, unknown> = {};
        if (src) { try { detail = JSON.parse(readFileSync(src, 'utf8')); } catch { /* broken record */ } }
        return json({ ...m, record: body ? readFileSync(body, 'utf8') : null,
          decisions: (detail as any).decisions ?? [], actions: (detail as any).actions ?? [] });
      }
      if (p === '/api/snotra/draft' && req.method === 'POST') {
        const b = (await req.json().catch(() => ({}))) as { id?: string };
        const r = snotraDraft(String(b.id ?? ''));
        return 'error' in r ? json(r, 400) : json(r);
      }
      if (p === '/api/snotra/send' && req.method === 'POST') {
        const b = (await req.json().catch(() => ({}))) as { draftId?: string };
        const r = snotraSend(String(b.draftId ?? ''));
        return 'error' in r ? json(r, 400) : json(r);
      }
      if (p === '/api/settings') return json(settings());
      if (p === '/api/workspaces' && req.method === 'GET') return json(workspaces());
      if (p === '/api/workspaces' && req.method === 'POST') {
        const b = (await req.json().catch(() => ({}))) as { name?: string; kind?: string; domains?: string[] | string };
        const name = (b.name ?? '').trim().toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/(^-|-$)/g, '');
        if (!name) return json({ error: 'workspace needs a name' }, 400);
        const kind = b.kind === 'work' ? 'work' : 'personal';
        const domains = Array.isArray(b.domains) ? b.domains.join(',') : b.domains ?? '';
        return json(workspaceProvision(name, kind, domains));
      }
      if (p === '/api/setup/status') return json(await setupStatus());
      if (p === '/api/setup/run' && req.method === 'POST') return json(setupRun());
      if (p === '/api/prompts' && req.method === 'GET') return json(prompts());
      if (p === '/api/prompts' && req.method === 'POST') {
        const body = (await req.json().catch(() => ({}))) as { agent?: string; kind?: string; body?: string };
        if (!body.agent || !body.kind) return json({ error: 'prompt needs agent + kind' }, 400);
        return json(savePrompt(body.agent, body.kind, body.body ?? ''));
      }
      if (p === '/api/stream') return stream();
      if (p === '/api/chat/models') return json(await chatModels());
      if (p === '/api/chat/sessions') return json(chatSessions());
      if (p === '/api/chat/history') return json(chatHistory(url.searchParams.get('session') ?? 'default'));
      if (p === '/api/chat/session' && req.method === 'DELETE') {
        return json(deleteChatSession(url.searchParams.get('session') ?? 'default'));
      }
      if (p === '/api/chat' && req.method === 'POST') {
        const body = (await req.json().catch(() => ({}))) as {
          session?: string;
          content?: string;
          model?: string;
          agents?: string[];
        };
        const content = (body.content ?? '').trim();
        if (!content) return json({ error: 'chat needs content' }, 400);
        return json(await postChat(body.session ?? 'default', content, body.model, body.agents));
      }
      if (p.startsWith('/api/')) return json({ error: `no route ${p}` }, 404);
      return serveStatic(p);
    } catch (err) {
      return json({ error: (err as Error).message }, 500);
    }
  },
});

console.log(`[hlidskjalf] gate api   http://127.0.0.1:${server.port}`);
console.log(`[hlidskjalf] runtime    ${ROOT}`);

/* ---- /api/ward — HIMINBJÖRG, the watchtower ------------------------------- */
// Garmr notices, Vörðr judges, Gná speaks. The tower shows what the hound wrote:
// the state of the two units, the heartbeat (a silent hound is a finding), and the
// newest judgements. It reads files only; it never starts, stops or closes anything.
function wardState() {
  // the home is already resolved once at the top of this file (Rule 07): env ->
  // the recorded choice -> one default. Never a second guess here.
  const home = HOME_DIR;
  const judged = join(home, 'hodd/state/garmr/judged.jsonl');
  const pausedMarker = join(home, 'hodd/state/garmr/PAUSED');
  const heartbeatFile = '/var/log/ymir/garmr/state/hound.heartbeat';
  const findingsFile = '/var/log/ymir/garmr/findings.jsonl';

  const counts: Record<string, number> = { INFO: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0 };
  const newest: Array<Record<string, unknown>> = [];
  let totalJudged = 0;
  if (existsSync(judged)) {
    const lines = read(judged).split('\n').filter((l) => l.trim().startsWith('{'));
    totalJudged = lines.length;
    for (const line of lines.slice(-2000)) {
      try {
        const row = JSON.parse(line);
        const sev = String(row.severity ?? 'INFO');
        counts[sev] = (counts[sev] ?? 0) + 1;
        if (sev === 'HIGH' || sev === 'CRITICAL') {
          newest.push({
            ts: row.ts ?? '', severity: sev, line: row.line ?? '', title: row.title ?? '',
            comm: row.comm ?? '', pid: row.pid ?? '',
            reasoning: row.reasoning ? { rung: row.reasoning.rung, model: row.reasoning.model } : null,
          });
        }
      } catch { /* a torn line is not a reason to fail the panel */ }
    }
  }

  const beat = existsSync(heartbeatFile) ? read(heartbeatFile).trim() : '';
  const beatAgeSeconds = beat ? Math.max(0, Math.round((Date.now() - Date.parse(beat)) / 1000)) : -1;
  const findingsLines = existsSync(findingsFile)
    ? read(findingsFile).split('\n').filter((l) => l.trim()).length : 0;

  // Skírnir: a bot that stopped answering must be visible, not discovered
  const assistantDir = join(home, 'hodd/state/assistant');
  const beatFile = join(assistantDir, 'telegram.heartbeat');
  const assistantBeat = existsSync(beatFile) ? read(beatFile).trim() : '';
  const beatAge = assistantBeat ? Math.max(0, Math.round((Date.now() - Date.parse(assistantBeat)) / 1000)) : -1;
  let lastAnswer = '';
  let refusalsToday = 0;
  let turnsToday = 0;
  const assistantDb = join(assistantDir, 'assistant.db');
  if (existsSync(assistantDb)) {
    try {
      const db = new Database(assistantDb, { readonly: true });
      const today = new Date().toISOString().slice(0, 10);
      const last = db.query('select ts from turns order by rowid desc limit 1').get() as { ts?: string } | null;
      lastAnswer = last?.ts ?? '';
      const refused = db.query('select count(*) as n from conversations where ts like ? and refused = 1').get(`${today}%`) as { n: number };
      const all = db.query('select count(*) as n from conversations where ts like ?').get(`${today}%`) as { n: number };
      refusalsToday = refused?.n ?? 0;
      turnsToday = all?.n ?? 0;
      db.close();
    } catch { /* the assistant is new: report zero rather than fail the panel */ }
  }
  const assistant = { heartbeat: assistantBeat, heartbeatAgeSeconds: beatAge,
                      live: beatAge >= 0 && beatAge < 300,
                      lastAnswer, refusalsToday, turnsToday };

  return {
    paused: existsSync(pausedMarker),
    heartbeat: beat,
    heartbeatAgeSeconds: beatAgeSeconds,
    silent: beatAgeSeconds === -1 || beatAgeSeconds > 600,
    findings: findingsLines,
    // `judged` is the whole record; bySeverity is the recent window the panel shows.
    // Reporting the window as the total made the tower say "2,000 judged" over a
    // 20,000-line ledger — a small lie in a security surface is still a lie.
    judged: totalJudged,
    bySeverity: counts,
    newest: newest.slice(-25).reverse(),
    assistant,
    door: 'bin/ward/garmr.sh',
  };
}
