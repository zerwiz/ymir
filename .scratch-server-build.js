// @bun
// apps/hlidskjalf/server/index.ts
import { appendFileSync, existsSync as existsSync2, mkdirSync as mkdirSync2, readFileSync as readFileSync2, readdirSync, statSync, unlinkSync, writeFileSync as writeFileSync2 } from "fs";
import { Database } from "bun:sqlite";
import { dirname, extname, join as join2, resolve } from "path";
import { homedir as homedir2 } from "os";

// apps/hlidskjalf/server/accounts.ts
import { chmodSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "fs";
import { homedir } from "os";
import { join } from "path";
var CONFIG_DIR = process.env.YMIR_CONFIG_DIR ?? join(homedir(), ".config", "ymir");
var STORE = join(CONFIG_DIR, "accounts.json");
var DEFAULT_INVITE_LIMIT = Number(process.env.YMIR_INVITE_LIMIT ?? 5);
var MIN_PASSWORD = 8;
var LOGIN_RE = /^[a-z0-9][a-z0-9._-]{1,31}$/;
function empty() {
  return { version: 1, accounts: [], invites: [] };
}
function load() {
  if (!existsSync(STORE))
    return empty();
  try {
    const s = JSON.parse(readFileSync(STORE, "utf8"));
    return { version: 1, accounts: s.accounts ?? [], invites: s.invites ?? [] };
  } catch {
    return empty();
  }
}
function save(s) {
  mkdirSync(CONFIG_DIR, { recursive: true });
  writeFileSync(STORE, `${JSON.stringify(s, null, 2)}
`, { mode: 384 });
  try {
    chmodSync(STORE, 384);
  } catch {}
}
function inviteCheck(code) {
  const wanted = code.trim().toUpperCase();
  if (!wanted)
    return { ok: false, reason: "an invite code is required" };
  const invite = load().invites.find((i) => i.code === wanted);
  if (!invite)
    return { ok: false, reason: "that invite code is not valid" };
  if (invite.used >= invite.limit)
    return { ok: false, reason: "that invite code has been used up" };
  return { ok: true, invite };
}
function listInvites() {
  return load().invites;
}
function invitesOpen() {
  return load().invites.some((i) => i.used < i.limit);
}
function findAccount(login) {
  const wanted = login.trim().toLowerCase();
  return load().accounts.find((a) => a.login === wanted);
}
function listAccounts() {
  return load().accounts.map(({ login, created }) => ({ login, created }));
}
async function register(login, password, code) {
  const name = login.trim().toLowerCase();
  if (!LOGIN_RE.test(name)) {
    return { ok: false, reason: "a username is 2\u201332 characters: letters, digits, dot, dash, underscore" };
  }
  if (password.length < MIN_PASSWORD) {
    return { ok: false, reason: `a password of at least ${MIN_PASSWORD} characters is required` };
  }
  const check = inviteCheck(code);
  if (!check.ok)
    return { ok: false, reason: check.reason };
  const s = load();
  if (s.accounts.some((a) => a.login === name))
    return { ok: false, reason: "that username is taken" };
  const live = s.invites.find((i) => i.code === check.invite.code);
  if (!live)
    return { ok: false, reason: "that invite code is not valid" };
  if (live.used >= live.limit)
    return { ok: false, reason: "that invite code has been used up" };
  const hash = await Bun.password.hash(password, { algorithm: "argon2id" });
  s.accounts.push({ login: name, hash, created: new Date().toISOString() });
  live.used += 1;
  save(s);
  return { ok: true, login: name };
}
async function verify(login, password) {
  const account = findAccount(login);
  if (!account)
    return null;
  const ok = await Bun.password.verify(password, account.hash).catch(() => false);
  return ok ? account.login : null;
}

// packages/contracts/src/agent-card.ts
var A2A_PROTOCOL = "a2a/1.0";
// apps/hlidskjalf/server/index.ts
var PORT = Number(process.env.PORT ?? 3889);
var HERE = import.meta.dir;
var ROOT = resolve(HERE, "../../..");
var AGENTS_DIR = join2(ROOT, ".agents/agents");
var SUBAGENTS_DIR = join2(ROOT, ".agents/subagents");
var AGENTS_ALT = existsSync2(AGENTS_DIR) ? AGENTS_DIR : SUBAGENTS_DIR;
var CONFIG_DIR2 = join2(ROOT, ".agents/config");
var STATE_DIR = join2(ROOT, "state");
var HOME_DIR = process.env.YMIR_HOME ?? (() => {
  try {
    const rec = readFileSync2(join2(process.env.XDG_CONFIG_HOME ?? join2(homedir2(), ".config"), "ymir", "home"), "utf8").trim().split(`
`)[0].trim();
    if (rec)
      return rec;
  } catch {}
  return join2(homedir2(), "Documents", "ymirhome");
})();
var HOARD = process.env.YMIR_HOARD ?? join2(process.env.YMIR_HOME ?? join2(homedir2(), "Documents", "ymirhome"), "hodd");
var RUNES = join2(HOARD, "memory/runes_audit.md");
var WELL = join2(ROOT, ".agents/memory/well/episodes.jsonl");
var MASTERPLAN = join2(ROOT, "docs/masterplan.md");
var json = (data, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" }
});
function read(path) {
  try {
    return readFileSync2(path, "utf8");
  } catch {
    return "";
  }
}
function run(cmd) {
  try {
    const p = Bun.spawnSync(["timeout", "12", ...cmd], {
      cwd: ROOT,
      stdout: "pipe",
      stderr: "pipe"
    });
    return new TextDecoder().decode(p.stdout ?? new Uint8Array).trim();
  } catch {
    return "";
  }
}
var MEMO = new Map;
var INFLIGHT = new Map;
function memo(key, ttlMs, fn) {
  const hit = MEMO.get(key);
  const now = Date.now();
  if (hit && now - hit.t < ttlMs)
    return hit.v;
  const v = fn();
  MEMO.set(key, { t: now, v });
  return v;
}
function memoAsync(key, ttlMs, fn) {
  const hit = MEMO.get(key);
  const now = Date.now();
  if (hit && now - hit.t < ttlMs)
    return Promise.resolve(hit.v);
  const running = INFLIGHT.get(key);
  if (running)
    return running;
  const p = fn().then((v) => {
    MEMO.set(key, { t: Date.now(), v });
    INFLIGHT.delete(key);
    return v;
  }).catch((e) => {
    INFLIGHT.delete(key);
    throw e;
  });
  INFLIGHT.set(key, p);
  return p;
}
async function runAsync(cmd, ttlMs = 3000) {
  return memoAsync("run:" + cmd.join("\x00"), ttlMs, async () => {
    try {
      const proc = Bun.spawn(["timeout", "12", ...cmd], {
        cwd: ROOT,
        stdout: "pipe",
        stderr: "pipe"
      });
      const out = await new Response(proc.stdout).text();
      await proc.exited;
      return out.trim();
    } catch {
      return "";
    }
  });
}
async function worktrees() {
  const out = await runAsync(["git", "worktree", "list", "--porcelain"]);
  const rows = [];
  let cur = {};
  const push = () => {
    if (!cur.path)
      return;
    const p = cur.path;
    const id = p.includes("/.yggdrasil/") ? p.split("/.yggdrasil/")[1] : "(main)";
    rows.push({ id, branch: cur.branch ?? "-", path: p, head: (cur.head ?? "").slice(0, 8), agent: id === "(main)" ? "-" : id });
  };
  for (const line of out.split(`
`)) {
    if (line.startsWith("worktree ")) {
      push();
      cur = { path: line.slice(9).trim() };
    } else if (line.startsWith("HEAD "))
      cur.head = line.slice(5).trim();
    else if (line.startsWith("branch "))
      cur.branch = line.slice(7).trim().replace("refs/heads/", "");
    else if (line.trim() === "detached")
      cur.branch = "detached";
  }
  push();
  return rows;
}
function frontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  if (!m)
    return {};
  const out = {};
  let listKey = null;
  for (const line of m[1].split(`
`)) {
    if (/^\s*-\s+/.test(line) && listKey) {
      out[listKey].push(line.replace(/^\s*-\s+/, "").replace(/^["']|["']$/g, ""));
      continue;
    }
    const kv = line.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!kv)
      continue;
    const [, k, v] = kv;
    if (v === "") {
      out[k] = [];
      listKey = k;
    } else {
      out[k] = v.replace(/^["']|["']$/g, "");
      listKey = null;
    }
  }
  return out;
}
function agents() {
  const model = read(join2(CONFIG_DIR2, "eindri-harness")).trim() || "opencode-go/deepseek-v4-flash";
  const files = existsSync2(AGENTS_ALT) ? readdirSync(AGENTS_ALT).filter((f) => f.endsWith(".md") && f !== "galdr.md") : [];
  return files.map((f) => {
    const text = read(join2(AGENTS_ALT, f));
    const fm = frontmatter(text);
    const id = String(fm.name ?? f.replace(/\.md$/, ""));
    const norse = String(fm.norse_name ?? fm.name ?? id);
    const registered = existsSync2(join2(ROOT, ".opencode/agents", `${id}.md`));
    const a2a = { protocol: A2A_PROTOCOL, endpoint: `local://${id}`, signed: false };
    return {
      id,
      name: norse.charAt(0).toUpperCase() + norse.slice(1),
      role: String(fm.descriptor ?? fm.role ?? "agent"),
      realm: "work",
      domain: String(fm.domain ?? "ymirlabs"),
      status: registered ? "nominal" : "degraded",
      capabilities: Array.isArray(fm.capabilities) ? fm.capabilities : [],
      skills: [],
      interface: a2a,
      model: String(fm.model ?? "") || model,
      uptime: 0,
      tasksDone: 0,
      traceability: 0
    };
  });
}
function orders_uncached() {
  const text = read(MASTERPLAN);
  const out = [];
  const lines = text.split(`
`);
  let cur = null;
  for (const line of lines) {
    const h = line.match(/^\*\*(W\d{4}) \u2014 (.+?)\*\*\s*$/);
    if (h) {
      if (cur)
        out.push(cur);
      cur = { id: h[1], title: h[2].trim(), phase: "P?", status: "ADDED" };
      continue;
    }
    if (!cur)
      continue;
    const ph = line.match(/^- Phase:\s*([^\u00B7]+)/);
    if (ph)
      cur.phase = ph[1].trim();
    const st = line.match(/^- Status:\s*([A-Z/]+)/);
    if (st && !/^\+/.test(line))
      cur.status = st[1];
    const note = line.match(/^\s*-\s+\d{4}-\d{2}-\d{2}\s+([A-Z]+)\b/);
    if (note)
      cur.status = note[1];
  }
  if (cur)
    out.push(cur);
  return out;
}
function orders() {
  return memo("orders", 2000, orders_uncached);
}
function tasks() {
  const now = new Date().toISOString();
  return orders().map((o, i) => ({
    id: o.id,
    title: o.title,
    state: o.status === "COMPLETED" ? "COMPLETED" : o.status === "BLOCKED" ? "INPUT_REQUIRED" : "WORKING",
    realm: "wayof",
    agent: "Brokk",
    agentId: "brokk",
    order: o.phase,
    progress: o.status === "COMPLETED" ? 100 : 25,
    startedAt: now,
    updatedAt: now,
    artifacts: [],
    log: [`${o.id} \xB7 ${o.status} \xB7 ${o.phase}`]
  }));
}
function runes_uncached() {
  return read(RUNES).split(`
`).filter((l) => l.trim().startsWith("{")).map((l, i) => {
    try {
      const e = JSON.parse(l);
      const level = /fail|error/i.test(e.event ?? "") ? "danger" : /warn|stale/i.test(e.event ?? "") ? "warn" : /briefing|written/i.test(e.event ?? "") ? "ok" : "info";
      return {
        id: e.checksum ? String(e.checksum).slice(0, 12) : `rune-${i}`,
        ts: e.timestamp ?? "",
        agent: e.actor ?? "brokk",
        module: e.event ?? "",
        event: e.message ?? "",
        checksum: String(e.checksum ?? "").slice(0, 12),
        realm: e.realm || "wayof",
        order: e.order ?? "",
        level
      };
    } catch {
      return null;
    }
  }).filter(Boolean).reverse();
}
function runes() {
  return memo("runes", 3000, runes_uncached);
}
var MIMIR_URL = process.env.MIMIRSBRUNN_URL ?? "http://127.0.0.1:4602";
function wellTitle(body, i = 0) {
  return (body.split(`
`)[0] ?? "").replace(/^#+\s*/, "").slice(0, 80) || `episode ${i}`;
}
function localWell(q = "") {
  const rows = read(WELL).split(`
`).filter((l) => l.trim().startsWith("{")).map((l, i) => {
    try {
      const e = JSON.parse(l);
      const body = String(e.content ?? "");
      return {
        id: e.hash ?? `ep-${i}`,
        title: wellTitle(body, i),
        body: body.slice(0, 600),
        score: 0.9,
        mode: "hybrid",
        agentScope: e.source ?? "assets/data",
        ts: e.timestamp ?? "",
        tags: Array.isArray(e.tags) ? e.tags : []
      };
    } catch {
      return null;
    }
  }).filter(Boolean);
  const ql = q.toLowerCase();
  const filtered = q ? rows.filter((r) => `${r.title} ${r.body}`.toLowerCase().includes(ql)) : rows;
  return filtered.slice(0, 60).reverse();
}
async function well(q = "") {
  try {
    const url = q ? `${MIMIR_URL}/recall?q=${encodeURIComponent(q)}&k=60` : `${MIMIR_URL}/recent?limit=60`;
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (res.ok) {
      const data = await res.json();
      if (data.results) {
        return data.results.map((r) => {
          const e = r.episode ?? {};
          const body = String(e.content ?? "");
          return {
            id: e.id ?? "",
            title: wellTitle(body),
            body: body.slice(0, 600),
            score: r.score ?? 0,
            mode: "hybrid",
            agentScope: (e.actors ?? [])[0] ?? e.agent_id ?? "well",
            ts: e.timestamp ?? "",
            tags: e.tags ?? []
          };
        });
      }
      if (data.episodes) {
        return data.episodes.map((e) => {
          const body = String(e.content ?? "");
          return {
            id: e.id ?? "",
            title: wellTitle(body),
            body: body.slice(0, 600),
            score: 0.9,
            mode: "recent",
            agentScope: (e.actors ?? [])[0] ?? e.agent_id ?? "well",
            ts: e.timestamp ?? "",
            tags: e.tags ?? []
          };
        });
      }
    }
  } catch {}
  return localWell(q);
}
async function mimirHealth() {
  try {
    const res = await fetch(`${MIMIR_URL}/health`, { signal: AbortSignal.timeout(4000) });
    if (res.ok)
      return await res.json();
  } catch {}
  return { status: "down", store: null, episodes: 0, agents: [] };
}
async function wellEpisode(id) {
  if (!id)
    return null;
  try {
    const res = await fetch(`${MIMIR_URL}/episode?id=${encodeURIComponent(id)}`, { signal: AbortSignal.timeout(6000) });
    if (res.ok)
      return await res.json();
  } catch {}
  return null;
}
async function processes() {
  const out = [];
  const cron = await runAsync(["bash", "bin/nornir-cron-start.sh", "--status"]);
  const bridge = await runAsync(["bash", "bin/bifrost-bridge.sh", "--status"]);
  out.push({
    id: "nornir-cron",
    name: "Nornir cron",
    daemon: "scheduler",
    manager: "pm2",
    status: cron.includes("running") ? "nominal" : "down",
    cpu: 0,
    mem: 12,
    restarts: 0,
    uptime: 3600,
    realm: "platform"
  });
  out.push({
    id: "bifrost-bridge",
    name: "Bifrost model bridge",
    daemon: "opencode-go bridge",
    manager: "systemd",
    status: bridge.includes('"up"') ? "nominal" : "down",
    cpu: 0,
    mem: 18,
    restarts: 0,
    uptime: 3600,
    realm: "platform"
  });
  for (const r of parseToon(await runAsync(["bash", "bin/valhalla.sh", "list"]))) {
    const st = /running|active|online/i.test(r.status) ? "nominal" : /exit|fail|inactive|dead|stop/i.test(r.status) ? "down" : "degraded";
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
      realm: "platform"
    });
  }
  return out;
}
var SMIDJA_DB = (() => {
  if (process.env.SMIDJA_DB)
    return process.env.SMIDJA_DB;
  const candidates = [
    join2(process.env.YMIR_HOME ?? join2(homedir2(), "Documents", "ymirhome"), "smidja", "smidja.db"),
    join2(ROOT, "apps", "smidja", "smidja_data", "smidja.db")
  ];
  return candidates.find((c) => existsSync2(c)) ?? candidates[1];
})();
function smidja() {
  try {
    if (!existsSync2(SMIDJA_DB))
      return null;
    return new Database(SMIDJA_DB, { readonly: true });
  } catch {
    return null;
  }
}
function smidjaHealth() {
  const db = smidja();
  if (!db)
    return { db: "absent", sessions: 0 };
  try {
    const r = db.query("select count(*) c from sessions").get();
    return { db: "present", sessions: r?.c ?? 0 };
  } catch {
    return { db: "present", sessions: 0 };
  } finally {
    db.close();
  }
}
function smidjaSessions(limit = 100) {
  const db = smidja();
  if (!db)
    return [];
  try {
    return db.query("select smidja_id, smidja_name, status, engineer, total_tokens, total_cost, started_at, ended_at from sessions order by started_at desc limit ?").all(limit);
  } catch {
    return [];
  } finally {
    db.close();
  }
}
function smidjaSession(id) {
  const db = smidja();
  if (!db)
    return null;
  try {
    const session = db.query("select * from sessions where smidja_id = ?").get(id);
    if (!session)
      return null;
    return {
      session,
      phases: db.query("select * from phases where smidja_id = ? order by seq, rowid").all(id),
      events: db.query("select rowid, event_id, phase_id, parent_id, type, name, payload_json, tokens, started_at, ended_at from events where smidja_id = ? order by rowid limit 2000").all(id),
      envelopes: db.query("select * from envelopes where smidja_id = ? order by created_at, rowid").all(id),
      gates: db.query("select * from gate_results where smidja_id = ? order by id").all(id),
      agents: db.query("select * from agent_sessions where smidja_id = ? order by created_at, agent").all(id)
    };
  } catch {
    return null;
  } finally {
    db.close();
  }
}
function smidjaDecisions() {
  const db = smidja();
  if (!db)
    return { total_failed: 0, decisions: [] };
  try {
    const decisions = db.query("select ph.name phase, ph.error, ag.model, count(*) count from phases ph left join agent_sessions ag on ag.smidja_id=ph.smidja_id and ag.agent=ph.owner where ph.status='fail' group by ph.name, ph.error, ag.model order by count desc").all();
    return { total_failed: decisions.length, decisions };
  } catch {
    return { total_failed: 0, decisions: [] };
  } finally {
    db.close();
  }
}
var VENDOR_MODELS = [
  { id: "gpt-5.5-pro", name: "GPT-5.5 Pro", provider: "OpenAI", tier: 1, rank: 1, pin: 30, po: 180, cache: 0.5 },
  { id: "o3-pro", name: "o3-pro", provider: "OpenAI", tier: 1, rank: 2, pin: 20, po: 80, cache: 0.5 },
  { id: "claude-opus", name: "Claude Opus 4.6 / 5", provider: "Anthropic", tier: 1, rank: 3, pin: 5, po: 25, cache: 0.1 },
  { id: "gpt-5.5", name: "GPT-5.5", provider: "OpenAI", tier: 1, rank: 4, pin: 5, po: 30, cache: 0.5 },
  { id: "llama-3.1-405b", name: "Llama 3.1 405B", provider: "Meta (Hosted)", tier: 1, rank: 5, pin: 3.75, po: 3.75, cache: 0.5 },
  { id: "gpt-5.4", name: "GPT-5.4", provider: "OpenAI", tier: 1, rank: 6, pin: 2.5, po: 15, cache: 0.5 },
  { id: "gpt-4o", name: "GPT-4o", provider: "OpenAI", tier: 1, rank: 7, pin: 2.5, po: 10, cache: 0.5 },
  { id: "gemini-3.1-pro", name: "Gemini 3.1 Pro", provider: "Google", tier: 1, rank: 8, pin: 2, po: 12, cache: 0.25 },
  { id: "o3", name: "o3", provider: "OpenAI", tier: 1, rank: 9, pin: 2, po: 8, cache: 0.5 },
  { id: "claude-sonnet", name: "Claude Sonnet 4.6 / 5", provider: "Anthropic", tier: 1, rank: 10, pin: 2.5, po: 12.5, cache: 0.1 },
  { id: "mistral-large-3", name: "Mistral Large 3", provider: "Mistral AI", tier: 2, rank: 11, pin: 0.5, po: 1.5, cache: 0.5 },
  { id: "claude-haiku", name: "Claude Haiku 4.5", provider: "Anthropic", tier: 2, rank: 12, pin: 1, po: 5, cache: 0.1 },
  { id: "gemini-2.5-pro", name: "Gemini 2.5 Pro", provider: "Google", tier: 2, rank: 13, pin: 1.25, po: 10, cache: 0.25 },
  { id: "o4-mini", name: "o4-mini", provider: "OpenAI", tier: 2, rank: 14, pin: 0.55, po: 2.2, cache: 0.5 },
  { id: "deepseek-r1", name: "DeepSeek R1", provider: "DeepSeek", tier: 2, rank: 15, pin: 0.55, po: 2.19, cache: 0.5 },
  { id: "gemini-3-flash-preview", name: "Gemini 3 Flash Preview", provider: "Google", tier: 2, rank: 16, pin: 0.5, po: 3, cache: 0.25 },
  { id: "command-r-plus", name: "Command R+", provider: "Cohere", tier: 2, rank: 17, pin: 2.5, po: 10, cache: 0.5 },
  { id: "gpt-5.4-mini", name: "GPT-5.4 Mini", provider: "OpenAI", tier: 2, rank: 18, pin: 0.75, po: 4.5, cache: 0.5 },
  { id: "deepseek-v4", name: "DeepSeek V4", provider: "DeepSeek", tier: 2, rank: 19, pin: 0.3, po: 0.5, cache: 0.5 },
  { id: "codestral", name: "Codestral", provider: "Mistral AI", tier: 2, rank: 20, pin: 0.3, po: 0.9, cache: 0.5 },
  { id: "deepseek-chat-v3.2", name: "DeepSeek-Chat (V3.2)", provider: "DeepSeek", tier: 2, rank: 21, pin: 0.28, po: 0.42, cache: 0.5 },
  { id: "llama-3.3-70b", name: "Llama 3.3 70B", provider: "Meta (Hosted)", tier: 2, rank: 22, pin: 0.41, po: 0.52, cache: 0.5 },
  { id: "mistral-medium-3.5", name: "Mistral Medium 3.5", provider: "Mistral AI", tier: 2, rank: 23, pin: 1.5, po: 7.5, cache: 0.5 },
  { id: "gpt-4.1", name: "GPT-4.1", provider: "OpenAI", tier: 2, rank: 24, pin: 2, po: 8, cache: 0.5 },
  { id: "qwen-2.5-72b", name: "Qwen 2.5 72B", provider: "Alibaba (Hosted)", tier: 2, rank: 25, pin: 0.35, po: 0.4, cache: 0.5 },
  { id: "gemini-3.7-flash", name: "Gemini 3.7 Flash", provider: "Google", tier: 3, rank: 26, pin: 0.75, po: 3.75, cache: 0.25 },
  { id: "gemini-3.6-flash", name: "Gemini 3.6 Flash", provider: "Google", tier: 3, rank: 27, pin: 0.75, po: 3.75, cache: 0.25 },
  { id: "gpt-4.1-mini", name: "GPT-4.1 Mini", provider: "OpenAI", tier: 3, rank: 28, pin: 0.4, po: 1.6, cache: 0.5 },
  { id: "llama-4-maverick", name: "Llama 4 Maverick", provider: "Meta (Hosted)", tier: 3, rank: 29, pin: 0.25, po: 0.875, cache: 0.5 },
  { id: "gpt-5-mini", name: "GPT-5 Mini", provider: "OpenAI", tier: 3, rank: 30, pin: 0.25, po: 2, cache: 0.5 },
  { id: "gemini-3.1-flash-lite", name: "Gemini 3.1 Flash-Lite", provider: "Google", tier: 3, rank: 31, pin: 0.25, po: 1.5, cache: 0.25 },
  { id: "gpt-5.4-nano", name: "GPT-5.4 Nano", provider: "OpenAI", tier: 3, rank: 32, pin: 0.2, po: 1.25, cache: 0.5 },
  { id: "mistral-small-4", name: "Mistral Small 4", provider: "Mistral AI", tier: 3, rank: 33, pin: 0.15, po: 0.6, cache: 0.5 },
  { id: "gpt-4o-mini", name: "GPT-4o mini", provider: "OpenAI", tier: 3, rank: 34, pin: 0.15, po: 0.6, cache: 0.5 },
  { id: "gpt-4.1-nano", name: "GPT-4.1 Nano", provider: "OpenAI", tier: 3, rank: 35, pin: 0.1, po: 0.4, cache: 0.5 },
  { id: "gemini-2.5-flash-lite", name: "Gemini 2.5 Flash-Lite", provider: "Google", tier: 3, rank: 36, pin: 0.1, po: 0.4, cache: 0.25 },
  { id: "llama-4-scout", name: "Llama 4 Scout", provider: "Meta (Hosted)", tier: 3, rank: 37, pin: 0.165, po: 0.5, cache: 0.5 },
  { id: "ministral-8b", name: "Ministral 8B", provider: "Mistral AI", tier: 3, rank: 38, pin: 0.1, po: 0.1, cache: 0.5 },
  { id: "llama-3.2-3b", name: "Llama 3.2 3B", provider: "Meta (Hosted)", tier: 3, rank: 39, pin: 0.02, po: 0.02, cache: 0.5 },
  { id: "ministral-3b", name: "Ministral 3B", provider: "Mistral AI", tier: 3, rank: 40, pin: 0.04, po: 0.04, cache: 0.5 }
];
var TIER_LABEL = {
  1: "Tier 1 \u2014 heavyweight flagships & enterprise intelligence",
  2: "Tier 2 \u2014 mid-range & high-efficiency workhorses",
  3: "Tier 3 \u2014 flash, mini & edge engines"
};
var LOCAL_MODEL_PREFIXES = ["lmstudio/", "ollama/", "localhost/", "vllm/", "unsloth/"];
var isLocalModel = (model) => LOCAL_MODEL_PREFIXES.some((p) => model.toLowerCase().startsWith(p));
function emptyStats() {
  const provider = () => ({ events: 0, sessions: 0, tokens: 0, cost: 0, input: 0, output: 0, cache_read: 0 });
  const vendorCost = { cached_cost: 0, total_cost: 0, savings: 0, savings_pct: 0 };
  return {
    totals: { runs: 0, success: 0, fail: 0, running: 0, tokens: 0, cost: 0 },
    usage: { input: 0, output: 0, cache_read: 0, cache_write: 0, total: 0 },
    cache_hit_ratio: 0,
    avg_cache_hit_per_run: 0,
    vendors: { gpt4o: { ...vendorCost }, gemini: { ...vendorCost } },
    vendor_catalog: [],
    providers: { local: provider(), online: provider(), per_model: [] },
    by_chain: [],
    by_model: [],
    generated_at: new Date().toISOString()
  };
}
function smidjaStats_uncached() {
  const db = smidja();
  if (!db)
    return emptyStats();
  try {
    const hasSessions = db.query("select name from sqlite_master where type='table' and name='sessions'").get();
    if (!hasSessions)
      return emptyStats();
    const sessions = db.query("select smidja_id, smidja_name, status, engineer, total_tokens, total_cost, started_at from sessions order by started_at desc").all();
    const totals = { runs: 0, success: 0, fail: 0, running: 0, tokens: 0, cost: 0 };
    for (const s of sessions) {
      totals.runs += 1;
      if (s.status === "success")
        totals.success += 1;
      else if (s.status === "fail")
        totals.fail += 1;
      else if (s.status === "running")
        totals.running += 1;
      totals.tokens += s.total_tokens ?? 0;
      totals.cost += s.total_cost ?? 0;
    }
    const usage = { input: 0, output: 0, cache_read: 0, cache_write: 0, total: 0 };
    const cacheHitRuns = [];
    const modelAggs = new Map;
    const agentModel = new Map;
    const agentCoding = new Map;
    const started = new Map;
    const emptyAgg = () => ({
      events: 0,
      sessions: new Set,
      tokens: 0,
      cost: 0,
      input: 0,
      output: 0,
      cache_read: 0,
      coding_agent: null
    });
    for (const s of sessions) {
      const evs = db.query("select type, name, payload_json from events where smidja_id = ? order by rowid").all(s.smidja_id);
      let r = 0;
      let t = 0;
      for (const e of evs) {
        let payload = {};
        try {
          payload = e.payload_json ? JSON.parse(e.payload_json) : {};
        } catch {
          payload = {};
        }
        if (e.type === "agent_start") {
          const sp = payload;
          if (sp?.model) {
            const key = `${s.smidja_id}|${e.name}`;
            if (!agentModel.has(key)) {
              const st = started.get(sp.model) ?? { events: 0, sessions: new Set, coding_agent: sp.coding_agent ?? null };
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
        if (e.type !== "agent_end")
          continue;
        const p = payload;
        const u = p?.usage;
        if (!u)
          continue;
        usage.input += u.input_tokens ?? 0;
        usage.output += u.output_tokens ?? 0;
        usage.cache_read += u.cache_read_tokens ?? 0;
        usage.cache_write += u.cache_write_tokens ?? 0;
        usage.total += u.total_tokens ?? 0;
        r += u.cache_read_tokens ?? 0;
        t += (u.input_tokens ?? 0) + (u.cache_read_tokens ?? 0);
        const model = e.name ? agentModel.get(`${s.smidja_id}|${e.name}`) : undefined;
        if (!model)
          continue;
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
      if (t > 0)
        cacheHitRuns.push(r / t);
    }
    for (const [model, st] of started) {
      if (modelAggs.has(model))
        continue;
      const agg = emptyAgg();
      agg.events = st.events;
      agg.sessions = st.sessions;
      agg.coding_agent = st.coding_agent;
      modelAggs.set(model, agg);
    }
    const ingested = usage.input + usage.cache_read;
    const cacheHitRatio = ingested > 0 ? usage.cache_read / ingested : 0;
    const vendor = (pin, pcr, po) => {
      const std = usage.input / 1e6 * pin;
      const cached = usage.cache_read / 1e6 * pcr;
      const out = usage.output / 1e6 * po;
      const total = std + cached + out;
      const savings = total - totals.cost;
      const savings_pct = total > 0 ? savings / total : 0;
      return { cached_cost: cached, total_cost: total, savings, savings_pct };
    };
    const gpt4o = vendor(2.5, 1.25, 10);
    const gemini = vendor(1.25, 0.3125, 5);
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
        ...v
      };
    });
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
    const per_model = [...modelAggs.entries()].map(([model, agg]) => ({
      model,
      kind: isLocalModel(model) ? "local" : "online",
      coding_agent: agg.coding_agent,
      events: agg.events,
      tokens: agg.tokens,
      cost: agg.cost
    })).sort((a, b) => b.tokens - a.tokens);
    const byChain = new Map;
    const byModel = new Map;
    for (const s of sessions) {
      const chain = (s.smidja_name ?? "smidja").split(" + ")[0];
      const chainAgg = byChain.get(chain) ?? { runs: 0, success: 0, tokens: 0, cost: 0 };
      chainAgg.runs += 1;
      if (s.status === "success")
        chainAgg.success += 1;
      chainAgg.tokens += s.total_tokens ?? 0;
      chainAgg.cost += s.total_cost ?? 0;
      byChain.set(chain, chainAgg);
      const modelAgg = byModel.get(s.smidja_name ?? "?") ?? { runs: 0, success: 0, tokens: 0, cost: 0 };
      modelAgg.runs += 1;
      if (s.status === "success")
        modelAgg.success += 1;
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
      by_chain: [...byChain.entries()].map(([chain, agg]) => Object.assign({ chain }, agg)).sort((a, b) => b.runs - a.runs),
      by_model: [...byModel.entries()].map(([model, agg]) => Object.assign({ model }, agg)).sort((a, b) => b.runs - a.runs),
      generated_at: new Date().toISOString()
    };
  } catch {
    return emptyStats();
  } finally {
    db.close();
  }
}
function smidjaStats() {
  return memo("smidjaStats", 3000, smidjaStats_uncached);
}
async function reviews() {
  const cards = [];
  let ghError = "";
  try {
    const repo = (run(["git", "-C", ROOT, "remote", "get-url", "origin"]).match(/[:/]([^/:]+\/[^/]+?)(?:\.git)?$/) ?? [])[1] ?? "zerwiz/ymir";
    const list = JSON.parse(await runAsync([
      "gh",
      "pr",
      "list",
      "--repo",
      repo,
      "--state",
      "open",
      "--limit",
      "50",
      "--json",
      "number,title,author,headRefName,isDraft,updatedAt,additions,deletions,statusCheckRollup,reviewDecision,mergeable"
    ], 15000) || "[]");
    for (const pr of list) {
      const checks = (pr.statusCheckRollup ?? []).map((c) => ({
        name: c.name ?? c.context ?? "check",
        state: c.conclusion === "SUCCESS" || c.status === "IN_PROGRESS" || c.status === "QUEUED" ? "nominal" : c.conclusion ? "down" : "nominal"
      }));
      const failing = checks.some((c) => c.state === "down");
      const approved = pr.reviewDecision === "APPROVED" && !failing;
      cards.push({
        id: `pr-${pr.number}`,
        number: pr.number,
        title: pr.title,
        repo,
        author: pr.author?.login ?? "unknown",
        realm: "work",
        state: pr.isDraft ? "open" : failing ? "changes" : approved ? "approved" : "open",
        mergeable: pr.mergeable ?? undefined,
        checks,
        checklist: [{ label: `branch ${pr.headRefName ?? "?"}`, done: true }],
        additions: pr.additions ?? 0,
        deletions: pr.deletions ?? 0,
        updatedAt: pr.updatedAt ?? new Date().toISOString()
      });
    }
  } catch (e) {
    ghError = e instanceof Error ? e.message : String(e);
  }
  const out = await runAsync(["bash", "bin/brokk-lint.sh", "--quiet"], 60000);
  const compliance = await runAsync(["bash", ".agents/skills/galdr-ymirsystem/scripts/compliance-check.sh", "--json"], 60000);
  let gates = [];
  try {
    gates = JSON.parse(compliance).checks ?? [];
  } catch {}
  const lintOk = out.trim() === "";
  const failing = !lintOk || gates.some((g) => g.status !== "PASS");
  cards.push({
    id: "lint",
    number: 0,
    title: "Brokk lint + compliance gate",
    repo: "Ymir",
    author: "brokk",
    realm: "work",
    state: failing ? "changes" : "open",
    checks: [
      { name: "lint", state: lintOk ? "nominal" : "down" },
      ...gates.map((g) => ({ name: g.id, state: g.status === "PASS" ? "nominal" : "down" }))
    ],
    checklist: [
      { label: `lint: ${lintOk ? "clean" : "issues found"}`, done: lintOk },
      ...gates.map((g) => ({ label: `${g.id}: ${g.detail}`, done: g.status === "PASS" }))
    ],
    additions: 0,
    deletions: 0,
    updatedAt: new Date().toISOString()
  });
  return { cards, ghError };
}
function workspaceRoot(realm) {
  const ws = workspaces().find((w) => w.id === realm);
  if (ws?.company) {
    const company = join2(HOME_DIR, "svartalfaheim", ws.company);
    if (existsSync2(company))
      return company;
  }
  const realmTree = join2(HOME_DIR, "svartalfaheim", realm);
  if (existsSync2(realmTree))
    return realmTree;
  const scope = join2(HOME_DIR, "workspace", realm);
  if (existsSync2(scope))
    return scope;
  const slug = realm.toLowerCase().replace(/[^a-z0-9]/g, "");
  const legacy = join2(ROOT, "svartalfaheim", slug);
  if (slug && slug !== realm && existsSync2(legacy))
    return legacy;
  const legacyScope = join2(ROOT, "workspace", realm);
  if (existsSync2(legacyScope))
    return legacyScope;
  return realmTree;
}
function files(realm) {
  const base = workspaceRoot(realm);
  const walk = (dir, rel, depth) => {
    const name = rel === "" ? realm || "svartalfaheim" : rel.split("/").pop();
    const node = { name, type: "dir", path: rel || "/", children: [] };
    if (depth > 3 || !existsSync2(dir))
      return node;
    let entries = [];
    try {
      entries = readdirSync(dir);
    } catch {
      return node;
    }
    for (const e of entries) {
      if (e.startsWith("."))
        continue;
      const full = join2(dir, e);
      let st;
      try {
        st = statSync(full);
      } catch {
        continue;
      }
      const childRel = rel ? `${rel}/${e}` : e;
      if (st.isDirectory())
        node.children.push(walk(full, childRel, depth + 1));
      else
        node.children.push({ name: e, type: "file", path: childRel, size: st.size, updated: st.mtime.toISOString() });
    }
    return node;
  };
  if (existsSync2(base))
    return walk(base, "", 0);
  return walk(HOME_DIR, "", 0);
}
function fileContent(realm, rel) {
  const base = resolve(workspaceRoot(realm));
  const full = resolve(base, rel);
  if (full !== base && !full.startsWith(base + "/"))
    return { error: "outside realm" };
  if (!existsSync2(full))
    return { error: "not found" };
  let st;
  try {
    st = statSync(full);
  } catch {
    return { error: "unreadable" };
  }
  if (!st.isFile())
    return { error: "not a file" };
  if (st.size > 512 * 1024)
    return { path: rel, size: st.size, body: "", note: "file too large to preview" };
  return { path: rel, size: st.size, updated: st.mtime.toISOString(), body: read(full) };
}
function skills() {
  const dir = join2(ROOT, ".agents/skills");
  if (!existsSync2(dir))
    return [];
  return readdirSync(dir).filter((d) => existsSync2(join2(dir, d, "SKILL.md")) || existsSync2(join2(dir, d, "AGENTS.md"))).map((d) => {
    const p = existsSync2(join2(dir, d, "SKILL.md")) ? join2(dir, d, "SKILL.md") : join2(dir, d, "AGENTS.md");
    const fm = frontmatter(read(p));
    const name = String(fm.name ?? d);
    const description = String(fm.description ?? "").slice(0, 240);
    const aett = name.includes("-") ? name.split("-")[0] : "galdr";
    return { id: `skl-${d}`, name, aett, description, capabilities: [], validated: true, domain: "ymirlabs", createdAt: "" };
  });
}
async function runtime() {
  const digest = await runAsync(["bash", "bin/saga-session-start.sh"], 1e4);
  const markers = {
    lock: read(join2(STATE_DIR, ".lock")).trim(),
    started: existsSync2(join2(STATE_DIR, ".session-start-complete")),
    armed: existsSync2(join2(STATE_DIR, ".supervision-armed"))
  };
  return { digest, markers, doc: "docs/session-start.md" };
}
function cronConfigPath() {
  const home = join2(HOME_DIR, "config", "cron.yaml");
  if (existsSync2(home))
    return { path: home, source: "home" };
  const repo = join2(CONFIG_DIR2, "cron.yaml");
  if (existsSync2(repo))
    return { path: repo, source: "repo" };
  const example = join2(CONFIG_DIR2, "cron.yaml.example");
  if (existsSync2(example))
    return { path: example, source: "example" };
  return { path: "", source: "none" };
}
function parseCronJobs(cfg) {
  const jobs = [];
  for (const raw of cfg.split(`
`)) {
    const line = raw.trim();
    if (!line || line.startsWith("#"))
      continue;
    let rest = line;
    let role = "";
    if (line.startsWith("@")) {
      role = line.split(/\s+/)[0].slice(1);
      rest = line.slice(line.indexOf(" ") + 1).trim();
    }
    const m = rest.match(/^(\d{2}:\d{2})\s+(.+)$/);
    if (!m)
      continue;
    let tail = m[2];
    if (tail.startsWith("@")) {
      role = tail.split(/\s+/)[0].slice(1);
      tail = tail.slice(tail.indexOf(" ") + 1).trim();
    }
    if (!tail)
      continue;
    jobs.push({ at: m[1], role, command: tail });
  }
  return jobs;
}
function roleWords(role) {
  return role ? role.split(",") : [];
}
function jobApplies(job, roles) {
  if (!job.role)
    return true;
  return roleWords(job.role).some((w) => roles.includes(w));
}
async function cron() {
  const { path, source } = cronConfigPath();
  const cfg = path ? read(path) : "";
  const jobs = parseCronJobs(cfg);
  const status = await runAsync(["bash", "bin/nornir-cron-start.sh", "--status"]);
  const running = status.includes("running");
  const pid = (status.match(/pid=(\d+)/) ?? [])[1] ?? "";
  const log = read(join2(STATE_DIR, "cron.log"));
  const sleepLines = log.split(`
`).filter((l) => l.includes("cron retired") || l.includes("cron run"));
  const why = running ? "" : sleepLines.length ? (sleepLines[sleepLines.length - 1].match(/cron retired - (.+)$/) ?? [])[1] ?? "stopped" : "never started this session";
  let roles = [];
  try {
    roles = JSON.parse(await runAsync(["bash", "bin/topology.sh", "--json"])).roles ?? [];
  } catch {}
  const last = {};
  const stampDir = join2(STATE_DIR, ".cron-fired");
  for (const j of jobs) {
    const f = join2(stampDir, j.command.replace(/[^A-Za-z0-9._-]/g, "_"));
    if (existsSync2(f))
      last[j.command] = read(f).trim();
  }
  const applies = jobs.filter((j) => jobApplies(j, roles)).length;
  return {
    running,
    pid,
    why,
    source,
    roles,
    jobs: jobs.map((j) => ({ at: j.at, role: j.role, command: j.command, status: running ? "scheduled" : "stopped", applies: jobApplies(j, roles) })),
    last
  };
}
var DEFAULT_SERVER_SEATS = [
  { seat: "whynot", host: "whynot" },
  { seat: "zerwizserver", host: "server" }
];
function serverSeats() {
  const env = process.env.YMIR_CRON_SERVER_SEATS;
  if (env) {
    return env.split(/\s+/).filter(Boolean).map((e) => {
      const [seat, host] = e.split(":");
      return { seat, host: host ?? seat };
    });
  }
  return DEFAULT_SERVER_SEATS;
}
async function cronSeats() {
  const { path } = cronConfigPath();
  const localJobs = parseCronJobs(path ? read(path) : "");
  const rows = [];
  for (const s of serverSeats()) {
    const out = await runAsync([
      "ssh",
      "-o",
      "BatchMode=yes",
      "-o",
      "ConnectTimeout=3",
      s.host,
      `bash -lc 'G=$HOME/ymir; [ -d "$G/bin" ] || G=$(dirname "$(ls -d "$HOME"/*ymir*/bin 2>/dev/null | head -1)" 2>/dev/null); cd "$G" 2>/dev/null || exit 1; bash bin/nornir-cron-start.sh --status; bash bin/topology.sh --json 2>/dev/null'`
    ], 8000);
    if (!out) {
      rows.push({ seat: s.seat, host: s.host, reachable: false, running: false, pid: "", roles: [], jobs: localJobs.length, applies: 0, error: "unreachable (ssh ring)" });
      continue;
    }
    const running = out.includes("running");
    const pid = (out.match(/pid=(\d+)/) ?? [])[1] ?? "";
    let roles = [];
    try {
      roles = JSON.parse(out.slice(out.indexOf("{"))).roles ?? [];
    } catch {}
    rows.push({
      seat: s.seat,
      host: s.host,
      reachable: true,
      running,
      pid,
      roles,
      jobs: localJobs.length,
      applies: localJobs.filter((j) => jobApplies(j, roles)).length
    });
  }
  return rows;
}
function parseToon(text) {
  const rows = [];
  const lines = text.split(`
`);
  const header = lines.find((l) => /\{[^}]+\}:/.test(l));
  if (!header)
    return rows;
  const keys = (header.match(/\{([^}]+)\}/) ?? ["", ""])[1].split(",");
  const start = lines.indexOf(header);
  for (let i = start + 1;i < lines.length; i++) {
    const l = lines[i];
    if (!/^\s{2,}"/.test(l))
      break;
    const vals = l.trim().split(/","/).map((v) => v.replace(/^"|"$/g, ""));
    const row = {};
    keys.forEach((k, idx) => row[k.trim()] = vals[idx] ?? "");
    rows.push(row);
  }
  return rows;
}
async function loaders() {
  return parseToon(await runAsync(["bash", "bin/valknut-load.sh", "--status"]));
}
async function checks() {
  try {
    return JSON.parse(await runAsync(["bash", ".agents/skills/galdr-ymirsystem/scripts/compliance-check.sh", "--json"], 60000)).checks ?? [];
  } catch {
    return [];
  }
}
function settings() {
  const dir = CONFIG_DIR2;
  if (!existsSync2(dir))
    return [];
  return readdirSync(dir).map((f) => {
    const v = read(join2(dir, f)).trim().slice(0, 120);
    return { key: f, set: v.length > 0, value: v };
  });
}
function stream() {
  let cursor = 0;
  try {
    cursor = statSync(RUNES).size;
  } catch {}
  return new Response(new ReadableStream({
    start(controller) {
      const enc = new TextEncoder;
      const tick = setInterval(() => {
        try {
          const size = statSync(RUNES).size;
          if (size > cursor) {
            const tail = readFileSync2(RUNES, "utf8").slice(cursor);
            cursor = size;
            for (const line of tail.split(`
`)) {
              if (!line.trim().startsWith("{"))
                continue;
              const e = JSON.parse(line);
              const ev = {
                id: String(e.checksum ?? Date.now()).slice(0, 12),
                ts: e.timestamp ?? new Date().toISOString(),
                kind: "rune",
                from: e.actor ?? "brokk",
                module: e.event ?? "",
                message: e.message ?? "",
                checksum: String(e.checksum ?? "").slice(0, 8)
              };
              controller.enqueue(enc.encode(`data: ${JSON.stringify(ev)}

`));
            }
          }
        } catch {}
      }, 2000);
      controller._tick = tick;
    },
    cancel() {}
  }), { headers: { "content-type": "text/event-stream", "cache-control": "no-store", connection: "keep-alive" } });
}
var CHAT_DIR = join2(STATE_DIR, "chat");
var CHAT_WINDOW = 40;
var SAFE_SESSION = /^[A-Za-z0-9._-]+$/;
var PI_MODELS_PATH = join2(homedir2(), ".pi/agent/models.json");
var PI_SETTINGS_PATH = join2(homedir2(), ".pi/agent/settings.json");
var CHAT_BASES = [
  process.env.CHAT_BASE_URL,
  "http://127.0.0.1:8080/v1",
  "http://127.0.0.1:4603/v1"
].filter(Boolean);
var CHAT_MODEL_ENV = process.env.CHAT_MODEL;
var modelFor = {};
async function listModels(base) {
  const res = await fetch(`${base}/models`);
  const data = await res.json();
  return (data.data ?? []).map((m) => m.id ?? "").filter(Boolean);
}
function piCatalog() {
  const out = [];
  try {
    const raw = JSON.parse(read(PI_MODELS_PATH));
    for (const [pkey, pv] of Object.entries(raw.providers ?? {})) {
      const base = pv.baseUrl ?? "";
      if (!base)
        continue;
      const kind = /(127\.0\.0\.1|localhost)/.test(base) ? "local" : "online";
      const models = (pv.models ?? []).map((m) => m.id ?? "").filter(Boolean);
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
          label: mid
        });
      }
    }
  } catch {}
  return out;
}
async function resolveModel(base) {
  if (CHAT_MODEL_ENV)
    return CHAT_MODEL_ENV;
  if (modelFor[base])
    return modelFor[base];
  const ids = await listModels(base);
  const pick = ids.find((i) => /gemma|qwen|deepseek|hermes/i.test(i)) ?? ids[0];
  if (!pick)
    throw new Error("no models advertised");
  modelFor[base] = pick;
  return pick;
}
function resolveChatTarget(model) {
  const cat = piCatalog();
  if (model) {
    const bare = model.includes("/") ? model.slice(model.indexOf("/") + 1) : model;
    const matches = cat.filter((e) => e.id === model || e.name === model || e.model === bare);
    if (matches.length) {
      const seen = new Set;
      return matches.filter((e) => {
        const key = `${e.base}|${e.model}`;
        if (seen.has(key))
          return false;
        seen.add(key);
        return true;
      });
    }
    if (/^(opencode-go|opencode)\//.test(model)) {
      return [{ base: "http://127.0.0.1:4603/v1", model, label: model, kind: "online" }];
    }
    const raw = [
      { base: "http://127.0.0.1:8080/v1", model, label: model, kind: "local" },
      { base: "http://127.0.0.1:4603/v1", model, label: model, kind: "online" }
    ];
    return raw;
  }
  const targets = [];
  try {
    const s = JSON.parse(read(PI_SETTINGS_PATH));
    const d = cat.find((e) => e.provider === s.defaultProvider && e.model === s.defaultModel) ?? cat.find((e) => e.provider === s.defaultProvider);
    if (d)
      targets.push(d);
  } catch {}
  const local = cat.find((e) => e.kind === "local");
  if (local && !targets.some((t) => t.base === local.base && t.model === local.model))
    targets.push(local);
  for (const base of CHAT_BASES) {
    if (!targets.some((t) => t.base === base))
      targets.push({ base, model: "", label: "", kind: base.includes("4603") ? "online" : "local" });
  }
  return targets;
}
async function chatCompletion(messages, targets) {
  let lastErr = "";
  for (const t of targets) {
    try {
      const model = t.model || await resolveModel(t.base);
      const headers = { "content-type": "application/json" };
      if (t.key)
        headers.authorization = `Bearer ${t.key}`;
      const res = await fetch(`${t.base}/chat/completions`, {
        method: "POST",
        headers,
        body: JSON.stringify({ model, messages, stream: false, temperature: 0.6, max_tokens: Number(process.env.YMIR_CHAT_MAX_TOKENS ?? 4096) })
      });
      if (!res.ok) {
        lastErr = `${t.base} \u2192 ${res.status}`;
        continue;
      }
      const data = await res.json();
      const body = data.choices?.[0]?.message?.content?.trim();
      if (body)
        return { body, backend: t.base, model };
      lastErr = `${t.base} \u2192 empty`;
    } catch (err) {
      lastErr = `${t.base} \u2192 ${err.message}`;
    }
  }
  throw new Error(lastErr || "no chat backend reachable");
}
async function chatModels() {
  const out = new Map;
  for (const e of piCatalog())
    out.set(e.id, { id: e.id, name: e.name, provider: e.provider, kind: e.kind });
  try {
    const res = await fetch("http://127.0.0.1:4603/v1/models", { signal: AbortSignal.timeout(2500) });
    if (res.ok) {
      const data = await res.json();
      for (const m of data.data ?? []) {
        const id = m.id ?? "";
        if (id && !out.has(id))
          out.set(id, { id, name: id, provider: "opencode-go", kind: "online" });
      }
    }
  } catch {}
  return [...out.values()].sort((a, b) => a.id.localeCompare(b.id));
}
var KAIA_SYSTEM = [
  "You are Kaia, the oracle by the well (Mimirsbrunn), the orchestrator of the Ymir fleet.",
  "Address the Allfather directly in every reply; never respond with zero direct address.",
  "Apply Norse methodology: name subsystems for the role-matched figure; never use imported terms.",
  "Drink from the well before you answer; when a recall excerpt is provided, ground the reply in it.",
  "Be concise, direct, and action-oriented \u2014 produce outcomes, not preamble.",
  "You may dispatch Eindri in the real system; here, state plainly what you recalled and what you would dispatch."
].join(" ");
function chatFile(session) {
  const safe = SAFE_SESSION.test(session) ? session : "default";
  return join2(CHAT_DIR, `${safe}.jsonl`);
}
function chatHistory(session = "default") {
  return read(chatFile(session)).split(`
`).filter((l) => l.trim().startsWith("{")).map((l) => {
    try {
      return JSON.parse(l);
    } catch {
      return null;
    }
  }).filter(Boolean);
}
function appendChat(session, row) {
  mkdirSync2(CHAT_DIR, { recursive: true });
  appendFileSync(chatFile(session), `${JSON.stringify(row)}
`);
}
function chatSessions() {
  mkdirSync2(CHAT_DIR, { recursive: true });
  if (!existsSync2(chatFile("default")))
    appendFileSync(chatFile("default"), "");
  const ids = readdirSync(CHAT_DIR).filter((f) => f.endsWith(".jsonl")).map((f) => f.replace(/\.jsonl$/, "")).filter((id) => SAFE_SESSION.test(id));
  return ids.map((id) => {
    const fp = chatFile(id);
    let messages = 0;
    let updated_at = null;
    try {
      messages = read(fp).split(`
`).filter((l) => l.trim().startsWith("{")).length;
      updated_at = statSync(fp).mtime.toISOString();
    } catch {}
    return { id, messages, updated_at };
  }).sort((a, b) => (b.updated_at ?? "").localeCompare(a.updated_at ?? ""));
}
function deleteChatSession(session) {
  try {
    unlinkSync(chatFile(session));
  } catch {}
  return { ok: true };
}
function chatRecall_uncached(query, limit = 6) {
  const lines = read(WELL).split(`
`).filter((l) => l.trim().startsWith("{"));
  const terms = query.toLowerCase().split(/[^a-z0-9]+/).filter((w) => w.length > 3);
  const scored = [];
  for (const line of lines) {
    try {
      const e = JSON.parse(line);
      const content = String(e.content ?? "");
      const head = content.split(`
`)[0].replace(/^#+\s*/, "").trim();
      if (!head)
        continue;
      const low = content.toLowerCase();
      let score = 0;
      for (const t of terms)
        if (low.includes(t))
          score++;
      scored.push({ score, source: e.source ?? "well", head, i: scored.length });
    } catch {}
  }
  scored.sort((a, b) => b.score - a.score || b.i - a.i);
  const picks = scored.slice(0, limit);
  return {
    text: picks.map((p) => `- (${p.source}) ${p.head.slice(0, 140)}`).join(`
`),
    count: picks.length
  };
}
function chatRecall(query, limit = 6) {
  return memo(`chatRecall:${query}:${limit}`, 3000, () => chatRecall_uncached(query, limit));
}
async function postChat(session, content, model, agents) {
  mkdirSync2(CHAT_DIR, { recursive: true });
  const sid = SAFE_SESSION.test(session) ? session : "default";
  const user = { id: `u-${Date.now()}`, from: "user", body: content, ts: new Date().toISOString() };
  appendChat(sid, user);
  const history = chatHistory(sid).slice(-CHAT_WINDOW);
  const recall = chatRecall(content);
  const lanes = agents?.length ? `

Focused Eindri lanes: ${agents.join(", ")}.` : "";
  const messages = [
    {
      role: "system",
      content: `${KAIA_SYSTEM}${lanes}

Well recall:
${recall.text || "(dry \u2014 answer from first principles, and say the well was dry)"}`
    },
    ...history.map((m) => ({ role: m.from === "user" ? "user" : "assistant", content: m.body }))
  ];
  let body;
  let live = false;
  let usedModel;
  try {
    const out = await chatCompletion(messages, resolveChatTarget(model));
    body = out.body;
    usedModel = out.model;
    live = true;
  } catch (err) {
    body = `The well is local; no model backend answered (${err.message}). Recall ran; for a reply, raise a local model (llama-server on :8080) or the Bifrost bridge (\`bin/bifrost-bridge.sh\`).`;
  }
  const kaia = {
    id: `k-${Date.now()}`,
    from: "kaia",
    body,
    ts: new Date().toISOString(),
    recalling: recall.count > 0,
    ...usedModel ? { model: usedModel } : {},
    ...agents?.length ? { agents } : {},
    ...live ? {} : { error: true }
  };
  appendChat(sid, kaia);
  return { reply: kaia, live };
}
var PROMPT_ROOT = join2(ROOT, "smidja/smidja_data/prompt_engineering");
function prompts() {
  if (!existsSync2(PROMPT_ROOT))
    return [];
  const out = [];
  for (const agent of readdirSync(PROMPT_ROOT).sort()) {
    const dir = join2(PROMPT_ROOT, agent);
    try {
      if (!statSync(dir).isDirectory())
        continue;
    } catch {
      continue;
    }
    for (const kind of ["system", "user"]) {
      const fp = join2(dir, `${kind}.md`);
      if (existsSync2(fp)) {
        out.push({ agent, kind, path: `smidja/smidja_data/prompt_engineering/${agent}/${kind}.md`, body: read(fp) });
      }
    }
  }
  return out;
}
function savePrompt(agent, kind, body) {
  if (!/^[A-Za-z0-9._-]+$/.test(agent) || kind !== "system" && kind !== "user") {
    throw new Error("bad prompt id");
  }
  const fp = join2(PROMPT_ROOT, agent, `${kind}.md`);
  mkdirSync2(dirname(fp), { recursive: true });
  writeFileSync2(fp, body);
  return { ok: true, path: `smidja/smidja_data/prompt_engineering/${agent}/${kind}.md` };
}
function workspaces() {
  let regPath = join2(ROOT, "workspace/workspaces.yaml");
  const hoardReg = join2(HOARD, "identity/workspaces.yaml");
  try {
    read(hoardReg);
    regPath = hoardReg;
  } catch {}
  const txt = read(regPath);
  const out = [];
  let cur = null;
  for (const line of txt.split(`
`)) {
    const idm = line.match(/^\s*-\s+id:\s*(\S+)/);
    if (idm) {
      if (cur)
        out.push(cur);
      cur = { id: idm[1], name: idm[1], kind: "personal", domains: [] };
      continue;
    }
    if (!cur)
      continue;
    const nm = line.match(/^\s*name:\s*(.+)$/);
    if (nm)
      cur.name = nm[1].trim();
    const km = line.match(/^\s*kind:\s*(\S+)/);
    if (km)
      cur.kind = km[1];
    const cm = line.match(/^\s*company:\s*(\S+)/);
    if (cm)
      cur.company = cm[1];
    const dm = line.match(/^\s*domains:\s*\[(.*)\]/);
    if (dm)
      cur.domains = dm[1].split(",").map((s) => s.trim()).filter(Boolean);
  }
  if (cur)
    out.push(cur);
  return out.length ? out : [
    { id: "work", name: "Work", kind: "work", domains: ["company", "marketing", "development", "life"] },
    { id: "personal", name: "Personal", kind: "personal", domains: ["me", "life", "development"] }
  ];
}
async function setupStatus() {
  return parseToon(await runAsync(["bash", "bin/ymir-install.sh", "--check"], 30000));
}
function setupRun() {
  return parseToon(run(["bash", "bin/ymir-install.sh", "--skip-services"]));
}
function workspaceProvision(name, kind, domains) {
  return parseToon(run(["bash", "bin/workspace-provision.sh", name, "--kind", kind, "--domains", domains]));
}
var GATE_AUTH = process.env.HLIDSKJALF_AUTH ?? "";
var SMIDJA_URL = process.env.SMIDJA_VIZ_URL ?? "http://127.0.0.1:8437";
var SMIDJA_HOST = (process.env.SMIDJA_HOST ?? "").toLowerCase();
var ODRERIR_HOST = (process.env.ODRERIR_HOST ?? "").toLowerCase();
var PRIMARY_HOST = (process.env.YMIR_PRIMARY_HOST ?? "").toLowerCase();
var ODRERIR_URL = process.env.ODRERIR_URL ?? "http://127.0.0.1:4322";
var APP_HOSTS = [
  { host: SMIDJA_HOST, base: SMIDJA_URL, name: "Sm\xED\xF0ja" },
  { host: ODRERIR_HOST, base: ODRERIR_URL, name: "\xD3\xF0rerir" }
].filter((a) => a.host !== "");
var DIST = join2(ROOT, "apps/hlidskjalf/dist");
var SESSIONS = new Map;
function cookieToken(req) {
  const c = req.headers.get("cookie") ?? "";
  const m = c.match(/(?:^|;\s*)ymir_session=([^;]+)/);
  return m ? m[1] : "";
}
function isAuthed(req) {
  if (isDesktopSeat(req))
    return true;
  const t = cookieToken(req);
  return !!t && SESSIONS.has(t);
}
var REQUEST_IP = new WeakMap;
function isDesktopSeat(req) {
  const marked = (req.headers.get("x-ymir-surface") ?? "") === "desktop" || new URL(req.url).searchParams.get("surface") === "desktop";
  if (!marked)
    return false;
  const ip = REQUEST_IP.get(req) ?? req.socket?.remoteAddress ?? "";
  const bare = ip.startsWith("::ffff:") ? ip.slice("::ffff:".length) : ip;
  return bare === "127.0.0.1" || bare === "::1";
}
function seatOf(req) {
  if (isDesktopSeat(req)) {
    const user = (GATE_AUTH || "").split(":")[0];
    return user || "operator";
  }
  return loginOf(req);
}
function loginOf(req) {
  return SESSIONS.get(cookieToken(req)) ?? null;
}
function sessionResponse(login) {
  const token = crypto.randomUUID();
  SESSIONS.set(token, login);
  return new Response(JSON.stringify({ ok: true, login }), {
    headers: {
      "content-type": "application/json",
      "set-cookie": `ymir_session=${token}; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000`
    }
  });
}
async function proxyApp(req, url, base = SMIDJA_URL, label = "smidja") {
  const headers = new Headers(req.headers);
  headers.delete("host");
  headers.delete("cookie");
  headers.delete("connection");
  const init = { method: req.method, headers, redirect: "manual" };
  if (req.method !== "GET" && req.method !== "HEAD")
    init.body = await req.arrayBuffer();
  try {
    const up = await fetch(`${base}${url.pathname}${url.search}`, init);
    return new Response(up.body, { status: up.status, headers: up.headers });
  } catch (err) {
    return json({ error: `${label} upstream unreachable: ${err.message}` }, 502);
  }
}
var STATIC_TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".css": "text/css",
  ".map": "application/json",
  ".json": "application/json",
  ".webmanifest": "application/manifest+json",
  ".xml": "application/xml",
  ".txt": "text/plain; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
  ".gif": "image/gif",
  ".ico": "image/x-icon",
  ".woff": "font/woff",
  ".woff2": "font/woff2",
  ".ttf": "font/ttf",
  ".wasm": "application/wasm",
  ".mp4": "video/mp4",
  ".webm": "video/webm",
  ".apk": "application/vnd.android.package-archive"
};
function serveStatic(pathname) {
  const rel = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
  let file = join2(DIST, rel);
  if (!file.startsWith(DIST) || !existsSync2(file) || statSync(file).isDirectory())
    file = join2(DIST, "index.html");
  const ext = extname(file).toLowerCase();
  const headers = { "content-type": STATIC_TYPES[ext] ?? "application/octet-stream" };
  if (ext === ".html")
    headers["cache-control"] = "no-cache, no-store, must-revalidate";
  if (ext === ".apk")
    headers["content-disposition"] = 'attachment; filename="ymir.apk"';
  if (ext === ".apk" || ext === ".woff" || ext === ".woff2" || ext === ".ttf")
    headers["cache-control"] = "public, max-age=86400";
  try {
    return new Response(readFileSync2(file), { headers });
  } catch {
    return new Response("Not found", { status: 404 });
  }
}
var server = Bun.serve({
  port: PORT,
  async fetch(req, srv) {
    const url = new URL(req.url);
    const p = url.pathname;
    REQUEST_IP.set(req, srv.requestIP(req)?.address ?? "");
    try {
      if (p === "/api/login" && req.method === "POST") {
        const b = await req.json().catch(() => ({}));
        const user = b.username ?? "";
        const pass = b.password ?? "";
        let login = null;
        if (GATE_AUTH && `${user}:${pass}` === GATE_AUTH)
          login = user;
        else if (user && pass)
          login = await verify(user, pass);
        if (login)
          return sessionResponse(login);
        return json({ error: "invalid credentials" }, 401);
      }
      if (p === "/api/register" && req.method === "POST") {
        const b = await req.json().catch(() => ({}));
        const made = await register(b.username ?? "", b.password ?? "", b.invite ?? "");
        if (!made.ok)
          return json({ error: made.reason }, 403);
        return sessionResponse(made.login);
      }
      if (p === "/api/auth/github" && req.method === "GET") {
        const clientId = process.env.GITHUB_CLIENT_ID ?? "";
        const clientSecret = process.env.GITHUB_CLIENT_SECRET ?? "";
        if (!clientId || !clientSecret) {
          return json({
            error: "GitHub sign-in is not configured. Set GITHUB_CLIENT_ID and GITHUB_CLIENT_SECRET in .env.local (a GitHub OAuth app) and restart the gate."
          }, 503);
        }
        const state = crypto.randomUUID();
        const redirect = `${url.origin}/api/auth/github/callback`;
        const authorize = "https://github.com/login/oauth/authorize" + `?client_id=${encodeURIComponent(clientId)}` + `&redirect_uri=${encodeURIComponent(redirect)}` + "&scope=read:user&state=" + encodeURIComponent(state);
        return new Response(JSON.stringify({ url: authorize }), {
          headers: {
            "content-type": "application/json",
            "set-cookie": `ymir_oauth_state=${state}; Path=/; HttpOnly; SameSite=Lax; Max-Age=600`
          }
        });
      }
      if (p === "/api/auth/github/callback" && req.method === "GET") {
        const clientId = process.env.GITHUB_CLIENT_ID ?? "";
        const clientSecret = process.env.GITHUB_CLIENT_SECRET ?? "";
        const code = url.searchParams.get("code") ?? "";
        const state = url.searchParams.get("state") ?? "";
        const expected = (req.headers.get("cookie") ?? "").match(/ymir_oauth_state=([^;]+)/)?.[1] ?? "";
        if (!code)
          return json({ error: "GitHub returned no code" }, 400);
        if (!state || state !== expected)
          return json({ error: "OAuth state did not match" }, 400);
        const tokenRes = await fetch("https://github.com/login/oauth/access_token", {
          method: "POST",
          headers: { "content-type": "application/json", accept: "application/json" },
          body: JSON.stringify({ client_id: clientId, client_secret: clientSecret, code })
        });
        const tok = await tokenRes.json().catch(() => ({}));
        if (!tok.access_token)
          return json({ error: "GitHub refused the code" }, 502);
        const userRes = await fetch("https://api.github.com/user", {
          headers: {
            authorization: `Bearer ${tok.access_token}`,
            accept: "application/vnd.github+json",
            "user-agent": "ymir-gate"
          }
        });
        const gh = await userRes.json().catch(() => ({}));
        const login = (gh.login ?? "").trim().toLowerCase();
        if (!login)
          return json({ error: "GitHub returned no login" }, 502);
        if (!findAccount(login)) {
          return json({ error: `No account is held for the GitHub login '${login}'. Ask for an invite code, then register.` }, 403);
        }
        return sessionResponse(login);
      }
      if (p === "/api/invites" && req.method === "GET" && isAuthed(req)) {
        return json({
          invites: listInvites().map((i) => ({ ...i, code: i.code })),
          accounts: listAccounts()
        });
      }
      if (p === "/api/session") {
        return json({
          authed: GATE_AUTH ? isAuthed(req) : true,
          login: seatOf(req),
          registration: invitesOpen(),
          github: !!(process.env.GITHUB_CLIENT_ID && process.env.GITHUB_CLIENT_SECRET)
        });
      }
      if (p === "/api/logout" && req.method === "POST") {
        SESSIONS.delete(cookieToken(req));
        return new Response(JSON.stringify({ ok: true }), {
          headers: { "content-type": "application/json", "set-cookie": "ymir_session=; Path=/; Max-Age=0" }
        });
      }
      const host = (req.headers.get("host") ?? "").toLowerCase().split(":")[0];
      const app = APP_HOSTS.find((a) => a.host === host);
      if (app) {
        if (!isAuthed(req)) {
          if (p.startsWith("/api/"))
            return json({ error: "unauthorized" }, 401);
          const scheme = (req.headers.get("x-forwarded-proto") ?? "https").split(",")[0];
          const door = PRIMARY_HOST || host;
          return new Response(null, {
            status: 302,
            headers: { location: `${scheme}://${door}/?next=${encodeURIComponent(url.toString())}` }
          });
        }
        return proxyApp(req, url, app.base, app.name);
      }
      if (GATE_AUTH && p.startsWith("/api/") && !isAuthed(req))
        return json({ error: "unauthorized" }, 401);
      if (p === "/api/health")
        return json({ ok: true, root: ROOT, sessions: orders().length });
      if (p === "/api/usage") {
        return json(await memoAsync("usage", 60000, async () => {
          try {
            const { execFileSync } = await import("child_process");
            const script = new URL("../../../bin/hlidskjalf-usage.sh", import.meta.url).pathname;
            const out = execFileSync(script, ["--days", process.env.YMIR_USAGE_DAYS ?? "30"], { timeout: 60000 }).toString().trim();
            return JSON.parse(out);
          } catch (e) {
            return { error: String(e).slice(0, 120) };
          }
        }));
      }
      if (p === "/api/worktrees")
        return json(await worktrees());
      if (p === "/api/me")
        return json({ login: loginOf(req) ?? "operator", realm: "work" });
      if (p === "/api/workspace") {
        const realm = url.searchParams.get("realm") ?? "work";
        return json({ realm, path: workspaceRoot(realm) });
      }
      if (p === "/api/agents") {
        try {
          const { execFileSync } = await import("child_process");
          const script = new URL("../../../bin/hlidskjalf-agents.sh", import.meta.url).pathname;
          const out = execFileSync(script, [], {
            timeout: 4000,
            cwd: ROOT,
            env: { ...process.env, ROSTER_DIR: AGENTS_ALT }
          }).toString().trim();
          if (out.startsWith("[")) {
            const rows = JSON.parse(out);
            if (Array.isArray(rows) && rows.length > 0) {
              return new Response(out, { headers: { "content-type": "application/json" } });
            }
          }
        } catch {}
        return json(agents());
      }
      if (p === "/api/tasks")
        return json(tasks());
      if (p === "/api/orders")
        return json({ open: orders().filter((o) => o.status !== "COMPLETED").length, orders: orders() });
      if (p === "/api/runes")
        return json(runes());
      if (p === "/api/well")
        return json(await well(url.searchParams.get("q") ?? ""));
      if (p === "/api/well/episode")
        return json(await wellEpisode(url.searchParams.get("id") ?? "") ?? { error: "not found" });
      if (p === "/api/mimir/health")
        return json(await mimirHealth());
      if (p === "/api/processes")
        return json(await processes());
      if (p === "/api/reviews")
        return json(await memoAsync("reviews", 60000, reviews));
      if (p === "/api/files")
        return json(files(url.searchParams.get("realm") ?? "work"));
      if (p === "/api/file")
        return json(fileContent(url.searchParams.get("realm") ?? "work", url.searchParams.get("path") ?? ""));
      if (p === "/api/skills")
        return json(skills());
      if (p === "/api/runtime")
        return json(await runtime());
      if (p === "/api/desktop" && req.method === "POST") {
        const body = await req.json().catch(() => ({}));
        const view = body?.view;
        const VIEWS = ["hlidskjalf", "smidja", "sessrumnir", "odrerir"];
        if (!VIEWS.includes(view)) {
          return json({ error: "view must be hlidskjalf, smidja, sessrumnir, or odrerir" }, 400);
        }
        const argv = view === "sessrumnir" ? ["bash", join2(ROOT, "bin", "sessrumnir.sh"), "start"] : ["bash", join2(ROOT, "scripts", "electron.sh"), "start", "--view", view];
        const proc = Bun.spawn(argv, { stdout: "pipe", stderr: "pipe", env: process.env });
        const out = await new Response(proc.stdout).text();
        await proc.exited;
        return json({ view, ok: proc.exitCode === 0, output: out.trim().slice(-400) });
      }
      if (p === "/api/cron")
        return json(await cron());
      if (p === "/api/cron/seats")
        return json(await cronSeats());
      if (p === "/api/loaders")
        return json(await loaders());
      if (p === "/api/checks")
        return json(await checks());
      if (p === "/api/smidja/health")
        return json(smidjaHealth());
      if (p === "/api/smidja/sessions")
        return json(smidjaSessions());
      if (p === "/api/smidja/decisions")
        return json(smidjaDecisions());
      if (p === "/api/smidja/stats")
        return json(smidjaStats());
      if (p.startsWith("/api/smidja/sessions/")) {
        const id = decodeURIComponent(p.slice("/api/smidja/sessions/".length));
        const detail = smidjaSession(id);
        return detail ? json(detail) : json({ error: `no session ${id}` }, 404);
      }
      if (p === "/api/settings")
        return json(settings());
      if (p === "/api/workspaces" && req.method === "GET")
        return json(workspaces());
      if (p === "/api/workspaces" && req.method === "POST") {
        const b = await req.json().catch(() => ({}));
        const name = (b.name ?? "").trim().toLowerCase().replace(/[^a-z0-9-]+/g, "-").replace(/(^-|-$)/g, "");
        if (!name)
          return json({ error: "workspace needs a name" }, 400);
        const kind = b.kind === "work" ? "work" : "personal";
        const domains = Array.isArray(b.domains) ? b.domains.join(",") : b.domains ?? "";
        return json(workspaceProvision(name, kind, domains));
      }
      if (p === "/api/setup/status")
        return json(await setupStatus());
      if (p === "/api/setup/run" && req.method === "POST")
        return json(setupRun());
      if (p === "/api/prompts" && req.method === "GET")
        return json(prompts());
      if (p === "/api/prompts" && req.method === "POST") {
        const body = await req.json().catch(() => ({}));
        if (!body.agent || !body.kind)
          return json({ error: "prompt needs agent + kind" }, 400);
        return json(savePrompt(body.agent, body.kind, body.body ?? ""));
      }
      if (p === "/api/stream")
        return stream();
      if (p === "/api/chat/models")
        return json(await chatModels());
      if (p === "/api/chat/sessions")
        return json(chatSessions());
      if (p === "/api/chat/history")
        return json(chatHistory(url.searchParams.get("session") ?? "default"));
      if (p === "/api/chat/session" && req.method === "DELETE") {
        return json(deleteChatSession(url.searchParams.get("session") ?? "default"));
      }
      if (p === "/api/chat" && req.method === "POST") {
        const body = await req.json().catch(() => ({}));
        const content = (body.content ?? "").trim();
        if (!content)
          return json({ error: "chat needs content" }, 400);
        return json(await postChat(body.session ?? "default", content, body.model, body.agents));
      }
      if (p.startsWith("/api/"))
        return json({ error: `no route ${p}` }, 404);
      return serveStatic(p);
    } catch (err) {
      return json({ error: err.message }, 500);
    }
  }
});
console.log(`[hlidskjalf] gate api   http://127.0.0.1:${server.port}`);
console.log(`[hlidskjalf] runtime    ${ROOT}`);
