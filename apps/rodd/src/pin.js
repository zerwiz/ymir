// pin.js — where Rödd's code lives: the PINNED runtime, never the working tree.
//
// Plan 257 H7 (measured 2026-11-11): Rödd's window ran `electron ~/ymir/apps/rodd` and her
// tool server ran `uvicorn --app-dir ~/ymir/apps/rodd/ui` — the WORKING tree, the directory
// agents switch branches in — while the arm service ran the pin. A `git checkout` in ~/ymir
// changed what she would run on her next start, silently (RULES/02 §7).
//
// So her code root is resolved ONCE, here, from the same record every unit reads:
//   1. $YMIR_RUNTIME_DIR (the launcher exports it)
//   2. $YMIR_HOME/config/runtime.env  YMIR_RUNTIME_DIR=…   ($HOME expanded once)
// and nothing else. No `~/ymir`, no `__dirname` guess. A pin that is absent is a REFUSAL
// with one named line — the window says why it will not start, it does not run the tree.

const fs = require('node:fs');
const path = require('node:path');

function homeDir(env) {
  // allow-home-default: the one home, resolved then used
  return env.YMIR_HOME || path.join(env.HOME || '', 'Documents/ymirhome');
}

function fromRuntimeEnv(env) {
  const conf = path.join(homeDir(env), 'config', 'runtime.env');
  let text = '';
  try { text = fs.readFileSync(conf, 'utf8'); } catch { return ''; }
  for (const line of text.split('\n')) {
    const m = line.match(/^\s*YMIR_RUNTIME_DIR\s*=\s*(.+?)\s*$/);
    if (m) {
      return m[1].replace(/^['"]|['"]$/g, '').replace(/\$\{?HOME\}?/g, env.HOME || '');
    }
  }
  return '';
}

// The split (2026-11-19): the window may live in its OWN home (~/.local/share/ymir-apps/rodd/current), a release
// exported from its repo — never a working tree. Then its face is its own (`<this app>/ui`), and the pin is only
// where Ymir's voice and arm are borrowed from. A window that still sits inside a Ymir tree keeps the old road.
function ownHome() {
  const app = path.resolve(__dirname, '..');
  const tree = path.resolve(app, '..', '..');
  return fs.existsSync(path.join(tree, 'bin', 'voice', 'voice-door.sh')) ? '' : app;
}

// resolvePin(env) → { root, source } or { error } — the error is the ONE named line.
function resolvePin(env = process.env) {
  const explicit = (env.YMIR_RUNTIME_DIR || '').trim();
  const root = explicit || fromRuntimeEnv(env);
  const source = explicit ? 'YMIR_RUNTIME_DIR' : 'runtime.env';
  if (!root) {
    return { error: `Rödd refuses to start: no pinned runtime is named (YMIR_RUNTIME_DIR unset and ${path.join(homeDir(env), 'config', 'runtime.env')} names none)` };
  }
  const own = ownHome();
  if (own) {
    if (!fs.existsSync(path.join(root, 'bin', 'voice', 'voice-door.sh'))) {
      return { error: `Rödd refuses to start: her voice comes from Ymir, and ${root} (from ${source}) carries no bin/voice/voice-door.sh` };
    }
    return { root, app: own, ui: path.join(own, 'ui'), source };
  }
  const app = path.join(root, 'apps', 'rodd');
  if (!fs.existsSync(path.join(app, 'src', 'main.js'))) {
    return { error: `Rödd refuses to start: the pinned runtime ${root} (from ${source}) carries no apps/rodd — run bin/engine/runtime-deploy.sh` };
  }
  return { root, app, ui: path.join(app, 'ui'), source };
}

module.exports = { resolvePin };
