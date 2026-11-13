/**
 * The model door's hands: apply a choice to one agent, and add a provider the detector did not find.
 *
 * Choosing a model rewrites ONLY the `model:` block of that agent's own Hermes config.yaml (every other
 * key — MCP doors, toolsets, hooks — is left as it is), records the choice, and the caller reloads the
 * gateway. Each agent has its own model.
 *
 * Keys a user pastes are written to the user's own home secrets (`$YMIR_HOME/hodd/secrets/`, chmod 600)
 * where that home exists, else to the app's ignored `data/models/` (chmod 600) — never to the repo, and
 * never echoed back: the answer carries a reference, not the key.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import YAML from 'yaml';
import {
  type AddedProvider, type Choice, type DetectOptions, type KeyRef, type FoundProvider,
  detect, modelBlock, modelsDirFor, normalizeBase, PRESETS, readAdded, readChoices, resolveKey, ymirHome,
} from './detect.js';

function writePrivate(file: string, content: string) {
  fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
  fs.writeFileSync(file, content, { mode: 0o600 });
  fs.chmodSync(file, 0o600);
}

const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 40) || 'provider';

/** Where a pasted key is kept: the user's home secrets when the home exists, else the app's ignored data/. */
export function keyHome(env: NodeJS.ProcessEnv, modelsDir: string): { file: string; where: string } {
  const home = ymirHome(env);
  const secrets = path.join(home, 'hodd', 'secrets');
  if (fs.existsSync(path.join(home, 'hodd'))) return { file: path.join(secrets, 'bilskirnir-providers.env'), where: 'your home secrets' };
  return { file: path.join(modelsDir, 'keys.env'), where: "the app's private data folder" };
}

function setDotenv(file: string, name: string, value: string) {
  let lines: string[] = [];
  try { lines = fs.readFileSync(file, 'utf8').split('\n').filter(Boolean); } catch { /* new file */ }
  lines = lines.filter((l) => !l.startsWith(`${name}=`));
  lines.push(`${name}=${value}`);
  writePrivate(file, lines.join('\n') + '\n');
}

export interface AddInput { preset?: string; name?: string; baseUrl?: string; key?: string }

/** Add (or update) a provider: a preset plus a key, or just a base URL. Returns the provider found, for the screen. */
export async function addProvider(input: AddInput, opts: DetectOptions = {}): Promise<{ provider: AddedProvider; keyStoredIn: string | null }> {
  const env = opts.env ?? process.env;
  const dir = modelsDirFor(opts);
  const preset = input.preset ? PRESETS.find((p) => p.id === input.preset) : undefined;
  if (input.preset && !preset) throw new Error('unknown provider preset');
  const baseUrl = (input.baseUrl?.trim() || preset?.baseUrl || '').replace(/\/+$/, '');
  if (!/^https?:\/\/[^\s]+$/.test(baseUrl)) throw new Error('Give the provider’s base URL, like https://api.example.com/v1');
  const key = (input.key ?? '').trim();
  if (key.length > 4096 || /[\r\n]/.test(key)) throw new Error('That does not look like a key.');
  if (preset?.needsKey && !key) {
    // A key already on this machine for that provider (environment, pi, …) is enough; the detector will say so.
    const d = await detect({ ...opts, offline: true });
    const have = d.providers.find((p) => normalizeBase(p.baseUrl) === normalizeBase(baseUrl) && p.keyRef);
    if (!have) throw new Error(`${preset.name} needs a key. Paste one${preset.keyHint ? ` (get it at ${preset.keyHint})` : ''}.`);
  }
  const id = preset?.id ?? slug(input.name || new URL(baseUrl).hostname);
  let keyRef: KeyRef | null = null;
  let keyStoredIn: string | null = null;
  if (key) {
    const { file, where } = keyHome(env, dir);
    const envName = `BILSKIRNIR_KEY_${id.toUpperCase().replace(/[^A-Z0-9]/g, '_')}`;
    setDotenv(file, envName, key);
    keyRef = { from: 'dotenv', path: file, name: envName };
    keyStoredIn = where;
  }
  const rows = readAdded(dir).filter((p) => p.id !== id && normalizeBase(p.baseUrl) !== normalizeBase(baseUrl));
  const existing = readAdded(dir).find((p) => p.id === id);
  const provider: AddedProvider = { id, name: input.name?.trim() || preset?.name || id, baseUrl, keyRef: keyRef ?? existing?.keyRef ?? null };
  writePrivate(path.join(dir, 'providers.json'), JSON.stringify([...rows, provider], null, 2) + '\n');
  return { provider, keyStoredIn };
}

export function removeProvider(id: string, opts: DetectOptions = {}) {
  const dir = modelsDirFor(opts);
  writePrivate(path.join(dir, 'providers.json'), JSON.stringify(readAdded(dir).filter((p) => p.id !== id), null, 2) + '\n');
}

/**
 * Replace the `model:` block of a Hermes config.yaml; every other key survives as written. The block is
 * the same text setup.sh renders (modelBlock), so `setup.sh --check` still finds the home current.
 */
export function patchHermesModel(configFile: string, model: string, baseUrl: string, key: string) {
  let cfg: any = {};
  try { cfg = YAML.parse(fs.readFileSync(configFile, 'utf8')) ?? {}; } catch { /* a new home */ }
  delete cfg.model;
  const rest = Object.keys(cfg).length ? YAML.stringify(cfg) : '';
  writePrivate(configFile, modelBlock(model, baseUrl, key) + rest);
}

export interface ChooseInput { providerId: string; model: string }
export interface ChooseResult { providerId: string; model: string; baseUrl: string; keyFrom: string }

/**
 * Choose `model` of `providerId` for the agent whose Hermes home is `home`. Refuses a model the
 * allow-list does not allow (the same verdict the screen showed), and a provider that has no key.
 */
export async function choose(agentKey: string, home: string, input: ChooseInput, opts: DetectOptions = {}): Promise<ChooseResult> {
  const env = opts.env ?? process.env;
  const d = await detect(opts);
  const p: FoundProvider | undefined = d.providers.find((x) => x.id === input.providerId);
  if (!p) throw new Error('That provider is not among the ones found. Add it first.');
  const m = p.models.find((x) => x.id === input.model);
  if (!m) throw new Error('That model is not listed by this provider.');
  if (!m.allowed) throw new Error('That model is not allowed in this fleet.');
  const key = resolveKey(p.keyRef, env);
  if (!p.local && !key) throw new Error(`${p.name} needs a key. Add one on the Models screen.`);
  patchHermesModel(path.join(home, 'config.yaml'), m.id, p.baseUrl, key);
  const dir = modelsDirFor(opts);
  const choices = readChoices(dir);
  const row: Choice = { providerId: p.id, baseUrl: p.baseUrl, model: m.id, keyRef: p.keyRef, at: new Date().toISOString() };
  choices[agentKey] = row;
  writePrivate(path.join(dir, 'choices.json'), JSON.stringify(choices, null, 2) + '\n');
  return { providerId: p.id, model: m.id, baseUrl: p.baseUrl, keyFrom: p.sources[0] ?? '' };
}

export { modelBlock };

// ---------- the command line: Rödd's Mind and any other Ymir app add a provider through this one door ----------
//   node server/src/models/choose.ts --presets                          every provider that can be added (no keys)
//   node server/src/models/choose.ts --add --preset <id> --key-stdin    add one; the key is read from standard input,
//                                                                       never an argument, so no process list shows it
//   node server/src/models/choose.ts --add --name N --base-url U [--key-stdin]   any other OpenAI-compatible endpoint
// The key is written to the user's private home ($YMIR_HOME/hodd/secrets/bilskirnir-providers.env, 0600), never to
// this public repository, and the answer carries where it went, never the key (plan 275, 2026-11-12).
import { pathToFileURL as _toUrl } from 'node:url';
if (process.argv[1] && import.meta.url === _toUrl(path.resolve(process.argv[1])).href) {
  const argv = process.argv.slice(2);
  const arg = (n: string) => { const i = argv.indexOf(n); return i >= 0 ? argv[i + 1] : undefined; };
  const say = (o: unknown, code: number) => { fs.writeSync(1, JSON.stringify(o) + '\n'); process.exit(code); };
  if (argv.includes('--presets')) {
    say({ presets: PRESETS.map(({ id, name, baseUrl, needsKey, local, keyHint, envKey }) => ({ id, name, baseUrl, needsKey, local: !!local, keyHint, envKey })) }, 0);
  } else if (argv.includes('--add')) {
    const key = argv.includes('--key-stdin') ? fs.readFileSync(0, 'utf8').trim() : '';
    addProvider({ preset: arg('--preset'), name: arg('--name'), baseUrl: arg('--base-url'), key })
      .then((r) => say({ ok: true, provider: { id: r.provider.id, name: r.provider.name, baseUrl: r.provider.baseUrl }, keyStoredIn: r.keyStoredIn }, 0))
      .catch((e) => say({ ok: false, detail: String(e?.message ?? e) }, 1));
  } else {
    fs.writeSync(2, 'usage: choose.ts --presets | --add --preset <id> --key-stdin | --add --name N --base-url U [--key-stdin]\n');
    process.exit(2);
  }
}
