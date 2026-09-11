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
import { appendFileSync, existsSync, mkdirSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { Database } from 'bun:sqlite';
import { join, resolve } from 'node:path';

const PORT = Number(process.env.PORT ?? 3889);
const HERE = import.meta.dir;
const ROOT = resolve(HERE, '../../..'); // /home/zerwiz/Ymir
const AGENTS_DIR = join(ROOT, '.agents/agents');
const SUBAGENTS_DIR = join(ROOT, '.agents/subagents');
const AGENTS_ALT = existsSync(AGENTS_DIR) ? AGENTS_DIR : SUBAGENTS_DIR;
const CONFIG_DIR = join(ROOT, '.agents/config');
const STATE_DIR = join(ROOT, 'state');
const RUNES = join(ROOT, 'workspace/memory/runes_audit.md');
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
  const files = existsSync(AGENTS_ALT) ? readdirSync(AGENTS_ALT).filter((f) => f.endsWith('.md')) : [];
  return files.map((f, i) => {
    const text = read(join(AGENTS_ALT, f));
    const fm = frontmatter(text);
    const id = String(fm.name ?? f.replace(/\.md$/, ''));
    const norse = String(fm.norse_name ?? fm.name ?? id);
    return {
      id,
      name: norse.charAt(0).toUpperCase() + norse.slice(1),
      role: String(fm.descriptor ?? fm.role ?? 'agent'),
      realm: 'way-of',
      house: 'ymirlabs',
      status: 'nominal',
      capabilities: Array.isArray(fm.capabilities) ? fm.capabilities : [],
      skills: existsSync(join(ROOT, '.opencode/agent', `${id}.md`)) ? ['opencode'] : [],
      interface: { protocol: 'a2a/1.0', endpoint: '/.well-known/agent-card.json', signed: false },
      model,
      uptime: 60 * (i + 1),
      tasksDone: 0,
      traceability: 0.984,
    };
  });
}

/* ---- /api/tasks (forge orders) ------------------------------------------- */
function orders() {
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

function tasks() {
  const now = new Date().toISOString();
  return orders().map((o, i) => ({
    id: o.id,
    title: o.title,
    state: o.status === 'COMPLETED' ? 'COMPLETED' : o.status === 'BLOCKED' ? 'INPUT_REQUIRED' : 'WORKING',
    realm: 'way-of',
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
function runes() {
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
          realm: e.realm || 'way-of',
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

/* ---- /api/well ----------------------------------------------------------- */
function well(q = '') {
  const rows = read(WELL)
    .split('\n')
    .filter((l) => l.trim().startsWith('{'))
    .map((l, i) => {
      try {
        const e = JSON.parse(l);
        const body = String(e.content ?? '');
        const title = (body.split('\n')[0] ?? '').replace(/^#+\s*/, '').slice(0, 80) || `episode ${i}`;
        return {
          id: e.hash ?? `ep-${i}`,
          title,
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

/* ---- /api/processes ------------------------------------------------------ */
function processes() {
  const out: unknown[] = [];
  const cron = run(['bash', 'bin/nornir-cron-start.sh', '--status']);
  const bridge = run(['bash', 'bin/bifrost-bridge.sh', '--status']);
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
  for (const r of parseToon(run(['bash', 'bin/valhalla.sh', 'list']))) {
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
const SMIDJA_DB = resolve(ROOT, process.env.SMIDJA_DB ?? 'smidja/smidja_data/smidja.db');

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
function smidjaStats() {
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

/* ---- /api/reviews (compliance as checks) --------------------------------- */
function reviews() {
  const out = run(['bash', 'bin/brokk-lint.sh', '--quiet']);
  const compliance = run(['bash', '.agents/skills/galdr/scripts/compliance-check.sh', '--json']);
  let gates: { id: string; status: string; detail: string }[] = [];
  try {
    gates = JSON.parse(compliance).checks ?? [];
  } catch {
    /* ignore */
  }
  return [
    {
      id: 'lint', number: 1, title: 'Brokk lint gate', repo: 'Ymir', author: 'brokk', realm: 'way-of',
      state: out === '' ? 'approved' : 'changes',
      checks: gates.map((g) => ({ name: g.id, state: g.status === 'PASS' ? 'nominal' : 'down' })),
      checklist: gates.map((g) => ({ label: `${g.id}: ${g.detail}`, done: g.status === 'PASS' })),
      additions: 0, deletions: 0, updatedAt: new Date().toISOString(),
    },
  ];
}

/* ---- /api/files (realm tree) --------------------------------------------- */
function files(realm: string) {
  const base = join(ROOT, 'svartalfaheim', realm);
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

/* ---- /api/runtime -------------------------------------------------------- */
function runtime() {
  const digest = run(['bash', 'bin/saga-session-start.sh']);
  const markers = {
    lock: read(join(STATE_DIR, '.lock')).trim(),
    started: existsSync(join(STATE_DIR, '.session-start-complete')),
    armed: existsSync(join(STATE_DIR, '.supervision-armed')),
  };
  return { digest, markers, doc: 'docs/session-start.md' };
}

/* ---- /api/cron ----------------------------------------------------------- */
function cron() {
  const cfg = read(join(CONFIG_DIR, 'cron.yaml'));
  const jobs = cfg
    .split('\n')
    .filter((l) => /^\d{2}:\d{2}\s+/.test(l))
    .map((l) => ({ at: l.slice(0, 5), command: l.slice(6).trim() }));
  const status = run(['bash', 'bin/nornir-cron-start.sh', '--status']);
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

function loaders() {
  return parseToon(run(['bash', 'bin/valknut-load.sh', '--status']));
}
function checks() {
  try {
    return (JSON.parse(run(['bash', '.agents/skills/galdr/scripts/compliance-check.sh', '--json'])).checks ?? []) as unknown[];
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
const CHAT_LOG = join(ROOT, 'state/chat.jsonl');
// Kaia speaks through the first OpenAI-compatible backend that answers: an
// explicit CHAT_BASE_URL, the local llama-server, then the Bifrost bridge.
const CHAT_BASES = [
  process.env.CHAT_BASE_URL,
  'http://127.0.0.1:8080/v1',
  'http://127.0.0.1:4603/v1',
].filter(Boolean) as string[];
const CHAT_MODEL_ENV = process.env.CHAT_MODEL;
const modelFor: Record<string, string> = {};

async function resolveModel(base: string): Promise<string> {
  if (CHAT_MODEL_ENV) return CHAT_MODEL_ENV;
  if (modelFor[base]) return modelFor[base];
  const res = await fetch(`${base}/models`);
  const data = (await res.json()) as { data?: { id?: string }[] };
  const ids = (data.data ?? []).map((m) => m.id ?? '').filter(Boolean);
  const pick = ids.find((i) => /gemma|qwen|deepseek|hermes/i.test(i)) ?? ids[0];
  if (!pick) throw new Error('no models advertised');
  modelFor[base] = pick;
  return pick;
}

/** Try each backend in order; return the first non-empty reply. */
async function chatCompletion(messages: { role: string; content: string }[]): Promise<{ body: string; backend: string }> {
  let lastErr = '';
  for (const base of CHAT_BASES) {
    try {
      const model = await resolveModel(base);
      const res = await fetch(`${base}/chat/completions`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ model, messages, stream: false, temperature: 0.6, max_tokens: 700 }),
      });
      if (!res.ok) {
        lastErr = `${base} → ${res.status}`;
        continue;
      }
      const data = (await res.json()) as { choices?: { message?: { content?: string } }[] };
      const body = data.choices?.[0]?.message?.content?.trim();
      if (body) return { body, backend: base };
      lastErr = `${base} → empty`;
    } catch (err) {
      lastErr = `${base} → ${(err as Error).message}`;
    }
  }
  throw new Error(lastErr || 'no chat backend reachable');
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
  error?: boolean;
}

function chatHistory(): ChatRow[] {
  return read(CHAT_LOG)
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

/** A bounded recall from the well — drink before you answer. */
function chatRecall(): string {
  const rows = read(WELL).split('\n').filter((l) => l.trim().startsWith('{')).slice(-400);
  const picks: string[] = [];
  for (let i = rows.length - 1; i >= 0 && picks.length < 4; i--) {
    try {
      const e = JSON.parse(rows[i]);
      const t = String(e.content ?? '').split('\n')[0].replace(/^#+\s*/, '').trim();
      if (t) picks.push(`- (${e.source ?? 'well'}) ${t.slice(0, 110)}`);
    } catch {
      /* skip malformed */
    }
  }
  return picks.join('\n');
}

async function postChat(content: string): Promise<{ reply: ChatRow; live: boolean }> {
  mkdirSync(STATE_DIR, { recursive: true });
  const user: ChatRow = { id: `u-${Date.now()}`, from: 'user', body: content, ts: new Date().toISOString() };
  appendFileSync(CHAT_LOG, `${JSON.stringify(user)}\n`);

  const history = chatHistory().slice(-12);
  const recall = chatRecall();
  const messages = [
    {
      role: 'system',
      content: `${KAIA_SYSTEM}\n\nWell recall:\n${recall || '(dry — answer from first principles, and say the well was dry)'}`,
    },
    ...history.map((m) => ({ role: m.from === 'user' ? 'user' : 'assistant', content: m.body })),
  ];

  let body: string;
  let live = false;
  try {
    const out = await chatCompletion(messages);
    body = out.body;
    live = true;
  } catch (err) {
    body = `The well is local; no model backend answered (${(err as Error).message}). Recall ran; for a reply, raise a local model (llama-server on :8080) or the Bifrost bridge (\`bin/bifrost-bridge.sh\`).`;
  }

  const kaia: ChatRow = {
    id: `k-${Date.now()}`,
    from: 'kaia',
    body,
    ts: new Date().toISOString(),
    recalling: recall.length > 0,
    ...(live ? {} : { error: true }),
  };
  appendFileSync(CHAT_LOG, `${JSON.stringify(kaia)}\n`);
  return { reply: kaia, live };
}

/* ---- server -------------------------------------------------------------- */
const server = Bun.serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);
    const p = url.pathname;
    try {
      if (p === '/api/health') return json({ ok: true, root: ROOT, sessions: orders().length });
      if (p === '/api/me') return json({ login: 'Allfather', realm: 'way-of' });
      if (p === '/api/workspace') return json({ realm: 'way-of', path: join(ROOT, 'svartalfaheim/way-of') });
      if (p === '/api/agents') return json(agents());
      if (p === '/api/tasks') return json(tasks());
      if (p === '/api/orders') return json({ open: orders().filter((o) => o.status !== 'COMPLETED').length, orders: orders() });
      if (p === '/api/runes') return json(runes());
      if (p === '/api/well') return json(well(url.searchParams.get('q') ?? ''));
      if (p === '/api/processes') return json(processes());
      if (p === '/api/reviews') return json(reviews());
      if (p === '/api/files') return json(files(url.searchParams.get('realm') ?? 'way-of'));
      if (p === '/api/runtime') return json(runtime());
      if (p === '/api/cron') return json(cron());
      if (p === '/api/loaders') return json(loaders());
      if (p === '/api/checks') return json(checks());
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
      if (p === '/api/stream') return stream();
      if (p === '/api/chat/history') return json(chatHistory());
      if (p === '/api/chat' && req.method === 'POST') {
        const body = (await req.json().catch(() => ({}))) as { content?: string };
        const content = (body.content ?? '').trim();
        if (!content) return json({ error: 'chat needs content' }, 400);
        return json(await postChat(content));
      }
      if (p.startsWith('/api/')) return json({ error: `no route ${p}` }, 404);
      return new Response('Hlidskjalf gate API. Endpoints under /api/*.', { status: 200 });
    } catch (err) {
      return json({ error: (err as Error).message }, 500);
    }
  },
});

console.log(`[hlidskjalf] gate api   http://127.0.0.1:${server.port}`);
console.log(`[hlidskjalf] runtime    ${ROOT}`);
