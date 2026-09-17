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
 *   ymir heimdall        the way in: your credential, and invites
 *   ymir smidja          the smithy's board (:8437) — build · start · stop · status
 *   ymir hlidskjalf      the high seat's window
 *   ymir sessrumnir      the seat-hall's window
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

const ROOT = path.resolve(__dirname, '..');
const pkg = (() => {
  try { return require(path.join(ROOT, 'package.json')); } catch { return { version: '0.0.0' }; }
})();

// ── the cloth (the same palette as bin/ymir-style.sh, cut from the tokens) ───
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
const STATE_DIR = process.env.YMIR_STATE_DIR || path.join(process.env.YMIR_HOME || path.join(require('node:os').homedir(), 'Documents', 'Ymir'), 'state');
function versionNotice() {
  try {
    const f = path.join(STATE_DIR, 'version');
    const seen = fs.existsSync(f) ? fs.readFileSync(f, 'utf8').trim() : '';
    if (seen === pkg.version) return;
    fs.mkdirSync(STATE_DIR, { recursive: true });
    fs.writeFileSync(f, pkg.version + '\n');
    if (!seen) return;                       // a first install has nothing to compare
    process.stderr.write(
      bone(`  the tree moved  `) + faint(`${seen} → `) + bronze(`${pkg.version}`) + '\n' +
      faint(`  run \`ymir eir\` to see what stands, \`ymir raise\` to lift the hall\n\n`));
  } catch { /* a version notice must never break a door */ }
}

// ── the doors ────────────────────────────────────────────────────────────────
// verb → { script, args } — args are prepended to whatever the operator passes,
// so a verb can be a doorway to a sub-verb of a script that has several.
const DOORS = {
  install:    { script: 'bin/ymir-install.sh',    about: 'first setup (idempotent, self-healing)' },
  raise:      { script: 'scripts/start.sh',       about: 'lift the hall — SPA, gate API, Nornir, bridges, the board' },
  lower:      { script: 'scripts/stop.sh',        about: 'lay the hall down' },
  eir:        { script: 'bin/eir-doctor.sh',      about: 'diagnose every surface; mend what is broken' },
  groa:       { script: 'bin/groa-update.sh',     about: 'take the latest, then mend this home forward' },
  heimdall:   { script: 'bin/ymir-setup-auth.sh', about: 'the way in — your credential (status · set · github)' },
  invite:     { script: 'bin/ymir-invite.sh',     about: 'let someone else in (mint · list · revoke)' },
  smidja:     { script: 'bin/smidja-board.sh',    about: "the smithy's board on :8437 (build · start · stop · status)" },
  hlidskjalf: { script: 'scripts/electron.sh',    about: "the high seat's window", args: ['start', '--view', 'hlidskjalf'] },
  sessrumnir: { script: 'scripts/electron.sh',    about: "the seat-hall's window", args: ['start', '--view', 'sessrumnir'] },
  mimir:      { script: 'bin/mimir.sh',           about: 'the memory well' },
  sense:      { script: 'bin/host-sense.sh',      about: 'what THIS machine is' },
  plan:       { script: 'bin/ymir-plan.sh',       about: 'what an install would do here — writes nothing' },
  migrate:    { script: 'bin/ymir-migrate.sh',    about: "heal this home's structure forward (Gr\u00f3a's mend)" },
  validate:   { script: 'bin/ymir-validate.sh',   about: 'alias of `ymir eir`' },
};

// Names the law has not given a home are kept for a while, so a muscle memory
// built yesterday still works — and says what to type instead.
const RENAMED = { validate: 'eir', auth: 'heimdall', desktop: 'hlidskjalf', doctor: 'eir', update: 'groa' };

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
if (!first) run(DOORS.install.script, []);
if (first === '--version' || first === '-v' || first === '-V') {
  process.stdout.write(`${pkg.version}\n`);
  process.exit(0);
}
if (first === '--help' || first === '-h' || first === 'help') { usage(); process.exit(0); }

let door = DOORS[first];
if (!door) {
  const replacement = RENAMED[first];
  process.stderr.write(`${blood('error:')} unknown door ${bold(first)}\n`);
  if (replacement) process.stderr.write(`${faint(`help: the door is named \`ymir ${replacement}\` now (the naming law — a figure does the work)`)}\n`);
  process.stderr.write(`${faint('help: `ymir --help` lists every door')}\n`);
  process.exit(2);
}
run(door.script, [...(door.args || []), ...argv.slice(1)]);
