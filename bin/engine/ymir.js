#!/usr/bin/env node
/**
 * ymir — the CLI the npm package publishes, and the operator's front door.
 *
 * It is a thin, honest wrapper: the real work lives in the shell scripts under
 * bin/ and scripts/ — the same scripts a git clone runs. This file exists
 * because npm needs a Node entry point (`bin: ymir`) and because an operator
 * should never have to know where the package landed.
 *
 * The doors are named for the figure whose work they do (the naming law):
 * Eir heals, Gróa renews, Heimdall keeps the way in, Smíðja is the smithy and
 * its board, Hlidskjalf the high seat, Sessrúmnir the seat-hall, Mímir the well.
 *
 *   ymir                 first setup (the same as `ymir install`)
 *   ymir install [...]   first setup, idempotent and self-healing
 *   ymir raise / lower   lift the hall, or lay it down
 *   ymir eir             what stands, and mend what does not
 *   ymir groa            take the latest, and mend this home forward
 *   ymir smidja          the smithy's board (:8437) — build · start · stop · status
 *   ymir hlidskjalf      the high seat's window
 *   ymir sessrumnir      the seat-hall's window
 *   ymir odrerir         the live hall's window
 *   ymir mimir           the memory well
 *   ymir sense           what THIS machine is
 *   ymir --version
 *
 * Colour appears only where a human is watching (a TTY, no NO_COLOR); the data
 * on stdout is always plain TOON.
 *
 * Exit codes follow the scripts: 0 ok, 1 error, 2 usage.
 */
'use strict';

const { spawnSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

// The tree root: this file lives at bin/engine/ymir.js, so the root is TWO levels up. One level (the
// old bin/ymir.js) resolved to bin/ and every door answered "missing from this install" (2026-11-18).
const ROOT = path.resolve(__dirname, '..', '..');
const pkg = (() => {
  try { return require(path.join(ROOT, 'package.json')); } catch { return { version: '0.0.0' }; }
})();

// ── the cloth (the same palette as bin/desktop/ymir-style.sh, cut from the tokens) ───
const colour = process.stderr.isTTY && !process.env.NO_COLOR && process.env.TERM !== 'dumb';
const wrap = (code) => (s) => (colour ? `\u001b[${code}m${s}\u001b[0m` : `${s}`);
const bone = wrap('38;2;207;195;169');
const bronze = wrap('38;2;201;151;79');
const faint = wrap('38;2;107;98;80');
const blood = wrap('38;2;194;88;74');
const bold = wrap('1');

// ── what a user went from, and to ────────────────────────────────────────────
// `npm install -g` prints "changed 266 packages" and no versions, so an operator
// cannot see what moved. We can: record the version we last ran, and say the
// transition once, on the first run after an update.
// The operator's home, resolved the SAME way every script does (Rule 07):
// env → the recorded choice (~/.config/ymir/home) → the ONE documented default
// (`$HOME/Documents/ymirhome`). The old literal `$HOME/Documents/Ymir` was a stale
// name: on any machine whose real home is `ymirhome` (or a phone's Termux path) every
// run created a phantom `~/Documents/Ymir/state`, which the eir hoard check then refused
// as a foreign/duplicate map. Paths differ per machine — resolve, never assume.
function resolveHome() {
  if (process.env.YMIR_HOME) return process.env.YMIR_HOME;
  try {
    const cfg = process.env.YMIR_CONFIG_DIR
      || path.join(process.env.XDG_CONFIG_HOME || path.join(require('node:os').homedir(), '.config'), 'ymir');
    const f = path.join(cfg, 'home');
    if (fs.existsSync(f)) {
      const v = fs.readFileSync(f, 'utf8').trim();
      if (v) return v;
    }
  } catch { /* fall through to the default */ }
  return process.env.YMIR_HOME_DEFAULT
    || path.join(require('node:os').homedir(), 'Documents', 'ymirhome');
}
const YMIR_HOME_RESOLVED = resolveHome();
const STATE_DIR = process.env.YMIR_STATE_DIR || path.join(YMIR_HOME_RESOLVED, 'state');
function noticeState(key) {
  try {
    const s = process.env.YMIR_SETTINGS_DIR || path.join(YMIR_HOME_RESOLVED, 'config');
    const f = path.join(s, 'notices.conf');
    if (!fs.existsSync(f)) return 'on';
    const line = fs.readFileSync(f, 'utf8').split('\n').find((l) => l.startsWith(key + '='));
    return line ? line.slice(key.length + 1).trim() : 'on';
  } catch { return 'on'; }
}

function versionNotice() {
  try {
    if (noticeState('version') === 'off') return;
    const f = path.join(STATE_DIR, 'version');
    const seen = fs.existsSync(f) ? fs.readFileSync(f, 'utf8').trim() : '';
    if (seen === pkg.version) return;
    fs.mkdirSync(STATE_DIR, { recursive: true });
    fs.writeFileSync(f, pkg.version + '\n');
    if (!seen) return;                       // a first install has nothing to compare
    process.stderr.write(
      bone(`  the tree moved  `) + faint(`${seen} → `) + bronze(`${pkg.version}`) + '\n' +
      faint(`  run \`ymir eir\` to see what stands, \`ymir raise\` to lift the hall\n`) +
      (noticeState('hints') === 'off' ? '' : faint(`      (not again: ymir config notice version off)\n`)) +
      '\n');
  } catch { /* a version notice must never break a door */ }
}

// ── is this copy current? ────────────────────────────────────────────────────
// An install can succeed and change NOTHING: npm resolves a cached `latest`, sees
// the same version, and says "changed 200 packages" while the old build stays. A
// user cannot tell — so the tool says it, once a day, where a human is watching.
function checkForUpdate() {
  if (!process.stderr.isTTY || process.env.YMIR_NO_UPDATE_CHECK === '1') return;
  if (noticeState('version') === 'off') return;
  try {
    const os = require('node:os');
    const stamp = path.join(STATE_DIR, 'update-check');
    const today = new Date().toISOString().slice(0, 10);
    if (fs.existsSync(stamp) && fs.readFileSync(stamp, 'utf8').trim() === today) return;
    fs.mkdirSync(STATE_DIR, { recursive: true });
    fs.writeFileSync(stamp, today + '\n');
    const https = require('node:https');
    const req = https.get('https://registry.npmjs.org/@zerwiz/ymir/latest', { timeout: 1500 }, (res) => {
      let body = '';
      res.on('data', (d) => { body += d; });
      res.on('end', () => {
        try {
          const latest = JSON.parse(body).version;
          if (latest && latest !== pkg.version) {
            process.stderr.write('\n' + bronze('  a newer Ymir is on npm  ') + faint(`${pkg.version} → `) + bronze(latest) + '\n' +
              faint('  update:  npm i -g @zerwiz/ymir    (no PATH? npx @zerwiz/ymir)') + '\n' +
              (noticeState('hints') === 'off' ? '' : faint('      (not again: ymir config notice version off)') + '\n'));
          }
        } catch { /* a notice must never break a door */ }
      });
    });
    req.on('error', () => {});
    req.on('timeout', () => req.destroy());
  } catch { /* never break a door */ }
}

// ── the doors ────────────────────────────────────────────────────────────────
// verb → { script, args } — args are prepended to whatever the operator passes,
// so a verb can be a doorway to a sub-verb of a script that has several.
const DOORS = {
  install:    { script: 'bin/engine/ymir-install.sh',    about: 'first setup (idempotent, self-healing)' },
  raise:      { script: 'scripts/start.sh',       about: 'lift the hall — SPA, gate API, Nornir, bridges, the board' },
  lower:      { script: 'scripts/stop.sh',        about: 'lay the hall down' },
  eir:        { script: 'bin/agents/eir-doctor.sh',      about: 'diagnose every surface; mend what is broken' },
  groa:       { script: 'bin/agents/groa-update.sh',     about: 'take the latest, then mend this home forward' },
  projects:   { script: 'bin/records/projects.sh',     about: 'every project you work on — worktrees, PRs, kit (add · kit update · reap)' },
  sessions:   { script: 'bin/records/sessions.sh',     about: 'every agent session on this machine, from every tool — scan · list · decisions · updates' },
  smidja:     { script: 'bin/desktop/smidja-board.sh',    about: "the smithy's board on :8437 (build · start · stop · status)" },
  hlidskjalf: { script: 'scripts/electron.sh',    about: "the high seat's window", args: ['start', '--view', 'hlidskjalf'] },
  sessrumnir: { script: 'scripts/electron.sh',    about: "the seat-hall's window", args: ['start', '--view', 'sessrumnir'] },
  odrerir:    { script: 'scripts/electron.sh',    about: "the live hall's window", args: ['start', '--view', 'odrerir'] },
  mimir:      { script: 'bin/records/mimir.sh',           about: 'the memory well' },
  config:     { script: 'bin/engine/ymir-config.sh',     about: 'your preferences — which notices are shown (stay silent with `notice <key> off`)' },
  release:    { script: 'bin/engine/ymir-release.sh',     about: 'releases: build, flip, status, rollback, and `npm <x.y.z> [--yes]` (a dry run unless --yes)' },
  work:       { script: 'bin/fleet/work.sh',              about: 'the work road: mode, models per role, send an ask, intake (solo | fleet | offline)' },
  nornir:     { script: 'bin/time/nornir-status.sh',      about: 'every scheduled job, judged on the seat that owns it' },
  sense:      { script: 'bin/host/host-sense.sh',      about: 'what THIS machine is' },
  plan:       { script: 'bin/bridge/ymir-plan.sh',       about: 'what an install would do here — writes nothing' },
  migrate:    { script: 'bin/engine/ymir-migrate.sh',    about: "heal this home's structure forward (Gr\u00f3a's mend)" },
  validate:   { script: 'bin/engine/ymir-validate.sh',   about: 'alias of `ymir eir`' },
};

// Names the law has not given a home are kept for a while, so a muscle memory
// built yesterday still works — and says what to type instead.
const RENAMED = { validate: 'eir', auth: 'heimdall', desktop: 'hlidskjalf', doctor: 'eir', update: 'groa' };

// The MENU. A bare `ymir` used to run the installer outright — so a user who
// typed `ymir` to see what it was got a setup plan and a `Proceed? [y/N]`
// prompt, with no way to reach the other doors without knowing their names
// (2026-09-23). The doors are the product; show them, and let the Allfather
// choose. Same design language as the install plan: a mark, a one-line
// subtitle, indented rows, bronze names, faint prose.
function menu() {
  const lines = [];
  lines.push('');
  lines.push(`  ${bronze('\u16c9')}  ${bold('Ymir')} ${faint(pkg.version)}`);
  lines.push(`     ${faint('the single-tenant agent operating system')}`);
  lines.push('');

  // What this machine already is, in two facts — so the menu is not blind.
  const home = process.env.YMIR_HOME || null;
  lines.push(`  ${faint('home')}     ${home ? bronze(home) : faint('not chosen yet — run `ymir install`')}`);
  lines.push('');

  const GROUPS = [
    ['begin',   ['install', 'plan', 'sense']],
    ['keep it', ['groa', 'migrate', 'eir', 'validate']],
    ['lift it', ['raise', 'lower', 'smidja', 'hlidskjalf', 'sessrumnir']],
    ['your own', ['config', 'mimir']],
  ];
  for (const [title, verbs] of GROUPS) {
    lines.push(bold(`  ${title}`));
    for (const v of verbs) {
      const d = DOORS[v];
      if (!d) continue;
      lines.push(`    ${bronze(v.padEnd(11))} ${faint(d.about)}`);
    }
    lines.push('');
  }

  lines.push(faint('  `ymir <door>` runs one directly; `ymir --help` lists every door.'));
  lines.push(faint('  Nothing here changes this machine until you say so.'));
  lines.push('');
  process.stdout.write(lines.join('\n') + '\n');
  return 0;
}

function usage() {
  const lines = [];
  lines.push('');
  lines.push(`  ${bronze('\u16c9')}  ${bold('Ymir')} ${faint(pkg.version)}`);
  lines.push(`     ${faint('the single-tenant agent operating system')}`);
  lines.push('');
  lines.push(bold('  The doors'));
  for (const [verb, d] of Object.entries(DOORS)) {
    lines.push(`    ${bronze(verb.padEnd(11))} ${faint(d.about)}`);
  }
  lines.push('');
  lines.push(bold('  Composed by hand'));
  lines.push(`    ${bronze('ymir groa migrate'.padEnd(11))} ${faint("heal this home's structure (run by groa / install)")}`);
  lines.push(`    ${bronze('ymir heimdall set'.padEnd(11))} ${faint('set the operator password (or `github`)')}`);
  lines.push(`    ${bronze('ymir doctor hermes'.padEnd(11))} ${faint('every Hermes surface, four states per door (exit 0 only when all answer)')}`);
  lines.push(`    ${bronze('ymir hermes seat'.padEnd(11))} ${faint('seat Ymir in Hermes: --check compares values, --dry-run shows the diff')}`);
  lines.push(`    ${bronze('ymir wait-worker'.padEnd(11))} ${faint('a finished herdr worker wakes the Hermes session that asked (supervised)')}`);
  lines.push('');
  lines.push(faint('  A bare `ymir` runs the first setup. Output is TOON; colour only on a TTY.'));
  lines.push('');
  process.stdout.write(lines.join('\n') + '\n');
}

function run(script, args) {
  const file = path.join(ROOT, script);
  if (!fs.existsSync(file)) {
    process.stderr.write(`${blood('error:')} ${script} is missing from this install\n`);
    process.stderr.write(`${faint('help: reinstall — npm i -g @zerwiz/ymir, or git clone the distro')}\n`);
    process.exit(1);
  }
  const r = spawnSync('bash', [file, ...args], { stdio: 'inherit' });
  process.exit(r.status === null ? 1 : r.status);
}

const argv = process.argv.slice(2);
const first = argv[0];

versionNotice();
checkForUpdate();
// A bare `ymir` shows the MENU — never the installer. Setup is a door, entered
// on purpose.
if (!first) { menu(); process.exit(0); }
if (first === '--version' || first === '-v' || first === '-V') {
  process.stdout.write(`${pkg.version}\n`);
  process.exit(0);
}
if (first === '--help' || first === '-h' || first === 'help') { usage(); process.exit(0); }

// The Python core's verbs (plan 317 §4.3, §5): `ymir doctor hermes`, `ymir hermes <verb>`,
// `ymir wait-worker`. They run `python3 -m ymir_runtime.hermes` from THIS tree's src/, so the pin
// answers when the pin is what is installed. A bare `ymir doctor` still points at `ymir eir`.
function runPy(args) {
  const src = path.join(ROOT, 'src');
  const env = { ...process.env, PYTHONPATH: src + (process.env.PYTHONPATH ? path.delimiter + process.env.PYTHONPATH : '') };
  const r = spawnSync('python3', ['-m', 'ymir_runtime.hermes', ...args], { stdio: 'inherit', env });
  if (r.error) {
    process.stderr.write(`${blood('error:')} python3 could not be run: ${r.error.message}\n`);
    process.exit(1);
  }
  process.exit(r.status === null ? 1 : r.status);
}
if (first === 'doctor' && argv[1] === 'hermes') runPy(['doctor', ...argv.slice(2)]);
if (first === 'hermes') runPy(argv.slice(1));
if (first === 'wait-worker') runPy(['wait-worker', ...argv.slice(1)]);

let door = DOORS[first];
if (!door) {
  const replacement = RENAMED[first];
  process.stderr.write(`${blood('error:')} unknown door ${bold(first)}\n`);
  if (replacement) process.stderr.write(`${faint(`help: the door is named \`ymir ${replacement}\` now (the naming law — a figure does the work)`)}\n`);
  process.stderr.write(`${faint('help: `ymir --help` lists every door')}\n`);
  process.exit(2);
}
run(door.script, [...(door.args || []), ...argv.slice(1)]);
