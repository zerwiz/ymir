#!/usr/bin/env node
/**
 * ymir — the CLI the npm package publishes.
 *
 * It is a thin, honest wrapper: the real work lives in the shell scripts under
 * bin/, which are the same scripts a git clone runs. This file exists because
 * npm needs a Node entry point (`bin: ymir`) and because a package user should
 * not have to know where the checkout landed.
 *
 *   ymir                 # the same as `ymir install`
 *   ymir install [--yes] # first setup (idempotent, self-healing)
 *   ymir sense           # what THIS machine is
 *   ymir validate        # prove what stands
 *   ymir migrate         # heal an older home forward
 *   ymir --version
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

const TASKS = {
  install: 'ymir-install.sh',
  validate: 'ymir-validate.sh',
  migrate: 'ymir-migrate.sh',
  sense: 'host-sense.sh',
};

function usage() {
  process.stdout.write(
    `ymir ${pkg.version} — the single-tenant agent operating system\n\n` +
    'Usage:\n' +
    '  ymir                 first setup (same as `ymir install`)\n' +
    '  ymir install [--yes] first setup, idempotent and self-healing\n' +
    '  ymir sense           report THIS machine (distro, session, desktop, capabilities)\n' +
    '  ymir validate        verify the running system\n' +
    '  ymir migrate         heal an older home forward\n' +
    '  ymir --version\n\n' +
    'Output is TOON. The scripts are the source of truth; this CLI only points at them.\n'
  );
}

function run(script, args) {
  const file = path.join(ROOT, 'bin', script);
  if (!fs.existsSync(file)) {
    process.stderr.write(`error: ${path.relative(ROOT, file)} is missing from this install\n`);
    process.stderr.write('help: reinstall — npm i -g @zerwiz/ymir, or git clone the distro\n');
    process.exit(1);
  }
  const r = spawnSync('bash', [file, ...args], { stdio: 'inherit' });
  process.exit(r.status === null ? 1 : r.status);
}

const argv = process.argv.slice(2);
const first = argv[0];

if (!first) run(TASKS.install, []);
if (first === '--version' || first === '-v' || first === '-V') {
  process.stdout.write(`${pkg.version}\n`);
  process.exit(0);
}
if (first === '--help' || first === '-h' || first === 'help') { usage(); process.exit(0); }

const script = TASKS[first];
if (!script) {
  process.stderr.write(`error: unknown command ${first}\n`);
  process.stderr.write('help: ymir [install|sense|validate|migrate|--version]\n');
  process.exit(2);
}
run(script, argv.slice(1));
