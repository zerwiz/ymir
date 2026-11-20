#!/usr/bin/env node
// test-boot-path.mjs — prove the failed boot is a sentence and a clean exit, not a SIGTRAP.
//
// Plan 231 R3. `apps/rodd/src/main.js` used to `reject('ui server did not answer')` into an
// unhandled promise; Electron answers that with a crash, which is the core dump we read. This
// harness loads the REAL main.js with `electron` replaced by a recorder (the window it would
// have opened records the URL it was given), points the interpreter at something that cannot
// start, and asserts three things:
//
//   1. ONE console line per attempt names the interpreter and the directory;
//   2. it retries exactly once — two attempts, not a loop;
//   3. the window that appears carries the sentence, and the process sets a failing exit code
//      without calling app.exit() from the boot path (no crash, no silent quit).
//
//   node apps/rodd/smoke/test-boot-path.mjs
// Exit: 0 every proof held · 1 a proof failed.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Module from 'node:module';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const MAIN = path.join(HERE, '..', 'src', 'main.js');

const windows = [];
const exits = [];
const consoleLines = [];

class FakeBrowserWindow {
  constructor(opts = {}) {
    this.opts = opts;
    this.title = opts.title || '';
    this.url = '';
    this.webContents = {
      on() {},
      executeJavaScript: () => Promise.resolve('{}'),
      reload() {},
    };
    windows.push(this);
  }
  setTitle(t) { this.title = t; }
  loadURL(u) { this.url = u; return Promise.resolve(); }
  on() {}
}

const fakeElectron = {
  app: {
    whenReady: () => Promise.resolve(),
    getPath: () => os.tmpdir(),
    on() {},
    quit() {},
    exit: (code) => exits.push(code),
  },
  BrowserWindow: FakeBrowserWindow,
  Menu: { setApplicationMenu() {} },
  session: { defaultSession: { setPermissionCheckHandler() {}, setPermissionRequestHandler() {} } },
};

// the console is the operator's window on a boot that failed — capture it
const realError = console.error;
const realLog = console.log;
console.error = (...a) => { consoleLines.push(a.join(' ')); realError(...a); };
console.log = (...a) => { consoleLines.push(a.join(' ')); realLog(...a); };

const load = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === 'electron') return fakeElectron;
  return load.call(this, request, parent, isMain);
};

process.env.RODD_PYTHON = '/nonexistent/rodd-test-python';
process.env.RODD_BOOT_TIMEOUT_MS = '4000';
process.env.RODD_BOOT_RETRY_PAUSE_MS = '10';

await import(`file://${MAIN}`);

// the async boot settles a tick after the import
await new Promise((r) => setTimeout(r, 1500));

let failed = 0;
const ok = (name) => realLog(`  ok    ${name}`);
const bad = (name, detail) => { realLog(`  FAIL  ${name}${detail ? ' — ' + detail : ''}`); failed = 1; };

const attempts = consoleLines.filter((l) => l.includes('ui server (attempt'));
attempts.length === 2 ? ok('exactly one retry (two attempts)')
  : bad('the retry count', `saw ${attempts.length} attempt line(s)`);

const failure = consoleLines.filter((l) => l.includes('UI SERVER FAILED'));
failure.length >= 1 ? ok('a failed boot is one named line') : bad('the failure line is missing');
if (failure.length) {
  const line = failure[failure.length - 1];
  line.includes('/nonexistent/rodd-test-python') && line.includes('ui')
    ? ok('the line names the interpreter and the directory')
    : bad('the line does not name both', line);
}

const sentence = windows.find((w) => w.url.startsWith('data:text/html'));
sentence ? ok('the failure opened a window') : bad('no window carried the sentence');
if (sentence) {
  const body = decodeURIComponent(sentence.url.split(',').slice(1).join(','));
  body.includes('The UI server did not start') ? ok('the window carries the sentence')
    : bad('the window does not carry the sentence');
  body.includes('/nonexistent/rodd-test-python') ? ok('the sentence names the interpreter')
    : bad('the sentence does not name the interpreter');
}

exits.length === 0 ? ok('the boot path did not force-exit (no crash)')
  : bad('the boot path called app.exit', JSON.stringify(exits));
process.exitCode === 1 ? ok('the process leaves with a failing exit code')
  : bad('the exit code says success', String(process.exitCode));

realLog('');
if (failed) { realLog('boot-path: a proof FAILED'); process.exit(1); }
realLog('boot-path: every proof held');
process.exit(0);
