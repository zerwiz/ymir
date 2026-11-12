/**
 * The model door's eyes: find every model the user can already reach, without editing a file.
 *
 * It looks, read-only, in the places a user's providers already live:
 *   - keys in the environment (OPENAI_API_KEY, ANTHROPIC_API_KEY, OPENROUTER_API_KEY, …)
 *   - pi's ~/.pi/agent/auth.json + models.json
 *   - OpenCode's ~/.config/opencode/opencode.json(c) + ~/.local/share/opencode/auth.json
 *   - Hermes' own ~/.hermes/config.yaml (its model block) + ~/.hermes/.env
 *   - the providers added on the Models screen (data/models/providers.json; keys in the home's secrets)
 *   - local servers answering /v1/models on the usual ports (Ollama 11434, LM Studio 1234,
 *     llama.cpp / llama-swap 8080, vLLM 8000)
 * Probe, never assume (RULES/25): a source that is missing is a clean skip, never an error.
 *
 * A key is NEVER returned, printed or sent to the browser. What the detector keeps is a reference to
 * where the key was found (an env name, or a file and the field in it); `resolveKey` reads it at the
 * moment a config is written.
 *
 * The allow-list is the operator's (`$YMIR_HOME/config/models-allowed.yaml`), judged by ONE door,
 * `bin/model/model-allow.sh filter` — this module never holds a second copy of the rule.
 *
 * Node builtins only, so `node server/src/models/detect.ts …` runs before the app's dependencies are
 * installed (setup.sh calls it for the first agent's model).
 */
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// ---------- shapes ----------

export type KeyRef =
  | { from: 'env'; name: string }
  | { from: 'json'; path: string; pointer: string[] }
  | { from: 'dotenv'; path: string; name: string }
  | { from: 'yaml-model'; path: string };

export interface FoundModel {
  id: string;
  allowed: boolean;
  /** Why it may not be chosen (only when allowed is false). */
  reason?: string;
}

export interface FoundProvider {
  /** The provider's name as the allow-list writes it: `<id>/<model>`. */
  id: string;
  name: string;
  /** OpenAI-compatible base, ending in /v1 (or the provider's own equivalent). */
  baseUrl: string;
  local: boolean;
  /** Where the key was found — never the key itself. */
  keyRef: KeyRef | null;
  /** Human words for where this provider was found, e.g. "pi (~/.pi/agent/auth.json)". */
  sources: string[];
  status: 'ok' | 'needs-key' | 'unreachable' | 'from-config';
  note?: string;
  models: FoundModel[];
  /** Added on the Models screen (so it can be removed there). */
  added?: boolean;
}

export interface Detection {
  at: string;
  policed: boolean;
  /** Where the allow-list lives (shown, so a user knows which file rules). */
  allowList: string | null;
  providers: FoundProvider[];
}

export interface DetectOptions {
  env?: NodeJS.ProcessEnv;
  home?: string;
  /** The app's data/models directory (choices, added providers). */
  modelsDir?: string;
  /** Local servers to probe; tests pass stub ports. */
  localPorts?: { kind: string; name: string; port: number; host?: string }[];
  /** Skip listing remote providers' models (setup's quick road and tests). */
  offline?: boolean;
  /** Override the allow door (tests). */
  allowDoor?: string | null;
  timeoutMs?: number;
}

// ---------- the common providers (presets for both detection and the "Add a provider" form) ----------

export interface Preset {
  id: string;
  name: string;
  baseUrl: string;
  /** The environment variable this provider's key usually lives in. */
  envKey?: string;
  needsKey: boolean;
  local?: boolean;
  /** Hint for where the user gets a key. */
  keyHint?: string;
}

/** The hand-kept providers: the local servers and the common few, always offered even with no catalog. */
const HAND_PRESETS: Preset[] = [
  { id: 'openrouter', name: 'OpenRouter', baseUrl: 'https://openrouter.ai/api/v1', envKey: 'OPENROUTER_API_KEY', needsKey: true, keyHint: 'openrouter.ai/keys' },
  { id: 'openai', name: 'OpenAI', baseUrl: 'https://api.openai.com/v1', envKey: 'OPENAI_API_KEY', needsKey: true, keyHint: 'platform.openai.com/api-keys' },
  { id: 'anthropic', name: 'Anthropic (Claude)', baseUrl: 'https://api.anthropic.com/v1', envKey: 'ANTHROPIC_API_KEY', needsKey: true, keyHint: 'console.anthropic.com' },
  { id: 'deepseek', name: 'DeepSeek', baseUrl: 'https://api.deepseek.com/v1', envKey: 'DEEPSEEK_API_KEY', needsKey: true, keyHint: 'platform.deepseek.com' },
  { id: 'groq', name: 'Groq', baseUrl: 'https://api.groq.com/openai/v1', envKey: 'GROQ_API_KEY', needsKey: true, keyHint: 'console.groq.com/keys' },
  { id: 'google', name: 'Google Gemini', baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai', envKey: 'GEMINI_API_KEY', needsKey: true, keyHint: 'aistudio.google.com/apikey' },
  { id: 'xai', name: 'xAI (Grok)', baseUrl: 'https://api.x.ai/v1', envKey: 'XAI_API_KEY', needsKey: true, keyHint: 'console.x.ai' },
  { id: 'mistral', name: 'Mistral', baseUrl: 'https://api.mistral.ai/v1', envKey: 'MISTRAL_API_KEY', needsKey: true, keyHint: 'console.mistral.ai' },
  { id: 'together', name: 'Together AI', baseUrl: 'https://api.together.xyz/v1', envKey: 'TOGETHER_API_KEY', needsKey: true },
  { id: 'fireworks', name: 'Fireworks', baseUrl: 'https://api.fireworks.ai/inference/v1', envKey: 'FIREWORKS_API_KEY', needsKey: true },
  { id: 'opencode-go', name: 'OpenCode Go', baseUrl: 'https://opencode.ai/inference/go/openai/v1', envKey: 'OPENCODE_API_KEY', needsKey: true, keyHint: 'opencode.ai' },
  { id: 'ollama', name: 'Ollama (this computer)', baseUrl: 'http://127.0.0.1:11434/v1', needsKey: false, local: true },
  { id: 'lmstudio', name: 'LM Studio (this computer)', baseUrl: 'http://127.0.0.1:1234/v1', needsKey: false, local: true },
  { id: 'llamacpp', name: 'llama.cpp / llama-swap (this computer)', baseUrl: 'http://127.0.0.1:8080/v1', needsKey: false, local: true },
  { id: 'vllm', name: 'vLLM (this computer)', baseUrl: 'http://127.0.0.1:8000/v1', needsKey: false, local: true },
];

/**
 * Every other provider, from the open catalog models.dev (github.com/sst/models.dev — the one OpenCode uses), cached
 * per machine by bin/model/providers-catalog.sh at $YMIR_HOME/state/models.dev.json. Only providers with an
 * OpenAI-compatible address are offered here; the rest need a translator (plan 275: LiteLLM, on demand).
 * The catalog carries NO keys — a key is pasted once and kept in the user's private home (plan 275, 2026-11-12).
 */
function catalogPresets(hand: Preset[]): Preset[] {
  const home = process.env.YMIR_HOME || path.join(os.homedir(), 'Documents', 'ymirhome');
  let cat: Record<string, any> = {};
  try { cat = JSON.parse(fs.readFileSync(path.join(home, 'state', 'models.dev.json'), 'utf8')); } catch { return []; }
  const norm = (u: string) => u.replace(/\/+$/, '').toLowerCase();
  const ids = new Set(hand.map((h) => h.id));
  const bases = new Set(hand.map((h) => norm(h.baseUrl)));
  const out: Preset[] = [];
  for (const [id, p] of Object.entries(cat)) {
    const api = typeof p?.api === 'string' ? p.api.trim() : '';
    if (!api || !/^https?:\/\//.test(api) || ids.has(id) || bases.has(norm(api))) continue;
    const env = Array.isArray(p.env) ? p.env.find((e: unknown) => typeof e === 'string' && /KEY|TOKEN/i.test(e)) : undefined;
    out.push({ id, name: String(p.name || id), baseUrl: api.replace(/\/+$/, ''), envKey: env, needsKey: true,
               keyHint: typeof p.doc === 'string' ? p.doc.replace(/^https?:\/\//, '') : undefined });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name));
}

export const PRESETS: Preset[] = [...HAND_PRESETS, ...catalogPresets(HAND_PRESETS)];

/** A placeholder is not a key (the app's own .env ships `XAI_API_KEY=unset`). */
const isKey = (v: string | undefined): v is string => !!v && !/^(unset|none|null|changeme|your[-_ ]?key.*|xxx+|<.*>)$/i.test(v.trim());

/** Extra env names that also carry a known provider's key. */
const ENV_ALIASES: Record<string, string> = { GOOGLE_API_KEY: 'google', OPENCODE_GO_API_KEY: 'opencode-go' };

/** BILSKIRNIR_LOCAL_PORTS="ollama:11434,llamacpp:8080" replaces the usual ports (RULES/07). */
export function localPortsFor(env: NodeJS.ProcessEnv = process.env) {
  const raw = env.BILSKIRNIR_LOCAL_PORTS;
  if (!raw) return DEFAULT_LOCAL_PORTS;
  return raw.split(',').map((x) => x.trim().split(':')).filter((p) => p.length === 2 && Number(p[1]) > 0)
    .map(([kind, port]) => ({ kind, name: PRESETS.find((q) => q.id === kind)?.name ?? kind, port: Number(port) }));
}

export const DEFAULT_LOCAL_PORTS = [
  { kind: 'ollama', name: 'Ollama', port: 11434 },
  { kind: 'lmstudio', name: 'LM Studio', port: 1234 },
  { kind: 'llamacpp', name: 'llama.cpp / llama-swap', port: 8080 },
  { kind: 'vllm', name: 'vLLM', port: 8000 },
];

// ---------- small helpers ----------

const tilde = (p: string, home: string) => (p.startsWith(home + path.sep) ? '~' + p.slice(home.length) : p);

function readJson(file: string): any {
  try {
    // JSONC: drop // and /* */ comments and trailing commas (opencode.jsonc)
    const raw = fs.readFileSync(file, 'utf8');
    try { return JSON.parse(raw); } catch { /* fall through to JSONC */ }
    const stripped = raw
      .replace(/("(?:\\.|[^"\\])*")|\/\/[^\n]*|\/\*[\s\S]*?\*\//g, (_m, s) => s ?? '')
      .replace(/,\s*([}\]])/g, '$1');
    return JSON.parse(stripped);
  } catch { return null; }
}

function readDotenv(file: string): Record<string, string> {
  const out: Record<string, string> = {};
  let text = '';
  try { text = fs.readFileSync(file, 'utf8'); } catch { return out; }
  for (const line of text.split('\n')) {
    const m = /^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/.exec(line);
    if (!m) continue;
    let v = m[2].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    out[m[1]] = v;
  }
  return out;
}

/** The `model:` block of a Hermes config.yaml — only the four flat keys we need, no YAML library. */
export function readHermesModel(file: string): { default?: string; provider?: string; base_url?: string; api_key?: string } | null {
  let text = '';
  try { text = fs.readFileSync(file, 'utf8'); } catch { return null; }
  const lines = text.split('\n');
  const start = lines.findIndex((l) => /^model:\s*$/.test(l));
  if (start < 0) {
    const flat = /^model:\s*["']?([^"'\n#]+?)["']?\s*$/m.exec(text);
    return flat ? { default: flat[1].trim() } : null;
  }
  const out: Record<string, string> = {};
  for (let i = start + 1; i < lines.length; i++) {
    const l = lines[i];
    if (!/^\s+\S/.test(l)) { if (l.trim() === '') continue; break; }
    const m = /^\s+([a-z_]+):\s*(.*?)\s*$/.exec(l);
    if (!m) continue;
    let v = m[2].replace(/\s+#.*$/, '');
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
    out[m[1]] = v;
  }
  return out;
}

/** One spelling per endpoint, so the same server found in three places is one provider. */
export function normalizeBase(u: string): string {
  try {
    const url = new URL(u.trim());
    if (['localhost', '0.0.0.0', '[::1]', '::1'].includes(url.hostname)) url.hostname = '127.0.0.1';
    return `${url.protocol}//${url.host.toLowerCase()}${url.pathname.replace(/\/+$/, '')}`;
  } catch { return u.trim().replace(/\/+$/, ''); }
}

const isLocalUrl = (u: string) => /^https?:\/\/(127\.\d+\.\d+\.\d+|localhost|0\.0\.0\.0|\[::1\])(:|\/|$)/.test(u);

/** Read the key a reference points at. Only ever called to write an agent's own config or to list models. */
export function resolveKey(ref: KeyRef | null, env: NodeJS.ProcessEnv = process.env): string {
  if (!ref) return '';
  try {
    if (ref.from === 'env') return env[ref.name] ?? '';
    if (ref.from === 'dotenv') return readDotenv(ref.path)[ref.name] ?? '';
    if (ref.from === 'yaml-model') return readHermesModel(ref.path)?.api_key ?? '';
    let v: any = readJson(ref.path);
    for (const k of ref.pointer) v = v?.[k];
    return typeof v === 'string' ? v : '';
  } catch { return ''; }
}

/** Where a reference points, in words a user can read (never the key). */
export function describeKeyRef(ref: KeyRef | null, home = os.homedir()): string {
  if (!ref) return 'no key needed';
  if (ref.from === 'env') return `the environment (${ref.name})`;
  if (ref.from === 'dotenv') return `${tilde(ref.path, home)} (${ref.name})`;
  if (ref.from === 'yaml-model') return `${tilde(ref.path, home)} (model.api_key)`;
  return `${tilde(ref.path, home)} (${ref.pointer.join('.')})`;
}

// ---------- the app's own store (read side; choose.ts writes) ----------

export function modelsDirFor(opts: DetectOptions = {}): string {
  const env = opts.env ?? process.env;
  if (opts.modelsDir) return opts.modelsDir;
  if (env.BILSKIRNIR_MODELS_DIR) return env.BILSKIRNIR_MODELS_DIR;
  return path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../data/models');
}

export interface AddedProvider { id: string; name: string; baseUrl: string; keyRef: KeyRef | null }
export interface Choice { providerId: string; baseUrl: string; model: string; keyRef: KeyRef | null; at: string }

export function readAdded(dir: string): AddedProvider[] {
  const v = readJson(path.join(dir, 'providers.json'));
  return Array.isArray(v) ? v.filter((p) => p && typeof p.id === 'string' && typeof p.baseUrl === 'string') : [];
}

export function readChoices(dir: string): Record<string, Choice> {
  const v = readJson(path.join(dir, 'choices.json'));
  return v && typeof v === 'object' && !Array.isArray(v) ? v : {};
}

// ---------- gathering candidates (no network) ----------

interface Candidate {
  id: string; name: string; baseUrl: string; keyRef: KeyRef | null; source: string;
  models?: string[]; added?: boolean;
}

function fromAdded(dir: string, home: string): Candidate[] {
  return readAdded(dir).map((p) => ({ id: p.id, name: p.name, baseUrl: p.baseUrl, keyRef: p.keyRef, source: `added here (${tilde(path.join(dir, 'providers.json'), home)})`, added: true }));
}

function fromPi(home: string): Candidate[] {
  const authFile = path.join(home, '.pi/agent/auth.json');
  const modelsFile = path.join(home, '.pi/agent/models.json');
  const auth = readJson(authFile) ?? {};
  const models = readJson(modelsFile)?.providers ?? {};
  const out: Candidate[] = [];
  const names = new Set([...Object.keys(auth), ...Object.keys(models)]);
  for (const name of names) {
    const m = models[name] ?? {};
    const preset = PRESETS.find((p) => p.id === name);
    const baseUrl = typeof m.baseUrl === 'string' ? m.baseUrl : preset?.baseUrl;
    if (!baseUrl) continue; // a provider pi knows by its own code (a subscription sign-in): not an endpoint we can reach
    const keyRef: KeyRef | null = typeof auth[name]?.key === 'string' && auth[name].key
      ? { from: 'json', path: authFile, pointer: [name, 'key'] }
      : typeof m.apiKey === 'string' && m.apiKey ? (/^[A-Z][A-Z0-9_]+$/.test(m.apiKey) ? { from: 'env', name: m.apiKey } : { from: 'json', path: modelsFile, pointer: ['providers', name, 'apiKey'] }) : null;
    out.push({
      id: name, name: preset?.name ?? name, baseUrl, keyRef,
      source: `pi (${tilde(keyRef?.from === 'json' && keyRef.path === authFile ? authFile : modelsFile, home)})`,
      models: Array.isArray(m.models) ? m.models.map((x: any) => x?.id).filter((x: unknown) => typeof x === 'string') : undefined,
    });
  }
  return out;
}

function fromOpenCode(home: string, env: NodeJS.ProcessEnv): Candidate[] {
  const cfgDir = env.XDG_CONFIG_HOME ? path.join(env.XDG_CONFIG_HOME, 'opencode') : path.join(home, '.config/opencode');
  const dataDir = env.XDG_DATA_HOME ? path.join(env.XDG_DATA_HOME, 'opencode') : path.join(home, '.local/share/opencode');
  const cfgFile = ['opencode.json', 'opencode.jsonc'].map((f) => path.join(cfgDir, f)).find((f) => fs.existsSync(f));
  const authFile = path.join(dataDir, 'auth.json');
  const cfg = cfgFile ? readJson(cfgFile) ?? {} : {};
  const auth = readJson(authFile) ?? {};
  const providers = cfg.provider && typeof cfg.provider === 'object' ? cfg.provider : {};
  const out: Candidate[] = [];
  for (const name of new Set([...Object.keys(providers), ...Object.keys(auth)])) {
    const p = providers[name] ?? {};
    const preset = PRESETS.find((x) => x.id === name);
    const baseUrl = p.options?.baseURL ?? preset?.baseUrl;
    if (typeof baseUrl !== 'string') continue;
    let keyRef: KeyRef | null = null;
    const k = p.options?.apiKey;
    if (typeof k === 'string' && k) {
      const envRef = /^\{env:([A-Za-z_][A-Za-z0-9_]*)\}$/.exec(k);
      keyRef = envRef ? { from: 'env', name: envRef[1] } : { from: 'json', path: cfgFile!, pointer: ['provider', name, 'options', 'apiKey'] };
    } else if (typeof auth[name]?.key === 'string' && auth[name].key) {
      keyRef = { from: 'json', path: authFile, pointer: [name, 'key'] };
    }
    out.push({
      id: name, name: typeof p.name === 'string' ? p.name : preset?.name ?? name, baseUrl, keyRef,
      source: `OpenCode (${tilde(keyRef?.from === 'json' ? keyRef.path : cfgFile ?? authFile, home)})`,
      models: p.models && typeof p.models === 'object' ? Object.keys(p.models) : undefined,
    });
  }
  return out;
}

function fromHermes(home: string, env: NodeJS.ProcessEnv): Candidate[] {
  const hhome = env.HERMES_HOME || path.join(home, '.hermes');
  const out: Candidate[] = [];
  const cfgFile = path.join(hhome, 'config.yaml');
  const m = readHermesModel(cfgFile);
  if (m?.base_url) {
    out.push({
      id: 'hermes', name: 'Hermes (its own model)', baseUrl: m.base_url,
      keyRef: m.api_key ? { from: 'yaml-model', path: cfgFile } : null,
      source: `Hermes (${tilde(cfgFile, home)})`, models: m.default ? [m.default] : undefined,
    });
  }
  const envFile = path.join(hhome, '.env');
  const dot = readDotenv(envFile);
  for (const [name, v] of Object.entries(dot)) {
    if (!isKey(v)) continue;
    const preset = PRESETS.find((p) => p.envKey === name) ?? PRESETS.find((p) => p.id === ENV_ALIASES[name]);
    if (!preset) continue;
    out.push({ id: preset.id, name: preset.name, baseUrl: preset.baseUrl, keyRef: { from: 'dotenv', path: envFile, name }, source: `Hermes (${tilde(envFile, home)})` });
  }
  return out;
}

function fromEnv(env: NodeJS.ProcessEnv): Candidate[] {
  const out: Candidate[] = [];
  for (const preset of PRESETS) {
    if (!preset.envKey) continue;
    const names = [preset.envKey, ...Object.entries(ENV_ALIASES).filter(([, id]) => id === preset.id).map(([n]) => n)];
    const name = names.find((n) => isKey(env[n]));
    if (!name) continue;
    // <ID>_BASE_URL moves a preset (OPENAI_BASE_URL is the common one); tests use it to point at a stub.
    const baseEnv = `${preset.envKey.replace(/_API_KEY$/, '')}_BASE_URL`;
    out.push({ id: preset.id, name: preset.name, baseUrl: env[baseEnv] || preset.baseUrl, keyRef: { from: 'env', name }, source: `the environment (${name})` });
  }
  return out;
}

/** Merge by endpoint. The first source to name a provider gives it its id; the first key found is kept. */
function merge(cands: Candidate[]): Map<string, Candidate & { sources: string[]; declared: Set<string> }> {
  const by = new Map<string, Candidate & { sources: string[]; declared: Set<string> }>();
  for (const c of cands) {
    const key = normalizeBase(c.baseUrl);
    const have = by.get(key);
    if (!have) {
      by.set(key, { ...c, baseUrl: c.baseUrl.replace(/\/+$/, ''), sources: [c.source], declared: new Set(c.models ?? []) });
      continue;
    }
    if (!have.sources.includes(c.source)) have.sources.push(c.source);
    if (!have.keyRef && c.keyRef) have.keyRef = c.keyRef;
    if (c.added) have.added = true;
    for (const m of c.models ?? []) have.declared.add(m);
  }
  return by;
}

// ---------- the network: probe local ports, list models ----------

async function getModels(baseUrl: string, key: string, timeoutMs: number): Promise<{ status: number; ids: string[] } | null> {
  const headers: Record<string, string> = {};
  if (key) {
    headers.Authorization = `Bearer ${key}`;
    if (/api\.anthropic\.com/.test(baseUrl)) { headers['x-api-key'] = key; headers['anthropic-version'] = '2023-06-01'; }
  }
  try {
    const r = await fetch(`${baseUrl.replace(/\/+$/, '')}/models`, { headers, signal: AbortSignal.timeout(timeoutMs) });
    if (!r.ok) return { status: r.status, ids: [] };
    const j: any = await r.json().catch(() => ({}));
    const list: any[] = Array.isArray(j?.data) ? j.data : Array.isArray(j?.models) ? j.models : [];
    const ids = list.map((m) => (typeof m === 'string' ? m : m?.id ?? m?.name)).filter((x): x is string => typeof x === 'string')
      .map((id) => id.replace(/^models\//, ''));
    return { status: r.status, ids };
  } catch { return null; }
}

async function probeLocal(ports: NonNullable<DetectOptions['localPorts']>, timeoutMs: number): Promise<Candidate[]> {
  const found = await Promise.all(ports.map(async (p) => {
    const baseUrl = `http://${p.host ?? '127.0.0.1'}:${p.port}/v1`;
    const r = await getModels(baseUrl, '', timeoutMs);
    if (!r) return null; // nothing answers: a clean skip
    const preset = PRESETS.find((x) => x.id === p.kind);
    return { id: p.kind, name: preset?.name ?? `${p.name} (this computer)`, baseUrl, keyRef: null, source: `a server answering on port ${p.port}` } as Candidate;
  }));
  return found.filter((x): x is Candidate => !!x);
}

// ---------- the allow-list (one door, never a second copy) ----------

/** Find bin/model/model-allow.sh: an override, else walk up from this module, else the pinned runtime. */
export function findAllowDoor(env: NodeJS.ProcessEnv = process.env): string | null {
  if (env.BILSKIRNIR_MODEL_ALLOW) return fs.existsSync(env.BILSKIRNIR_MODEL_ALLOW) ? env.BILSKIRNIR_MODEL_ALLOW : null;
  let dir = path.dirname(fileURLToPath(import.meta.url));
  for (let i = 0; i < 8; i++) {
    const p = path.join(dir, 'bin/model/model-allow.sh');
    if (fs.existsSync(p)) return p;
    const up = path.dirname(dir);
    if (up === dir) break;
    dir = up;
  }
  for (const r of [env.YMIR_RUNTIME_DIR, path.join(env.HOME ?? os.homedir(), 'ymir-runtime')]) {
    if (r && fs.existsSync(path.join(r, 'bin/model/model-allow.sh'))) return path.join(r, 'bin/model/model-allow.sh');
  }
  return null;
}

/** Where the operator's allow-list would live, by the same law allow.py reads (YMIR_SETTINGS_DIR, else <home>/config). */
function allowListPath(env: NodeJS.ProcessEnv, door: string | null): string {
  if (door) {
    const r = spawnSync('bash', [door, 'path'], { env, encoding: 'utf8', timeout: 10_000 });
    const p = (r.stdout ?? '').trim().split('\n').pop();
    if (r.status === 0 && p) return p;
  }
  const settings = env.YMIR_SETTINGS_DIR || path.join(env.YMIR_HOME || path.join(env.HOME ?? os.homedir(), 'Documents/ymirhome'), 'config');
  return path.join(settings, 'models-allowed.yaml');
}

const CLAUDE_HOSTS = /api\.anthropic\.com/;

/**
 * Judge every (provider, model) pair through `model-allow.sh filter`. With no list, everything found is
 * selectable. A list with no door to read it is a refusal (fail closed), said in words.
 */
export function judge(providers: FoundProvider[], env: NodeJS.ProcessEnv, doorOverride?: string | null): { policed: boolean; allowList: string | null } {
  const door = doorOverride === undefined ? findAllowDoor(env) : doorOverride;
  const list = allowListPath(env, door);
  const policed = fs.existsSync(list);
  if (!policed) {
    for (const p of providers) for (const m of p.models) m.allowed = true;
    return { policed: false, allowList: null };
  }
  if (!door) {
    for (const p of providers) for (const m of p.models) { m.allowed = false; m.reason = 'the allow-list door (bin/model/model-allow.sh) is missing'; }
    return { policed: true, allowList: list };
  }
  // Claude's models are named `claude/<id>` and judged under the claude harness, as the list writes them;
  // everything else is `<provider>/<model>`.
  const run = (harness: string, rows: [string, string][]) => {
    if (!rows.length) return new Set<string>();
    const body = `catalog[${rows.length}]{provider,model}:\n` + rows.map(([p, m]) => `  ${JSON.stringify(p)},${JSON.stringify(m)}`).join('\n') + '\n';
    const r = spawnSync('bash', [door, 'filter', '--harness', harness], { env, input: body, encoding: 'utf8', timeout: 20_000 });
    const ok = new Set<string>();
    if (r.status !== 0) return ok;
    for (const line of (r.stdout ?? '').split('\n')) {
      if (!line.startsWith('  ')) continue;
      try { const [p, m] = JSON.parse('[' + line.trim() + ']'); ok.add(`${p}/${m}`); } catch { /* not a row */ }
    }
    return ok;
  };
  const plain: [string, string][] = [];
  const claude: [string, string][] = [];
  for (const p of providers) for (const m of p.models) (CLAUDE_HOSTS.test(p.baseUrl) ? claude : plain).push([CLAUDE_HOSTS.test(p.baseUrl) ? 'claude' : p.id, m.id]);
  const okPlain = run('hermes', plain);
  const okClaude = run('claude', claude);
  for (const p of providers) {
    const isClaude = CLAUDE_HOSTS.test(p.baseUrl);
    for (const m of p.models) {
      m.allowed = (isClaude ? okClaude : okPlain).has(`${isClaude ? 'claude' : p.id}/${m.id}`);
      if (!m.allowed) m.reason = 'not allowed in this fleet';
      else delete m.reason;
    }
  }
  return { policed: true, allowList: list };
}

// ---------- the whole look ----------

export async function detect(opts: DetectOptions = {}): Promise<Detection> {
  const env = opts.env ?? process.env;
  const home = opts.home ?? env.HOME ?? os.homedir();
  const timeoutMs = opts.timeoutMs ?? 4000;
  const dir = modelsDirFor(opts);

  // The order is the order of trust in a provider's NAME: the app's own and pi's names are what the
  // operator's allow-list writes; a bare port answer is named last.
  const local = await probeLocal(opts.localPorts ?? localPortsFor(env), Math.min(timeoutMs, 1500));
  const merged = merge([...fromAdded(dir, home), ...fromPi(home), ...fromOpenCode(home, env), ...fromHermes(home, env), ...fromEnv(env), ...local]);

  const providers = await Promise.all([...merged.values()].map(async (c): Promise<FoundProvider> => {
    const isLocal = isLocalUrl(c.baseUrl);
    const base: FoundProvider = { id: c.id, name: c.name, baseUrl: c.baseUrl, local: isLocal, keyRef: c.keyRef, sources: c.sources, status: 'from-config', models: [], added: c.added || undefined };
    const declared = [...c.declared];
    if (opts.offline && !isLocal) return { ...base, models: declared.map((id) => ({ id, allowed: true })) };
    const r = await getModels(c.baseUrl, resolveKey(c.keyRef, env), isLocal ? Math.min(timeoutMs, 2500) : timeoutMs);
    if (r && r.ids.length) return { ...base, status: 'ok', models: r.ids.map((id) => ({ id, allowed: true })) };
    if (r && (r.status === 401 || r.status === 403)) return { ...base, status: declared.length ? 'from-config' : 'needs-key', note: c.keyRef ? 'the key was refused' : 'answers, but wants a key', models: declared.map((id) => ({ id, allowed: true })) };
    return { ...base, status: declared.length ? 'from-config' : 'unreachable', note: r ? `answered ${r.status}` : 'not answering', models: declared.map((id) => ({ id, allowed: true })) };
  }));

  // The ones that answer first, the free ones before the paid ones.
  const rank = (p: FoundProvider) => (p.status === 'ok' ? 0 : p.status === 'from-config' ? 1 : 2) * 10 + (p.local ? 0 : 1);
  providers.sort((a, b) => rank(a) - rank(b));
  const verdict = judge(providers, env, opts.allowDoor);
  return { at: new Date().toISOString(), ...verdict, providers };
}

/** Models that cannot hold a conversation: never a fresh install's first pick. */
const NOT_CHAT = /embed|rerank|whisper|tts|speech|moderation|dall-e|image|vision-only/i;

/** The first model a user may choose: what a fresh install starts on. */
export function firstAllowed(d: Detection): { provider: FoundProvider; model: string } | null {
  for (const p of d.providers) {
    if (p.status === 'unreachable' || p.status === 'needs-key') continue;
    const m = p.models.find((x) => x.allowed && !NOT_CHAT.test(x.id));
    if (m) return { provider: p, model: m.id };
  }
  return null;
}

/** A detection safe to hand to a browser: the key references are reduced to words. */
export function forBrowser(d: Detection, home = os.homedir()) {
  return {
    ...d,
    providers: d.providers.map(({ keyRef, ...p }) => ({ ...p, key: describeKeyRef(keyRef, home), hasKey: !!keyRef })),
  };
}

// ---------- the Hermes model block (setup.sh and the Models screen write the same thing) ----------

const q = (s: string) => JSON.stringify(s);

export function modelBlock(model: string, baseUrl: string, key: string): string {
  return `model:\n  default: ${q(model)}\n  provider: "custom"\n  base_url: ${q(baseUrl)}\n` + (key ? `  api_key: ${q(key)}\n` : '');
}

// ---------- command line (setup.sh) ----------
//
//   node server/src/models/detect.ts --json                      the detection, keys as words only
//   node server/src/models/detect.ts --model-block --agent primary --config <engine>/config.yaml
//        [--model M] [--base-url U]                              the model block for that agent (stdout),
//                                                               and one line of why on stderr

async function main(argv: string[]) {
  const arg = (n: string) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : undefined; };
  if (argv.includes('--json')) {
    // written synchronously: a pipe takes 64 KiB at a time, and process.exit() right after an async write cut the
    // answer off mid-string for any program reading it (Rödd's Mind got nothing, plan 275, 2026-11-12)
    fs.writeSync(1, JSON.stringify(forBrowser(await detect()), null, 2) + '\n');
    return 0;
  }
  if (argv.includes('--model-block')) {
    const agent = arg('--agent') ?? 'primary';
    const cfg = arg('--config');
    const wantModel = arg('--model');
    const wantBase = arg('--base-url');
    const env = process.env;
    const say = (s: string) => process.stderr.write(s + '\n');
    // 1 · the environment names it (setup's documented override)
    if (wantModel) {
      const d = await detect({ offline: true });
      const byBase = wantBase ? d.providers.find((p) => normalizeBase(p.baseUrl) === normalizeBase(wantBase)) : undefined;
      const byModel = d.providers.find((p) => p.models.some((m) => m.id === wantModel));
      const p = byBase ?? byModel;
      const baseUrl = wantBase ?? p?.baseUrl ?? 'http://127.0.0.1:8080/v1';
      process.stdout.write(modelBlock(wantModel, baseUrl, resolveKey(p?.keyRef ?? null, env)));
      say(`model ${wantModel} at ${baseUrl} (from BILSKIRNIR_MODEL)${p?.keyRef ? `; key from ${describeKeyRef(p.keyRef)}` : ''}`);
      return 0;
    }
    // 2 · the Models screen chose it
    const choice = readChoices(modelsDirFor())[agent];
    if (choice?.model && choice.baseUrl) {
      process.stdout.write(modelBlock(choice.model, choice.baseUrl, resolveKey(choice.keyRef, env)));
      say(`model ${choice.providerId}/${choice.model} (chosen on the Models screen)`);
      return 0;
    }
    // 3 · the agent already has one: keep it (setup is idempotent; it never moves a working agent)
    const have = cfg ? readHermesModel(cfg) : null;
    if (have?.default && have.base_url) {
      process.stdout.write(modelBlock(have.default, have.base_url, have.api_key ?? ''));
      say(`model ${have.default} (kept from the agent's own config)`);
      return 0;
    }
    // 4 · a fresh install: the first allowed model the detector finds
    const d = await detect({ timeoutMs: 4000 });
    const first = firstAllowed(d);
    if (!first) {
      say('no model found — open Settings › Models in the hall, or set BILSKIRNIR_MODEL');
      return 3;
    }
    process.stdout.write(modelBlock(first.model, first.provider.baseUrl, resolveKey(first.provider.keyRef, env)));
    say(`model ${first.provider.id}/${first.model} (found: ${first.provider.sources[0]})`);
    return 0;
  }
  process.stderr.write('usage: detect.ts --json | --model-block --agent <key> [--config <file>] [--model M] [--base-url U]\n');
  return 2;
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main(process.argv.slice(2)).then((c) => process.exit(c), (e) => { process.stderr.write(String(e?.message ?? e) + '\n'); process.exit(1); });
}
