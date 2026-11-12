// The model door, part by part — stub servers, a temp HOME, no network, no real keys.
//
//   cd apps/bilskirnir && node_modules/.bin/tsx tests/model-door.mts
//
// 1. a temp HOME with pi, OpenCode and Hermes configs + env keys → every provider is found, once each
// 2. a stub local server (Ollama's shape) answering /v1/models is found; a closed port is a clean skip
// 3. a key is NEVER in the detection (nor in the browser view); only a reference to where it was found
// 4. with no allow-list, everything found is selectable
// 5. with an allow-list (the real bin/model/model-allow.sh), only allowed models are selectable
// 6. choosing a model rewrites only the model block of that agent's config.yaml and records the choice
// 7. choosing a refused model, or a keyless remote, is refused
// 8. a pasted key goes to the home's secrets (0600), never to the repo, and never comes back
// 9. --model-block: BILSKIRNIR_MODEL wins; a choice wins over the agent's own; a fresh install takes the first allowed
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import type { AddressInfo } from 'node:net';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { describeKeyRef, detect, firstAllowed, forBrowser, readChoices, resolveKey } from '../server/src/models/detect.js';
import { addProvider, choose, patchHermesModel } from '../server/src/models/choose.js';

let failed = 0;
const ok = (name: string, cond: boolean, detail = '') => {
  console.log(`${cond ? 'ok  ' : 'FAIL'} ${name}${detail ? ` — ${detail}` : ''}`);
  if (!cond) failed++;
};

const here = path.dirname(fileURLToPath(import.meta.url));
const door = path.resolve(here, '../../../bin/model/model-allow.sh');

const SECRET = 'sk-test-SECRET-must-never-leak-123456';
const PI_SECRET = 'pi-secret-key-abcdef';

function stub(models: string[], wantKey?: string): Promise<http.Server> {
  return new Promise((resolve) => {
    const s = http.createServer((req, res) => {
      if (req.url === '/v1/models') {
        if (wantKey && req.headers.authorization !== `Bearer ${wantKey}`) { res.writeHead(401).end('{}'); return; }
        res.setHeader('content-type', 'application/json');
        res.end(JSON.stringify({ data: models.map((id) => ({ id })) }));
      } else res.writeHead(404).end();
    }).listen(0, '127.0.0.1', () => resolve(s));
  });
}
const portOf = (s: http.Server) => (s.address() as AddressInfo).port;

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'model-door-'));
const home = path.join(tmp, 'home');
const ymirHome = path.join(tmp, 'ymirhome');
const modelsDir = path.join(tmp, 'data-models');
const engine = path.join(tmp, 'engine');
for (const d of [home, path.join(ymirHome, 'hodd', 'secrets'), path.join(ymirHome, 'config'), engine]) fs.mkdirSync(d, { recursive: true });

const ollama = await stub(['llama3.2:3b', 'qwen2.5-coder:7b']);
const piRail = await stub(['rail-small', 'rail-big'], PI_SECRET);
const dead = await stub([]); const deadPort = portOf(dead); await new Promise((r) => dead.close(r));
const dead2 = await stub([]); const deadPort2 = portOf(dead2); await new Promise((r) => dead2.close(r));

// pi: one provider with a key, pointing at the keyed stub
fs.mkdirSync(path.join(home, '.pi/agent'), { recursive: true });
fs.writeFileSync(path.join(home, '.pi/agent/auth.json'), JSON.stringify({ pirail: { type: 'api_key', key: PI_SECRET } }));
fs.writeFileSync(path.join(home, '.pi/agent/models.json'), JSON.stringify({ providers: { pirail: { baseUrl: `http://127.0.0.1:${portOf(piRail)}/v1`, api: 'openai-completions', models: [{ id: 'rail-small' }] } } }));
// OpenCode: the same endpoint again (must merge) and a second one, key by {env:...}
fs.mkdirSync(path.join(home, '.config/opencode'), { recursive: true });
fs.writeFileSync(path.join(home, '.config/opencode/opencode.json'), JSON.stringify({ provider: {
  pirail2: { name: 'The same rail', options: { baseURL: `http://localhost:${portOf(piRail)}/v1`, apiKey: '{env:RAIL_KEY}' } },
  declared: { name: 'Declared only', options: { baseURL: `http://127.0.0.1:${deadPort}/v1` }, models: { 'declared-model': {} } },
} }));
// Hermes: its own model block
fs.mkdirSync(path.join(home, '.hermes'), { recursive: true });
fs.writeFileSync(path.join(home, '.hermes/config.yaml'), `model:\n  default: "hermes-own"\n  provider: "custom"\n  base_url: "http://127.0.0.1:${deadPort2}/v1"\n`);

const env: NodeJS.ProcessEnv = { HOME: home, PATH: process.env.PATH, YMIR_HOME: ymirHome, RAIL_KEY: PI_SECRET, OPENAI_API_KEY: SECRET, XAI_API_KEY: 'unset', OPENAI_BASE_URL: `http://127.0.0.1:${portOf(piRail)}/v1/x` };
const baseOpts = { env, home, modelsDir, localPorts: [{ kind: 'ollama', name: 'Ollama', port: portOf(ollama) }, { kind: 'vllm', name: 'vLLM', port: deadPort }], timeoutMs: 2000, allowDoor: door };

// 1–4 · no allow-list: everything found, selectable
let d = await detect(baseOpts);
const byId = (id: string) => d.providers.find((p) => p.id === id);
ok('pi provider found with its models', byId('pirail')?.models.map((m) => m.id).sort().join() === 'rail-big,rail-small', byId('pirail')?.status);
ok('the same endpoint in pi and OpenCode is one provider', d.providers.filter((p) => p.baseUrl.includes(`:${portOf(piRail)}/v1`) && !p.baseUrl.endsWith('/x')).length === 1);
ok('both sources are named', (byId('pirail')?.sources.length ?? 0) >= 2, byId('pirail')?.sources.join(' + '));
ok('a local server answering /v1/models is found', byId('ollama')?.models.length === 2 && byId('ollama')?.local === true, byId('ollama')?.status);
ok('a closed local port is a clean skip', !byId('vllm'));
ok('a declared-only provider that does not answer keeps its declared model', byId('declared')?.status === 'from-config' && byId('declared')?.models[0]?.id === 'declared-model');
ok('Hermes own model is found', byId('hermes')?.models[0]?.id === 'hermes-own');
ok('a placeholder (XAI_API_KEY=unset) is not a key', !byId('xai'));
ok('an env key makes its provider appear', !!byId('openai') && byId('openai')?.keyRef?.from === 'env');
ok('no allow-list: unpoliced, every model selectable', d.policed === false && d.providers.every((p) => p.models.every((m) => m.allowed)));
const wire = JSON.stringify(forBrowser(d, home)) + JSON.stringify(d.providers.map(({ keyRef, ...p }) => p));
ok('no key anywhere in what the browser gets', !wire.includes(SECRET) && !wire.includes(PI_SECRET));
ok('a key reference names where, in words', /auth\.json/.test(describeKeyRef(byId('pirail')!.keyRef, home)));
ok('the reference resolves to the key when a config is written', resolveKey(byId('pirail')!.keyRef, env) === PI_SECRET);

// 5 · with an allow-list, through the real door
fs.writeFileSync(path.join(ymirHome, 'config/models-allowed.yaml'), 'version: 1\nallow:\n  - ollama/llama3.2:3b\n  - pirail/rail-small\ngrants: []\n');
d = await detect(baseOpts);
const allowed = (id: string) => byId(id)!.models.filter((m) => m.allowed).map((m) => m.id).sort().join();
ok('a list exists: policed', d.policed === true, d.allowList ?? '');
ok('only the models the list allows are selectable', allowed('ollama') === 'llama3.2:3b' && allowed('pirail') === 'rail-small');
ok('a refused model says why', byId('ollama')!.models.find((m) => m.id === 'qwen2.5-coder:7b')?.reason === 'not allowed in this fleet');
ok('a provider the list does not name is wholly refused', allowed('hermes') === '' && allowed('openai') === '');
ok('the first allowed model leads a fresh install', (() => { const f = firstAllowed(d); return !!f && f.model === 'llama3.2:3b' || f?.model === 'rail-small'; })());

// 6–7 · choosing
fs.writeFileSync(path.join(engine, 'config.yaml'), 'mcp_servers:\n  ymir:\n    command: python3\nhooks:\n  on_session_start: []\nmodel:\n  default: old\n');
const r = await choose('primary', engine, { providerId: 'pirail', model: 'rail-small' }, baseOpts);
const cfgText = fs.readFileSync(path.join(engine, 'config.yaml'), 'utf8');
ok('choosing writes the model block', /default: "rail-small"/.test(cfgText) && /provider: "custom"/.test(cfgText) && cfgText.includes(`:${portOf(piRail)}/v1`));
ok('the block is the one setup.sh renders (quoted), so --check stays current', /^model:\n  default: "rail-small"\n  provider: "custom"/.test(cfgText));
ok('the agent’s other keys survive', /mcp_servers:/.test(cfgText) && /on_session_start/.test(cfgText));
ok('the key is written into that agent’s own config (0600)', cfgText.includes(PI_SECRET) && (fs.statSync(path.join(engine, 'config.yaml')).mode & 0o777) === 0o600);
ok('the choice is recorded by reference only', readChoices(modelsDir).primary?.model === 'rail-small' && !fs.readFileSync(path.join(modelsDir, 'choices.json'), 'utf8').includes(PI_SECRET));
ok('the answer carries no key', !JSON.stringify(r).includes(PI_SECRET));
const refused = await choose('primary', engine, { providerId: 'ollama', model: 'qwen2.5-coder:7b' }, baseOpts).then(() => 'chosen', (e) => String(e.message));
ok('a refused model cannot be chosen', /not allowed in this fleet/.test(refused), refused);
fs.rmSync(path.join(ymirHome, 'config/models-allowed.yaml'));
const unlisted = await choose('primary', engine, { providerId: 'pirail', model: 'no-such-model' }, baseOpts).then(() => 'chosen', (e) => String(e.message));
ok('a model the provider does not list is refused', /not listed/.test(unlisted), unlisted);
const unknown = await choose('primary', engine, { providerId: 'nobody', model: 'x' }, baseOpts).then(() => 'chosen', (e) => String(e.message));
ok('an unknown provider is refused', /not among the ones found/.test(unknown), unknown);

// 8 · a pasted key
const added = await addProvider({ preset: 'groq', key: 'gsk-pasted-secret-xyz' }, baseOpts);
const secretsFile = path.join(ymirHome, 'hodd/secrets/bilskirnir-providers.env');
ok('a pasted key lands in the home secrets', fs.existsSync(secretsFile) && fs.readFileSync(secretsFile, 'utf8').includes('gsk-pasted-secret-xyz'), added.keyStoredIn ?? '');
ok('…chmod 600', (fs.statSync(secretsFile).mode & 0o777) === 0o600);
ok('the added provider holds a reference, not the key', !fs.readFileSync(path.join(modelsDir, 'providers.json'), 'utf8').includes('gsk-pasted-secret-xyz'));
ok('and the answer does not echo it', !JSON.stringify(added).includes('gsk-pasted-secret-xyz'));
const needKey = await addProvider({ preset: 'openrouter' }, { ...baseOpts, env: { ...env, OPENAI_API_KEY: '' } }).then(() => 'added', (e) => String(e.message));
ok('a preset that needs a key asks for one', /needs a key/.test(needKey), needKey);
const urlOnly = await addProvider({ name: 'My server', baseUrl: `http://127.0.0.1:${portOf(ollama)}/v1/` }, baseOpts).catch((e) => ({ error: e.message }));
ok('a bare base URL is enough for a keyless server', 'provider' in urlOnly && urlOnly.provider.id === 'my-server');
ok('a bad URL is refused', await addProvider({ baseUrl: 'not a url' }, baseOpts).then(() => false, () => true));

// 9 · the command line setup.sh uses
fs.rmSync(path.join(modelsDir, 'providers.json'), { force: true }); // the added ones merged into the stub's endpoint and took its name
// async, not spawnSync: the stub servers live in this process and must keep answering while the CLI runs
const cli = (args: string[], extra: Record<string, string> = {}) => new Promise<{ status: number | null; stdout: string; stderr: string }>((resolve) => {
  const p = spawn(path.resolve(here, '../node_modules/.bin/tsx'), [path.resolve(here, '../server/src/models/detect.ts'), ...args], { env: { ...env, BILSKIRNIR_MODELS_DIR: modelsDir, BILSKIRNIR_MODEL_ALLOW: door, BILSKIRNIR_LOCAL_PORTS: `ollama:${portOf(ollama)},vllm:${deadPort}`, ...extra } });
  let stdout = '', stderr = '';
  p.stdout.on('data', (d) => (stdout += d)); p.stderr.on('data', (d) => (stderr += d));
  p.on('close', (status) => resolve({ status, stdout, stderr: stderr.split('\n').filter((l) => !/Deprecat|trace-deprecation/.test(l)).join('\n') }));
});
const forced = await cli(['--model-block', '--agent', 'primary', '--config', path.join(tmp, 'none.yaml'), '--model', 'rail-big', '--base-url', `http://127.0.0.1:${portOf(piRail)}/v1`]);
ok('BILSKIRNIR_MODEL still wins, and borrows the found key', forced.status === 0 && /default: "rail-big"/.test(forced.stdout) && forced.stdout.includes(PI_SECRET), forced.stderr.trim());
const chosen = await cli(['--model-block', '--agent', 'primary', '--config', path.join(tmp, 'none.yaml')]);
ok('the Models-screen choice comes next', chosen.status === 0 && /default: "rail-small"/.test(chosen.stdout), chosen.stderr.trim());
fs.rmSync(path.join(modelsDir, 'choices.json'));
fs.writeFileSync(path.join(tmp, 'have.yaml'), 'model:\n  default: "kept-model"\n  provider: "custom"\n  base_url: "http://127.0.0.1:1/v1"\n');
const kept = await cli(['--model-block', '--agent', 'primary', '--config', path.join(tmp, 'have.yaml')]);
ok('an agent that already has a model keeps it', /default: "kept-model"/.test(kept.stdout), kept.stderr.trim());
const fresh = await cli(['--model-block', '--agent', 'primary', '--config', path.join(tmp, 'absent.yaml')]);
ok('a fresh install takes the first allowed model found', fresh.status === 0 && /default: "/.test(fresh.stdout), fresh.stderr.trim());
fs.writeFileSync(path.join(ymirHome, 'config/models-allowed.yaml'), 'version: 1\nallow:\n  - ollama/qwen2.5-coder:7b\ngrants: []\n');
const policed = await cli(['--model-block', '--agent', 'primary', '--config', path.join(tmp, 'absent.yaml')]);
ok('…and under a list, only an allowed one', /default: "qwen2\.5-coder:7b"/.test(policed.stdout), policed.stderr.trim());
const none = await cli(['--model-block', '--agent', 'primary', '--config', path.join(tmp, 'absent.yaml')], { HOME: path.join(tmp, 'empty'), OPENAI_API_KEY: '', RAIL_KEY: '', BILSKIRNIR_LOCAL_PORTS: `vllm:${deadPort}` });
ok('nothing found is said in words, exit 3', none.status === 3 && /no model found/.test(none.stderr), none.stderr.trim());

patchHermesModel(path.join(tmp, 'p.yaml'), 'm', 'http://x/v1', '');
ok('patchHermesModel makes a new home’s config', /default: "m"/.test(fs.readFileSync(path.join(tmp, "p.yaml"), "utf8")));

ollama.close(); piRail.close(); fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? `\n${failed} FAILED` : '\nall passed');
process.exit(failed ? 1 : 0);
