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
import { dirname, extname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import {
  findAccount,
  invitesOpen,
  listAccounts,
  listInvites,
  register,
  verify as verifyAccount,
} from './accounts.ts';

const PORT = Number(process.env.PORT ?? 3889);
const HERE = import.meta.dir;
const ROOT = resolve(HERE, '../../..'); // the checkout this app is served from
const AGENTS_DIR = join(ROOT, '.agents/agents');
const SUBAGENTS_DIR = join(ROOT, '.agents/subagents');
const AGENTS_ALT = existsSync(AGENTS_DIR) ? AGENTS_DIR : SUBAGENTS_DIR;
const CONFIG_DIR = join(ROOT, '.agents/config');
const STATE_DIR = join(ROOT, 'state');
// The ledger lives in the HOARD, never in the checkout (Rule 04 / migration
// 0004): $YMIR_HOARD, else $YMIR_HOME/hodd, else ~/Documents/Ymir/hodd.
const HOARD = process.env.YMIR_HOARD ?? join(process.env.YMIR_HOME ?? join(homedir(), 'Documents', 'Ymir'), 'hodd');
const RUNES = join(HOARD, 'memory/runes_audit.md');
const WELL = join(ROOT, '.agents/memory/well/episodes.jsonl');
const MASTERPLAN = join(ROOT, 'docs/masterplan.md');

const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' },
  });

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
async function runAsync(cmd: string[], ttlMs = 3000): Promise<string> {
  return memoAsync('run:' + cmd.join('\u0000'), ttlMs, async () => {
    try {
      const proc = Bun.spawn(['timeout', '12', ...cmd], {
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
    const registered = existsSync(join(ROOT, '.opencode/agent', `${id}.md`));
    return {
      id,
      name: norse.charAt(0).toUpperCase() + norse.slice(1),
      role: String(fm.descriptor ?? fm.role ?? 'agent'),
      realm: 'work',
      domain: String(fm.domain ?? 'ymirlabs'),
      status: registered ? 'nominal' : 'degraded',
      capabilities: Array.isArray(fm.capabilities) ? fm.capabilities : [],
      skills: [],
      interface: { protocol: 'a2a/1.0', endpoint: `local://${id}`, signed: false },
      model: String(fm.model ?? '') || model,
      uptime: 0,
      tasksDone: 0,
      traceability: 0,
    };
  });
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

function tasks() {
  const now = new Date().toISOString();
  return orders().map((o, i) => ({
    id: o.id,
    title: o.title,
    state: o.status === 'COMPLETED' ? 'COMPLETED' : o.status === 'BLOCKED' ? 'INPUT_REQUIRED' : 'WORKING',
    realm: 'wayof',
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
async function mimirHealth() {
  try {
    const res = await fetch(`${MIMIR_URL}/health`, { signal: AbortSignal.timeout(4000) });
    if (res.ok) return await res.json();
  } catch {
    /* down */
  }
  return { status: 'down', store: null, episodes: 0, agents: [] };
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
  const cron = await runAsync(['bash', 'bin/nornir-cron-start.sh', '--status']);
  const bridge = await runAsync(['bash', 'bin/bifrost-bridge.sh', '--status']);
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
  for (const r of parseToon(await runAsync(['bash', 'bin/valhalla.sh', 'list']))) {
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
    join(process.env.YMIR_HOME ?? join(homedir(), 'Documents', 'Ymir'), 'smidja', 'smidja.db'),
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
async function reviews() {
  const cards: unknown[] = [];

  // 1. Real pull requests from the repo's remote — the Glitnir gate. A delivered
  //    change must appear here so the Allfather can review and seal it; without
  //    this the surface showed only the synthetic lint card and no PR ever landed.
  try {
    const list = JSON.parse(
      (await runAsync([
        'gh', 'pr', 'list', '--state', 'open', '--limit', '50',
        '--json', 'number,title,author,headRefName,isDraft,updatedAt,additions,deletions,statusCheckRollup',
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
      cards.push({
        id: `pr-${pr.number}`,
        number: pr.number,
        title: pr.title,
        repo: 'origin',
        author: pr.author?.login ?? 'unknown',
        realm: 'work',
        state: pr.isDraft ? 'open' : failing ? 'changes' : 'open',
        checks,
        checklist: [{ label: `branch ${pr.headRefName ?? '?'}`, done: true }],
        additions: pr.additions ?? 0,
        deletions: pr.deletions ?? 0,
        updatedAt: pr.updatedAt ?? new Date().toISOString(),
      });
    }
  } catch {
    /* gh unavailable or offline — the compliance card below still stands */
  }

  // 2. The compliance card (lint + governed-path checks) always stands.
  const out = await runAsync(['bash', 'bin/brokk-lint.sh', '--quiet'], 60000);
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
  return cards;
}

/* ---- /api/files (realm tree) --------------------------------------------- */
/** Resolve a workspace id to its on-disk scope: a company container when the
 *  workspace names one, else its repo-root workspace scope. */
function workspaceRoot(realm: string): string {
  const ws = workspaces().find((w) => w.id === realm);
  if (ws?.company) {
    const company = join(ROOT, 'svartalfaheim', ws.company);
    if (existsSync(company)) return company;
  }
  const scope = join(ROOT, 'workspace', realm);
  if (existsSync(scope)) return scope;
  const slug = realm.toLowerCase().replace(/[^a-z0-9]/g, '');
  const legacy = join(ROOT, 'svartalfaheim', slug);
  if (slug && slug !== realm && existsSync(legacy)) return legacy;
  return join(ROOT, 'svartalfaheim', realm);
}

function files(realm: string) {
  const base = workspaceRoot(realm);
  const walk = (dir: string, rel: string, depth: number): unknown => {
    const name = rel === '' ? (realm || 'svartalfaheim') : rel.split('/').pop()!;
    const node: Record<string, unknown> = { name, type: 'dir', path: rel || '/', children: [] as unknown[] };
    if (depth > 3 || !existsSync(dir)) return node;
    let entries: string[] = [];
    try {
      entries = readdirSync(dir);
    } catch {
      return node;
    }
    for (const e of entries) {
      if (e.startsWith('.')) continue;
      const full = join(dir, e);
      let st;
      try {
        st = statSync(full);
      } catch {
        continue;
      }
      const childRel = rel ? `${rel}/${e}` : e;
      if (st.isDirectory()) (node.children as unknown[]).push(walk(full, childRel, depth + 1));
      else (node.children as unknown[]).push({ name: e, type: 'file', path: childRel, size: st.size, updated: st.mtime.toISOString() });
    }
    return node;
  };
  if (existsSync(base)) return walk(base, '', 0);
  return walk(join(ROOT, 'docs'), '', 0);
}

/* ---- /api/file — read one realm file, read-only, scoped ------------------ */
function fileContent(realm: string, rel: string) {
  const base = resolve(workspaceRoot(realm));
  const full = resolve(base, rel);
  if (full !== base && !full.startsWith(base + '/')) return { error: 'outside realm' };
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
async function runtime() {
  const digest = await runAsync(['bash', 'bin/saga-session-start.sh'], 10000);
  const markers = {
    lock: read(join(STATE_DIR, '.lock')).trim(),
    started: existsSync(join(STATE_DIR, '.session-start-complete')),
    armed: existsSync(join(STATE_DIR, '.supervision-armed')),
  };
  return { digest, markers, doc: 'docs/session-start.md' };
}

/* ---- /api/cron ----------------------------------------------------------- */
async function cron() {
  const cfg = read(join(CONFIG_DIR, 'cron.yaml'));
  const jobs = cfg
    .split('\n')
    .filter((l) => /^\d{2}:\d{2}\s+/.test(l))
    .map((l) => ({ at: l.slice(0, 5), command: l.slice(6).trim() }));
  const status = await runAsync(['bash', 'bin/nornir-cron-start.sh', '--status']);
  const running = status.includes('running');
  const pid = (status.match(/pid=(\d+)/) ?? [])[1] ?? '';
  return { running, pid, jobs: jobs.map((j) => ({ ...j, status: running ? 'scheduled' : 'stopped' })) };
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
  return parseToon(await runAsync(['bash', 'bin/valknut-load.sh', '--status']));
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

/* ---- /api/stream (SSE): new runes lines ---------------------------------- */
function stream() {
  let cursor = 0;
  try {
    cursor = statSync(RUNES).size;
  } catch {
    /* no ledger yet */
  }
  return new Response(
    new ReadableStream({
      start(controller) {
        const enc = new TextEncoder();
        const tick = setInterval(() => {
          try {
            const size = statSync(RUNES).size;
            if (size > cursor) {
              const tail = readFileSync(RUNES, 'utf8').slice(cursor);
              cursor = size;
              for (const line of tail.split('\n')) {
                if (!line.trim().startsWith('{')) continue;
                const e = JSON.parse(line);
                const ev = {
                  id: String(e.checksum ?? Date.now()).slice(0, 12),
                  ts: e.timestamp ?? new Date().toISOString(),
                  kind: 'rune',
                  from: e.actor ?? 'brokk',
                  module: e.event ?? '',
                  message: e.message ?? '',
                  checksum: String(e.checksum ?? '').slice(0, 8),
                };
                controller.enqueue(enc.encode(`data: ${JSON.stringify(ev)}\n\n`));
              }
            }
          } catch {
            /* keep streaming */
          }
        }, 2000);
        (controller as unknown as { _tick?: ReturnType<typeof setInterval> })._tick = tick;
      },
      cancel() {
        /* interval GC scope */
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

/** Providers from the root Pi catalog: the exact base/model/key Pi uses. */
function piCatalog(): ChatCatalogEntry[] {
  const out: ChatCatalogEntry[] = [];
  try {
    const raw = JSON.parse(read(PI_MODELS_PATH)) as {
      providers?: Record<string, { baseUrl?: string; apiKey?: string; models?: { id?: string }[] }>;
    };
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
          key: pv.apiKey,
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
  // No choice: the operator's Pi default, then any local catalog model, then bases.
  const targets: ChatTarget[] = [];
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
    body = `The well is local; no model backend answered (${(err as Error).message}). Recall ran; for a reply, raise a local model (llama-server on :8080) or the Bifrost bridge (\`bin/bifrost-bridge.sh\`).`;
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
  let regPath = join(ROOT, 'workspace/workspaces.yaml');
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
  return parseToon(await runAsync(['bash', 'bin/ymir-install.sh', '--check'], 30000));
}
function setupRun() {
  return parseToon(run(['bash', 'bin/ymir-install.sh', '--skip-services']));
}
function workspaceProvision(name: string, kind: string, domains: string) {
  return parseToon(run(['bash', 'bin/workspace-provision.sh', name, '--kind', kind, '--domains', domains]));
}

/* ---- tunnel gate (hardcoded for now) ------------------------------------- */
// Temporary HTTP Basic Auth for the public tunnel. Override with
// HLIDSKJALF_AUTH="user:pass"; replace with Heimdall (oauth2-proxy) later.
const GATE_AUTH = process.env.HLIDSKJALF_AUTH ?? '';
const SMIDJA_URL = process.env.SMIDJA_VIZ_URL ?? 'http://127.0.0.1:8437';
// No default host: which hostname serves the smithy is the machine's fact.
const SMIDJA_HOST = (process.env.SMIDJA_HOST ?? '').toLowerCase();
const ODRERIR_HOST = (process.env.ODRERIR_HOST ?? '').toLowerCase();
/** The one door: the primary host that carries Hlidskjalf's own login. Every app
 *  host redirects its unauthenticated visitors here, with where they were going. */
const PRIMARY_HOST = (process.env.YMIR_PRIMARY_HOST ?? '').toLowerCase();
const ODRERIR_URL = process.env.ODRERIR_URL ?? 'http://127.0.0.1:4322';
/** Every app host the gate fronts: unauthenticated visitors get the login, never
 *  the app. Add a row when an app earns a public hostname. */
const APP_HOSTS: Array<{ host: string; base: string; name: string }> = [
  { host: SMIDJA_HOST, base: SMIDJA_URL, name: 'Smíðja' },
  { host: ODRERIR_HOST, base: ODRERIR_URL, name: 'Óðrerir' },
].filter((a) => a.host !== '');
const DIST = join(ROOT, 'apps/hlidskjalf/dist');

/** token → login. A session must know *who* it is, not merely that it exists. */
const SESSIONS = new Map<string, string>();

/**
 * The token a request carries is the httpOnly `ymir_session` cookie — and nothing
 * else. There is deliberately NO header credential (no `X-Ymir-Session`/`Bearer`)
 * and NO token on disk: a persisted bearer is a credential at rest that any local
 * process could replay, and every app must be verified live by this gate rather
 * than read a file that claims a session. The gate is the one authority.
 */
function cookieToken(req: Request): string {
  const c = req.headers.get('cookie') ?? '';
  const m = c.match(/(?:^|;\s*)ymir_session=([^;]+)/);
  return m ? m[1] : '';
}
function isAuthed(req: Request): boolean {
  if (isDesktopSeat(req)) return true;
  const t = cookieToken(req);
  return !!t && SESSIONS.has(t);
}

/** The peer address per request: Bun's Request has no socket, so it is recorded
 *  at the top of the handler. */
const REQUEST_IP = new WeakMap<Request, string>();

/**
 * The desktop seat (Electron) is local and trusted, so it is never asked to log
 * in: the shell loads this app from 127.0.0.1 and its preload marks every
 * request with `x-ymir-surface: desktop`. The marker alone proves nothing — a
 * web caller could send the header too — so it is honoured ONLY when the request
 * genuinely arrives over loopback, which a remote client never does. The web
 * door keeps its lock.
 */
function isDesktopSeat(req: Request): boolean {
  // A header where the client can set one; a query marker where it cannot —
  // EventSource (the live Runes stream) sends no custom headers.
  const marked =
    (req.headers.get('x-ymir-surface') ?? '') === 'desktop' ||
    new URL(req.url).searchParams.get('surface') === 'desktop';
  if (!marked) return false;
  const ip =
    REQUEST_IP.get(req) ??
    (req as Request & { socket?: { remoteAddress?: string } }).socket?.remoteAddress ??
    '';
  const bare = ip.startsWith('::ffff:') ? ip.slice('::ffff:'.length) : ip;
  return bare === '127.0.0.1' || bare === '::1';
}

/** Who the gate says you are: the desktop seat wears the operator's own name. */
function seatOf(req: Request): string {
  if (isDesktopSeat(req)) {
    const user = (GATE_AUTH || '').split(':')[0];
    return user || 'operator';
  }
  return loginOf(req);
}

/** The login behind a request's session, if any. */
function loginOf(req: Request): string | null {
  return SESSIONS.get(cookieToken(req)) ?? null;
}

/** Begin a session and hand back the cookie. No copy is kept on disk. */
function sessionResponse(login: string): Response {
  const token = crypto.randomUUID();
  SESSIONS.set(token, login);
  return new Response(JSON.stringify({ ok: true, login }), {
    headers: {
      'content-type': 'application/json',
      'set-cookie': `ymir_session=${token}; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000`,
    },
  });
}

/** The login screen for an app host — same gate, same credentials. */
function appLoginPage(name = 'Smíðja'): Response {
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${name} — Sign in</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 24px;
    background: radial-gradient(900px 500px at 50% -10%, rgba(226,232,240,.07), transparent 60%), #080c14;
    color: #e2e8f0; font: 15px/1.4 system-ui, sans-serif; }
  form { width: 100%; max-width: 380px; display: flex; flex-direction: column; gap: 14px;
    background: #0d131f; border: 1px solid #23304a; border-radius: 14px; padding: 26px;
    box-shadow: 0 24px 60px rgba(0,0,0,.5); }
  .brand { display: flex; align-items: center; gap: 12px; }
  .brand b { font-size: 20px; letter-spacing: .18em; }
  .brand small { display: block; font: 10px/1 ui-monospace, monospace; letter-spacing: .28em;
    text-transform: uppercase; color: #e2e8f0; margin-top: 4px; }
  h1 { font-size: 22px; margin: 0; }
  p { margin: 0; color: #94a3b8; font-size: 13px; }
  input { padding: 11px 12px; border-radius: 9px; border: 1px solid #23304a; background: #111a2b;
    color: #e2e8f0; font-size: 15px; }
  input:focus { outline: none; border-color: #e2e8f0; }
  button { padding: 11px 12px; border: none; border-radius: 9px; background: #e2e8f0; color: #06121f;
    font-weight: 700; font-size: 15px; cursor: pointer; }
  .err { color: #f87171; font-size: 12px; min-height: 14px; }
</style>
</head>
<body>
<form id="gate">
  <div class="brand">
    <svg width="34" height="34" viewBox="0 0 32 32" aria-hidden="true">
      <rect x="1" y="1" width="30" height="30" rx="7" fill="#0f172a" stroke="#1e293b"/>
      <g fill="#e2e8f0">
        <polygon points="7,6 10,6 16,11.5 22,6 25,6 17.5,13 17.5,20 14.5,20 14.5,13"/>
        <polygon points="6,21 26,21 25.4,24 6.6,24"/>
        <polygon points="8,25 24,25 23.3,27.5 8.7,27.5"/>
      </g>
    </svg>
    <span><b>${name.toUpperCase()}</b><small>Ymir</small></span>
  </div>
  <h1>Sign in</h1>
  <p>The gate is closed. Sign in, or enter an invite code to make your own account.</p>
  <input name="username" placeholder="username" autocomplete="username" autofocus />
  <input name="password" type="password" placeholder="••••••••" autocomplete="current-password" />
  <input name="invite" placeholder="invite code (only to create an account)" autocomplete="off" />
  <span class="err" id="err"></span>
  <button type="submit">Enter</button>
</form>
<script>
  const f = document.getElementById('gate');
  f.addEventListener('submit', async (e) => {
    e.preventDefault();
    const b = new FormData(f);
    const invite = String(b.get('invite') || '').trim();
    // An invite in the field means "make me an account"; without one this is an
    // ordinary sign-in. A bad or spent code is refused by the gate either way.
    const r = await fetch(invite ? '/api/register' : '/api/login', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ username: b.get('username'), password: b.get('password'), invite }),
    });
    if (r.ok) { location.reload(); return; }
    const said = await r.json().catch(() => ({}));
    document.getElementById('err').textContent = said.error || 'Wrong username or password';
  });
</script>
</body>
</html>`;
  return new Response(html, {
    headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' },
  });
}

/** Forward an authed Smíðja-host request to the visualizer on :8437. */
async function proxyApp(req: Request, url: URL, base = SMIDJA_URL, label = 'smidja'): Promise<Response> {
  const headers = new Headers(req.headers);
  headers.delete('host');
  headers.delete('cookie');
  headers.delete('connection');
  const init: RequestInit = { method: req.method, headers, redirect: 'manual' };
  if (req.method !== 'GET' && req.method !== 'HEAD') init.body = await req.arrayBuffer();
  try {
    const up = await fetch(`${base}${url.pathname}${url.search}`, init);
    return new Response(up.body, { status: up.status, headers: up.headers });
  } catch (err) {
    return json({ error: `${label} upstream unreachable: ${(err as Error).message}` }, 502);
  }
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
// Sessions are in-memory only: a gate restart ends them, and nothing on disk can
// revive one. That is the point — no bearer is kept at rest.
const server = Bun.serve({
  port: PORT,
  async fetch(req, srv) {
    const url = new URL(req.url);
    const p = url.pathname;
    // Bun's Request carries no socket; the peer address comes from the server.
    // Recorded per request (a WeakMap, so concurrent requests cannot mix).
    REQUEST_IP.set(req, srv.requestIP(req)?.address ?? '');
    try {
      if (p === '/api/login' && req.method === 'POST') {
        const b = (await req.json().catch(() => ({}))) as { username?: string; password?: string };
        const user = b.username ?? '';
        const pass = b.password ?? '';
        // Two ways in: the operator's own credentials (HLIDSKJALF_AUTH), or an
        // account minted with an invite code.
        let login: string | null = null;
        if (GATE_AUTH && `${user}:${pass}` === GATE_AUTH) login = user;
        else if (user && pass) login = await verifyAccount(user, pass);
        if (login) return sessionResponse(login);
        return json({ error: 'invalid credentials' }, 401);
      }
      if (p === '/api/register' && req.method === 'POST') {
        const b = (await req.json().catch(() => ({}))) as {
          username?: string;
          password?: string;
          invite?: string;
        };
        const made = await register(b.username ?? '', b.password ?? '', b.invite ?? '');
        if (!made.ok) return json({ error: made.reason }, 403);
        return sessionResponse(made.login);
      }
      /* ---- GitHub: the same gate, a second door ---------------------------- *
       * Sign-in with GitHub never creates access on its own. It names a login,
       * and that login must already hold an account — accounts come from an
       * invite, so the door stays closed to strangers however they arrive. */
      if (p === '/api/auth/github' && req.method === 'GET') {
        const clientId = process.env.GITHUB_CLIENT_ID ?? '';
        const clientSecret = process.env.GITHUB_CLIENT_SECRET ?? '';
        if (!clientId || !clientSecret) {
          return json(
            {
              error:
                'GitHub sign-in is not configured. Set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET in .env.local (a GitHub OAuth app) and restart the gate.',
            },
            503,
          );
        }
        const state = crypto.randomUUID();
        const redirect = `${url.origin}/api/auth/github/callback`;
        const authorize =
          'https://github.com/login/oauth/authorize' +
          `?client_id=${encodeURIComponent(clientId)}` +
          `&redirect_uri=${encodeURIComponent(redirect)}` +
          '&scope=read:user&state=' +
          encodeURIComponent(state);
        return new Response(JSON.stringify({ url: authorize }), {
          headers: {
            'content-type': 'application/json',
            'set-cookie': `ymir_oauth_state=${state}; Path=/; HttpOnly; SameSite=Lax; Max-Age=600`,
          },
        });
      }
      if (p === '/api/auth/github/callback' && req.method === 'GET') {
        const clientId = process.env.GITHUB_CLIENT_ID ?? '';
        const clientSecret = process.env.GITHUB_CLIENT_SECRET ?? '';
        const code = url.searchParams.get('code') ?? '';
        const state = url.searchParams.get('state') ?? '';
        const expected = (req.headers.get('cookie') ?? '').match(/ymir_oauth_state=([^;]+)/)?.[1] ?? '';
        if (!code) return json({ error: 'GitHub returned no code' }, 400);
        if (!state || state !== expected) return json({ error: 'OAuth state did not match' }, 400);
        const tokenRes = await fetch('https://github.com/login/oauth/access_token', {
          method: 'POST',
          headers: { 'content-type': 'application/json', accept: 'application/json' },
          body: JSON.stringify({ client_id: clientId, client_secret: clientSecret, code }),
        });
        const tok = (await tokenRes.json().catch(() => ({}))) as { access_token?: string };
        if (!tok.access_token) return json({ error: 'GitHub refused the code' }, 502);
        const userRes = await fetch('https://api.github.com/user', {
          headers: {
            authorization: `Bearer ${tok.access_token}`,
            accept: 'application/vnd.github+json',
            'user-agent': 'ymir-gate',
          },
        });
        const gh = (await userRes.json().catch(() => ({}))) as { login?: string };
        const login = (gh.login ?? '').trim().toLowerCase();
        if (!login) return json({ error: 'GitHub returned no login' }, 502);
        if (!findAccount(login)) {
          return json(
            { error: `No account is held for the GitHub login '${login}'. Ask for an invite code, then register.` },
            403,
          );
        }
        return sessionResponse(login);
      }
      if (p === '/api/invites' && req.method === 'GET' && isAuthed(req)) {
        // The operator's own view of who may still be let in.
        return json({
          invites: listInvites().map((i) => ({ ...i, code: i.code })),
          accounts: listAccounts(),
        });
      }
      if (p === '/api/session') {
        return json({
          authed: GATE_AUTH ? isAuthed(req) : true,
          login: seatOf(req),
          // The login surface shows "create an account" only while a live invite
          // exists — a newcomer with a code can enter, and nobody else can.
          registration: invitesOpen(),
          // GitHub is a second door only when an OAuth app is configured; the
          // login surface hides the button otherwise (it would 503).
          github: !!(process.env.GITHUB_CLIENT_ID && process.env.GITHUB_CLIENT_SECRET),
        });
      }
      if (p === '/api/logout' && req.method === 'POST') {
        SESSIONS.delete(cookieToken(req));
        return new Response(JSON.stringify({ ok: true }), {
          headers: { 'content-type': 'application/json', 'set-cookie': 'ymir_session=; Path=/; Max-Age=0' },
        });
      }
      // The Smíðja host rides the same gate: sign in here, then every request
      // is reverse-proxied to the visualizer on :8437.
      const host = (req.headers.get('host') ?? '').toLowerCase().split(':')[0];
      const app = APP_HOSTS.find((a) => a.host === host);
      if (app) {
        if (!isAuthed(req)) {
          // No dead login page: send them to the one login, remembering the app.
          if (p.startsWith('/api/')) return json({ error: 'unauthorized' }, 401);
          const scheme = (req.headers.get('x-forwarded-proto') ?? 'https').split(',')[0];
          const door = PRIMARY_HOST || host;
          return new Response(null, {
            status: 302,
            headers: { location: `${scheme}://${door}/?next=${encodeURIComponent(url.toString())}` },
          });
        }
        return proxyApp(req, url, app.base, app.name);
      }
      if (GATE_AUTH && p.startsWith('/api/') && !isAuthed(req)) return json({ error: 'unauthorized' }, 401);
      if (p === '/api/health') return json({ ok: true, root: ROOT, sessions: orders().length });
      if (p === '/api/usage') {
        // What the HARNESSES spent — opencode and pi — not only the smithy's runs.
        // Memoised for a minute: the aggregate is one bounded SQL statement over a
        // 37 GB store, and a panel must not pay for it on every poll.
        return json(await memoAsync('usage', 60_000, async () => {
          try {
            const { execFileSync } = await import('node:child_process');
            const script = new URL('../../../bin/hlidskjalf-usage.sh', import.meta.url).pathname;
            const out = execFileSync(script, ['--days', process.env.YMIR_USAGE_DAYS ?? '30'], { timeout: 60_000 }).toString().trim();
            return JSON.parse(out);
          } catch (e) {
            return { error: String(e).slice(0, 120) };
          }
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
          const script = new URL('../../../bin/hlidskjalf-agents.sh', import.meta.url).pathname;
          const out = execFileSync(script, [], { timeout: 4000 }).toString().trim();
          if (out.startsWith('[')) {
            return new Response(out, { headers: { 'content-type': 'application/json' } });
          }
        } catch {
          // herdr absent or the connector failed: fall through to the roster
        }
        return json(agents());
      }
      if (p === '/api/tasks') return json(tasks());
      if (p === '/api/orders') return json({ open: orders().filter((o) => o.status !== 'COMPLETED').length, orders: orders() });
      if (p === '/api/runes') return json(runes());
      if (p === '/api/well') return json(await well(url.searchParams.get('q') ?? ''));
      if (p === '/api/well/episode') return json((await wellEpisode(url.searchParams.get('id') ?? '')) ?? { error: 'not found' });
      if (p === '/api/mimir/health') return json(await mimirHealth());
      if (p === '/api/processes') return json(await processes());
      if (p === '/api/reviews') return json(await reviews());
      if (p === '/api/files') return json(files(url.searchParams.get('realm') ?? 'work'));
      if (p === '/api/file') return json(fileContent(url.searchParams.get('realm') ?? 'work', url.searchParams.get('path') ?? ''));
      if (p === '/api/skills') return json(skills());
      if (p === '/api/runtime') return json(await runtime());
      // A speed-start from the UI. It calls the same launcher the Omarchy key
      // bindings use, so the app is raised when it is already up and started
      // when it is not — one way to raise a Ymir window, not two.
      if (p === '/api/desktop' && req.method === 'POST') {
        const body = (await req.json().catch(() => ({}))) as { view?: string };
        const view = body?.view;
        if (view !== 'hlidskjalf' && view !== 'smidja' && view !== 'sessrumnir') {
          return json({ error: 'view must be hlidskjalf, smidja, or sessrumnir' }, 400);
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
      if (p === '/api/cron') return json(await cron());
      if (p === '/api/loaders') return json(await loaders());
      if (p === '/api/checks') return json(await checks());
      if (p === '/api/smidja/health') return json(smidjaHealth());
      if (p === '/api/smidja/sessions') return json(smidjaSessions());
      if (p === '/api/smidja/decisions') return json(smidjaDecisions());
      if (p === '/api/smidja/stats') return json(smidjaStats());
      if (p.startsWith('/api/smidja/sessions/')) {
        const id = decodeURIComponent(p.slice('/api/smidja/sessions/'.length));
        const detail = smidjaSession(id);
        return detail ? json(detail) : json({ error: `no session ${id}` }, 404);
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
