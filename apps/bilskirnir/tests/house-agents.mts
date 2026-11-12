// Every agent made in Bilskirnir is a house agent from birth — no browser, no running hall, no model.
//
//   cd apps/bilskirnir && npx tsx tests/house-agents.mts
//
// A throwaway home (seats.yaml, operator.yaml), a throwaway database and engines folder; the real ones are never touched.
//  1. a new bot's rendered config carries the house doors (ymir, well, skuld, bolthorn, house), the house toolsets,
//     and keeps its own `hq` door
//  2. its soul names its own name and role, and the house/operator come from the home — never a hard-coded name
//  3. a re-start is idempotent (config and soul byte-identical), and the user's own soul lines are kept
//  4. an older bot (stock soul, hq-only config) is brought up to date
//  5. the primary's renderer (house.py, as setup.sh calls it) is the same one the bots use
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'house-agents-'));
const home = path.join(tmp, 'home');
fs.mkdirSync(path.join(home, 'hodd', 'identity'), { recursive: true });
fs.writeFileSync(path.join(home, 'hodd', 'identity', 'seats.yaml'), 'fleet:\n  house: Testhouse\n  name: the test fleet\n  operator: Allfather Tester\n');
fs.writeFileSync(path.join(home, 'hodd', 'identity', 'operator.yaml'), 'allfather:\n  display: Allfather Tester\n');
process.env.YMIR_HOME = home;
process.env.YMIR_HOST = 'testhost';
process.env.YMIR_RUNTIME_DIR = path.join(tmp, 'no-runtime');
process.env.BILSKIRNIR_SESSION_HOOK = path.join(tmp, 'no-hook');
process.env.DB_PATH = path.join(tmp, 'test.db');
process.env.ENGINES_DIR = path.join(tmp, 'engines');
process.env.BILSKIRNIR_DESK = 'orgo'; // no desk in this test
process.env.SESSION_SECRET = 'test';
process.env.COMPOSIO_API_KEY ??= 'unset';
process.env.ORGO_API_KEY ??= 'unset';

let failed = 0;
const ok = (name: string, cond: boolean, detail = '') => { console.log(`${cond ? 'ok  ' : 'FAIL'} ${name}${detail ? ` — ${detail}` : ''}`); if (!cond) failed++; };

const { db } = await import('../server/src/db.js');
const { writeHome } = await import('../server/src/engine.js');
const YAML = (await import('yaml')).default;
const here = import.meta.dirname;

db.prepare("INSERT INTO users(id,email,name,created_at) VALUES ('u1','a@b.c','Tester',1)").run();
const mk = (id: string, name: string, label: string, description: string) =>
  db.prepare("INSERT INTO bots(id,user_id,name,label,description,engine,engine_port,created_at,updated_at) VALUES (?,?,?,?,?,'managed',?,1,1)").run(id, 'u1', name, label, description, 8700 + id.length);
mk('bot_new', 'Scout', 'Market researcher', 'Looks into markets.');

const file = (id: string, f: string) => path.join(process.env.ENGINES_DIR!, id, f);
const cfgOf = (id: string) => YAML.parse(fs.readFileSync(file(id, 'config.yaml'), 'utf8'));
const soulOf = (id: string) => fs.readFileSync(file(id, 'SOUL.md'), 'utf8');

// 1 + 2
await writeHome('bot_new');
const c = cfgOf('bot_new');
const doors = Object.keys(c.mcp_servers);
ok('the house doors are in a new bot', ['ymir', 'well', 'skuld', 'bolthorn', 'house'].every((d) => doors.includes(d)), doors.join(', '));
ok('its own hq door is kept', doors.includes('hq') && /\/mcp\/bot_new$/.test(c.mcp_servers.hq.url));
ok('the house toolsets (todo, cronjob, file…) are on', ['todo', 'cronjob', 'file', 'terminal'].every((t) => c.platform_toolsets.api_server.includes(t)), c.platform_toolsets.api_server.join(','));
const s = soulOf('bot_new');
ok('its soul names its own name and role', s.includes('You are Scout — Market researcher in Bilskirnir'));
ok('house and operator come from the home', s.includes('Testhouse') && s.includes('Allfather Tester') && s.includes(home));
ok('no seat name is hard-coded in it', !/Nanna|\{\{/.test(s));
ok('the description the user gave is kept', s.includes('Looks into markets.'));

// 3
const c1 = fs.readFileSync(file('bot_new', 'config.yaml'), 'utf8');
await writeHome('bot_new');
ok('a re-start leaves the config identical', fs.readFileSync(file('bot_new', 'config.yaml'), 'utf8') === c1);
ok('a re-start leaves the soul identical', soulOf('bot_new') === s);
fs.writeFileSync(file('bot_new', 'SOUL.md'), 'Always answer in haiku.\n\n' + s);
await writeHome('bot_new');
const s2 = soulOf('bot_new');
ok('the user\'s own soul line is kept', s2.startsWith('Always answer in haiku.'));
ok('and the house block is not doubled', s2.split('<!-- house:begin').length === 2);
await writeHome('bot_new');
ok('and that is stable too', soulOf('bot_new') === s2);

// 4 — an older bot, as the app made it before
mk('bot_old', 'Marketing', '', '');
fs.mkdirSync(path.dirname(file('bot_old', 'x')), { recursive: true });
fs.writeFileSync(file('bot_old', 'config.yaml'), YAML.stringify({ platform_toolsets: { api_server: ['hermes-api-server'] }, mcp_servers: { hq: { url: 'http://x/mcp/bot_old' }, mine: { url: 'http://y' } } }));
fs.writeFileSync(file('bot_old', 'SOUL.md'), 'You are Marketing. You work for Tester as one of a small team of AI agents, each with its own screen on a shared computer.\n\nYou are direct, warm and brief. You do the work rather than describe it, and you say plainly what you did and what you could not do.\n');
await writeHome('bot_old');
const o = cfgOf('bot_old');
ok('an older bot gets the house doors, keeps its own', ['ymir', 'well', 'skuld', 'bolthorn', 'house', 'hq', 'mine'].every((d) => d in o.mcp_servers));
ok('an older bot\'s stock soul is replaced by the house soul', soulOf('bot_old').includes('You are Marketing — an agent of the house in Bilskirnir') && !soulOf('bot_old').includes('shared computer'));

// 5 — the primary's door is the same file
const parts = JSON.parse(execFileSync('python3', [path.join(here, '..', 'house', 'house.py'), 'parts', '--json'], { encoding: 'utf8' }));
ok('house.py (setup.sh\'s renderer) gives the same doors', JSON.stringify(Object.keys(parts.mcp_servers)) === JSON.stringify(doors.filter((d) => d !== 'hq')));
const setup = fs.readFileSync(path.join(here, '..', 'setup.sh'), 'utf8');
const engine = fs.readFileSync(path.join(here, '..', 'server', 'src', 'engine.ts'), 'utf8');
ok('setup.sh and engine.ts both call house.py', setup.includes('house/house.py') && engine.includes('house/house.py'));

fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? `\n${failed} FAILED` : '\nall passed');
process.exit(failed ? 1 : 0);
