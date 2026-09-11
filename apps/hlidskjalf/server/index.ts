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
  const pm2 = run(['pm2', 'jlist']);
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
  try {
    for (const p of JSON.parse(pm2)) {
      out.push({
        id: `pm2-${p.pm_id}`, name: p.name, daemon: p.pm2_env?.script ?? 'pm2', manager: 'pm2',
        status: p.pm2_env?.status === 'online' ? 'nominal' : 'down', cpu: p.monit?.cpu ?? 0,
        mem: Math.round((p.monit?.memory ?? 0) / 1e6), restarts: p.pm2_env?.restart_time ?? 0,
        uptime: Math.round((Date.now() - (p.pm2_env?.pm_uptime ?? Date.now())) / 1000), realm: 'platform',
      });
    }
  } catch {
    /* pm2 absent */
  }
  return out;
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
