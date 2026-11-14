// Rödd — the voice of Ymir, as a desk app.
//
// The house already has a realtime voice UI (the engine's own browser face, dressed in
// the house's cloth at ui/). This shell gives it what every other Ymir app has: a window
// of its own in the launcher, a stable title, one process to start and stop.
//
// It serves ui/ from a tiny loopback HTTP server — the browser needs a real origin for
// getUserMedia, and the UI's ES modules cannot load from file://.
//
// The voice PIPELINE is not started here. It is the door's business:
//   bin/voice/voice-door.sh start|stop|status|log
// This app is the face; the door is the pipeline. A window that claims to host a voice
// it did not raise would be a lie told in pixels.

const { app, BrowserWindow, Menu, session } = require('electron');
// The window's WM class, named ONCE and never left to the package name (2026-11-14). Without this Electron
// presented `zerwiz-rodd` (from `@zerwiz/rodd`), while bin/desktop/app-lib.sh — the ONE source of truth for
// routing, the .desktop StartupWMClass, the generated Hyprland rule and ymir-app's "open where you click"
// watcher — all name `ymir-rodd`. So a rule for Rödd matched nothing, and the click-to-desktop follow waited
// thirty seconds for a window it had already missed. Every other Ymir app sets its slug; this one now does too.
app.setName('ymir-rodd');
const { execFile } = require('node:child_process');
const http = require('node:http');
const path = require('node:path');
const fs = require('node:fs');

// The code root is the PINNED runtime, never the tree this file happens to sit in (plan 257
// H7): the face, the tool server's --app-dir and every door the instructions name resolve
// from YMIR_RUNTIME_DIR / runtime.env. An absent pin is a refusal, said in the window.
const { resolvePin } = require('./pin');
const PIN = resolvePin(process.env);
const UI = PIN.ui || '';
const ARM_DOOR = PIN.root ? path.join(PIN.root, 'bin', 'voice', 'rodd-arm.sh') : 'bin/voice/rodd-arm.sh';
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.wasm': 'application/wasm',
  '.onnx': 'application/octet-stream', '.svg': 'image/svg+xml', '.png': 'image/png',
  '.ico': 'image/x-icon', '.woff2': 'font/woff2',
};

// The UI ships its own server (demo/server.py) which serves the front-end AND the
// same-origin endpoints the front-end expects (/api/config, /api/session, the search
// proxy). Re-implementing those by hand was the fault: the client must talk to the
// server the project ships. So the app SPAWNS that server, on an ephemeral port.
//
// A FAILED BOOT IS A SENTENCE, NOT A REJECTION (plan 231 R3). This used to `reject('ui
// server did not answer')` into an unhandled promise, which Electron answered with the
// SIGTRAP we read in a core file — the crash was the boot path, not the compositor. Now a
// failed spawn keeps the last twenty stderr lines, prints the interpreter and the directory
// in ONE console line, tries once more after a pause, and then shows the reason in the
// window and exits. No silent retry loop, no crash, one message.
const BOOT_TIMEOUT_MS = Number(process.env.RODD_BOOT_TIMEOUT_MS || 20000);   // one documented default
const BOOT_RETRY_PAUSE_MS = Number(process.env.RODD_BOOT_RETRY_PAUSE_MS || 1500);

// the interpreter, named ONCE: env wins, then the seat's own venv (Rule 07)
function defaultPython() {
  return process.env.RODD_PYTHON || path.join(process.env.HOME || '', 'venvs/s2s/bin/python');   // allow-home-default: the seat's own venv
}

function startUiServer(attempt = 1) {
  return new Promise((resolve, reject) => {
    const port = 7800 + Math.floor(Math.random() * 90);
    const env = { ...process.env, SPEECH_TO_SPEECH_URL: process.env.SPEECH_TO_SPEECH_URL || '' };
    // the interpreter is named ONCE, and it is logged: when the spawn silently dies the
    // shell must be able to read which python and which directory it was asked for
    const py = defaultPython();
    const dir = UI;
    const logPath = path.join(app.getPath('temp'), 'rodd-uiserver.log');
    console.log(`[rodd] ui server (attempt ${attempt}):`, JSON.stringify(py), '-m uvicorn --app-dir', JSON.stringify(dir), 'port', port);
    const tail = [];
    let settled = false;
    const remember = (d) => {
      String(d).split('\n').filter(Boolean).forEach((line) => tail.push(line.slice(0, 300)));
      while (tail.length > 20) tail.shift();
    };
    const fail = (why) => {
      if (settled) return;
      settled = true;
      reject(Object.assign(new Error(why), { py, dir, port, tail: tail.slice(-20), log: logPath }));
    };
    const proc = execFile(
      py,
      ['-m', 'uvicorn', '--app-dir', dir, 'server:app', '--host', '127.0.0.1', '--port', String(port)],
      { env: { ...env, YMIR_RUNTIME_DIR: PIN.root }, cwd: dir, timeout: 0 },
      (err) => { if (err) console.error('[rodd] ui server exited:', err.message); },
    );
    // a missing interpreter is an 'error' event, not stderr — the very case that used to hang
    // for the full deadline and then reject into the void
    proc.on('error', (err) => fail(`the interpreter did not start: ${err.message}`));
    proc.stderr.on('data', (d) => {
      remember(d);
      try { fs.appendFileSync(logPath, d); } catch {}
    });
    const deadline = Date.now() + BOOT_TIMEOUT_MS;
    const wait = () => {
      if (settled) return;
      const req = http.get({ host: '127.0.0.1', port, path: '/api/config', timeout: 1500 }, (res) => {
        res.resume();
        if (res.statusCode === 200) {
          if (settled) return;
          settled = true;
          console.log('[rodd] ui server answered on port', port);
          resolve({ port, proc });
        } else { retry(); }
      });
      req.on('error', retry);
      req.on('timeout', () => { req.destroy(); retry(); });
    };
    const retry = () => {
      if (settled) return;
      if (Date.now() > deadline) fail(`the ui server did not answer within ${Math.round(BOOT_TIMEOUT_MS / 1000)}s`);
      else setTimeout(wait, 400);
    };
    setTimeout(wait, 600);
  });
}

// One console line that names the interpreter, the directory and what it last said.
function bootFailureLine(err) {
  const py = (err && err.py) || defaultPython();
  const dir = (err && err.dir) || UI;
  const said = (err && err.tail && err.tail.length) ? err.tail.join(' | ') : ((err && err.message) || 'no output');
  return `[rodd] UI SERVER FAILED — python ${JSON.stringify(py)} dir ${JSON.stringify(dir)} — ${said}`;
}

// The sentence he can read, in the window he is looking at, instead of a core dump.
function showBootFailure(err) {
  err = err || new Error('the UI server did not start');
  err.py = err.py || defaultPython();
  err.dir = err.dir || UI;
  err.log = err.log || path.join(app.getPath('temp'), 'rodd-uiserver.log');
  const said = (err.tail && err.tail.length ? err.tail : [err.message || '']).join('\n');
  const html = `<!doctype html><meta charset="utf-8"><title>Rödd — the UI server did not start</title>
<style>body{background:#0e0c09;color:#e8e0d0;font:16px/1.5 system-ui,sans-serif;padding:2.5rem;max-width:52rem}
code,pre{background:#1a1712;color:#cdbfa4}h1{font-size:1.25rem;font-weight:600}</style>
<h1>The UI server did not start.</h1>
<p>python <code>${String(err.py || '').replace(/</g, '&lt;')}</code><br>
dir <code>${String(err.dir || '').replace(/</g, '&lt;')}</code></p>
<p>The log: <code>${String(err.log || '').replace(/</g, '&lt;')}</code></p>
<pre>${String(said).replace(/</g, '&lt;').slice(0, 4000)}</pre>
<p>Nothing else was started. Close this window to exit; the voice pipeline is untouched.</p>`;
  const win = new BrowserWindow({
    width: 860, height: 620, title: 'Rödd — the UI server did not start',
    backgroundColor: '#0e0c09', autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, sandbox: true },
  });
  win.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`);
  process.exitCode = 1;
}

function probeSlot(url) {
  return new Promise((resolve) => {
    const ws = new WebSocket(url);
    let settled = false;
    const done = (v) => { if (!settled) { settled = true; try { ws.close(); } catch {} resolve(v); } };
    ws.onopen = () => done('open');
    // The engine leaks its single slot when a client dies mid-response ("SESSION_END not
    // drained"), and then refuses every new client with an error event. Any error on connect
    // means the slot is not ours — clear it through the door rather than open into silence.
    ws.onmessage = (e) => {
      try { const m = JSON.parse(e.data); if (m?.type === 'error' || m?.error) done('busy'); } catch {}
    };
    ws.onerror = () => done('down');
    setTimeout(() => done('timeout'), 4000);
  });
}

function restartHost(url) {
  return new Promise((resolve) => {
    let host = process.env.YMIR_VOICE_HOST;
    if (!host) {
      try {
        const home = process.env.YMIR_HOME || path.join(process.env.HOME || '', 'Documents/ymirhome');  // allow-home-default: the one home, resolved then used
        const fleet = JSON.parse(fs.readFileSync(path.join(home, 'hodd/data/fleet.json'), 'utf8'));
        host = (fleet.ear || [])[0];
      } catch {}
    }
    if (!host) return resolve('no host known');
    execFile('ssh', ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=6', host,
      'cd ~/ymir && ./bin/voice/voice-door.sh host --now'], { timeout: 240000 }, (err) => resolve(err ? String(err.message) : 'restarted'));
  });
}

app.whenReady().then(async () => {
  Menu.setApplicationMenu(null);
  // The face offers the camera only when the head can see: start.sh says which head it
  // raised (RODD_CAMERA=1 with the vision head), and a picture sent to a text-only head
  // is answered `500 image input is not supported` — for that turn AND every turn after
  // it, because the image stays in the conversation. One snapshot ended a session.
  console.log('[rodd] camera', process.env.RODD_CAMERA === '1' ? 'on (the head can see)' : 'off (text-only head)');

  // A voice window without a microphone is a picture of a voice. Electron denies
  // getUserMedia unless the seat asks for it: grant media on this loopback origin only.
  session.defaultSession.setPermissionCheckHandler((wc, permission) => {
    const url = (wc && wc.getURL && wc.getURL()) || '';
    const local = url.includes('127.0.0.1') || url.includes('localhost') || url === '';
    return local && ['media', 'audioCapture'].includes(permission);
  });
  session.defaultSession.setPermissionRequestHandler((wc, permission, callback, details) => {
    const origin = new URL(details.requestingUrl || wc.getURL() || 'http://127.0.0.1');
    const local = origin.hostname === '127.0.0.1' || origin.hostname === 'localhost';
    callback(local && ['media', 'audioCapture', 'display-capture', 'clipboard-read', 'clipboard-sanitized-write'].includes(permission));
  });

  // No pin, no Rödd: one named line in the console and in the window, never the tree.
  if (PIN.error) {
    console.error('[rodd] ' + PIN.error);
    showBootFailure(Object.assign(new Error(PIN.error), { dir: '(no pinned runtime)' }));
    return;
  }
  console.log('[rodd] code root', JSON.stringify(PIN.root), 'from', PIN.source);

  // ONE retry after a pause, then the sentence and a clean exit (plan 231 R3).
  let started = null;
  let lastError = null;
  for (const attempt of [1, 2]) {
    try {
      started = await startUiServer(attempt);
      break;
    } catch (err) {
      lastError = err;
      console.error(bootFailureLine(err));
      if (attempt === 1) await new Promise((r) => setTimeout(r, BOOT_RETRY_PAUSE_MS));
    }
  }
  if (!started) {
    // a sentence in the window he is looking at, and an exit — never a rejection, never a loop
    showBootFailure(lastError);
    return;
  }
  const { port, proc } = started;
  app.on('before-quit', () => { try { proc.kill(); } catch {} });
  const win = new BrowserWindow({
    width: 1180, height: 820, title: 'Rödd',
    backgroundColor: '#0e0c09',
    autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, sandbox: true },
    // the rune of the voice (ᛚ Laguz, plan 275): the window wears its own minted icon, as every app's does
    icon: require('path').join(__dirname, '..', 'electron', 'icon.png'),
  });
  win.setTitle('Rödd');
  // The engine's UI defaults to a Qwen3-TTS voice ("Aiden"); the house mouth is Kokoro.
  // A saved Qwen voice in localStorage would 404 the synthesiser and silence the answer.
  win.webContents.on('did-finish-load', () => {
    const HOUSE_INSTRUCTIONS = [
      "You are Skírnir, the Allfather's voice in Ymir — not a generic assistant.",
      "Speak in one or two short sentences. Address him as Allfather.",
      "You DO have hands in this window. Use them: for his own notes, plans or files use search_home and",
      "read_home_file (his day and todo are life/personal/me/todo.md); for mail use read_mail with scope",
      "inbox, sent, drafts or all; for his day use read_calendar; for boards, projects, places, tasks or",
      "who owes what use gimle; to record something use add_todo; for anything about past work or a",
      "decision use recall first.",
      "For any request with more than one step, first call plan_write and read the numbered steps back to",
      "him; send nothing until he approves the steps. To give work to a worker use hand_over — first call",
      "WITHOUT confirm so he is asked out loud, and only call again with confirm=true after he says yes.",
      "Check context_left on a long conversation so you summarise before the window fills.",
      "cron_jobs says whether the schedule is running and what is on it; plans reads the numbered plan",
      "ledger (a PLAN is not an ERRAND); research sends Huginn out — ask him out loud first, then confirm.",
      "That door resolves the ARM LEASE and prints the holder's pid, generation, state dir and how fresh its heartbeat is.",
      "If it prints 'no arm is held', say exactly that — nobody is watching — and never guess a name or a session.",
      `To hand him something, use: bash ${ARM_DOOR} tell "<the one line>". It refuses when no arm`,
      "is held, and that refusal is the truth: say it out loud instead of claiming you sent it.",
      "THE ARM HOLDER — who is watching, right now. Before answering anything about what Ymir is doing, whether anyone",
      `is supervising, or what was decided, RUN: bash ${ARM_DOOR} who — it resolves the ARM LEASE and prints the`,
      "holder's seat, role, charter, host, fleet role, pin, generation, pid and heartbeat age. If it answers 'no arm is held', say exactly that and never",
      `guess a name. To hand him one line: bash ${ARM_DOOR} tell "<the line>" — it refuses when no arm is held,`,
      "and that refusal is the truth: say it, do not claim you sent it.",
      "You also have ls, read, edit and bash, and mcp (chrome-devtools drives the browser, well and the",
      "board hold the record). edit, bash and any mcp call that can write ask him out loud first and run",
      "only on his yes; a destructive command is refused outright — say so, never work around it.",
      "For how many agents are working or where the work is, call seats (it reads the herdr panes) and",
      "pane_read or seats(pane=…) for one of them — errand_state knows only this seat's own errands.",
      "sessrumnir says whether the desktop seat is up and what its workspaces hold; you cannot post into",
      "its conversations yet, and you say so.",
      "Two hands reach the session that HOLDS THE ARM — the mind that plans, drains wakes and sends the",
      "workers out. That mind is NOT this window's own agent. talk_to_arm hands it a message in his words,",
      "one plain line; hear_from_arm reads what it has answered since you last listened, and the answer",
      "comes back on a later turn, never in the same breath. Hand a message over only when the door returns",
      "delivered=yes, and never say sent or done on your own word: if no reply has arrived, say the arm has",
      "not written back yet.",
      "Mail: the Gmail MCP drafts and labels but cannot send, and its calls are refused until the Cloud",
      "project is enrolled — never promise to send; use mail_compose to open a prefilled letter for him.",
      "Never claim a merge, a push, a sent mail or a changed board unless a tool returned it; the vault is",
      "closed to you and you say so. Never say a message was sent, handed over or answered unless the door",
      "that carries it returned that it did.",
    ].join(' ');
    win.webContents.executeJavaScript(`
      (() => {
        const out = {};
        const v = localStorage.getItem('s2s.ws.voice') || '';
        if (!/^(af|am|bf|bm)_/.test(v)) { localStorage.setItem('s2s.ws.voice', 'af_nicole'); out.voice = 'repaired ' + v; }
        localStorage.setItem('s2s.ws.instructions', ${JSON.stringify('HOUSE_PLACEHOLDER')});
        out.instructions = 'set';
        return JSON.stringify(out);
      })()`.replace('HOUSE_PLACEHOLDER', HOUSE_INSTRUCTIONS.replace(/"/g, '\\"')))
      .then((r) => { try { fs.appendFileSync(process.env.TMPDIR + '/rodd-window.log', '[house] identity ' + r + '\n'); } catch {} });
  });
  // The engine leaks its single session slot when a client disconnects uncleanly
  // ("SESSION_END not drained"), and then refuses every new client with
  // `session_limit_reached`. The page reports that as a console warning; when we see
  // it, clear the pipeline through the door and reload the face once.
  let healed = 0;
  win.webContents.on('console-message', (event, level, message) => {
    const text = (event && typeof event === 'object' && event.message) ? event.message : String(message || '');
    if (healed < 2 && /session_limit_reached|All \d+ session slots are in use/.test(text)) {
      healed += 1;
      console.log('[rodd] leaked session slot — restarting the pipeline and reloading the face');
      restartHost(process.env.SPEECH_TO_SPEECH_URL || '').then(() => { try { win.webContents.reload(); } catch {} });
    }
  });

  // clear a held slot before the page tries to speak into it
  const target = process.env.SPEECH_TO_SPEECH_URL || '';
  if (target) {
    const state = await probeSlot(target);
    if (state === 'busy') {
      console.log('[rodd] session slot held — restarting the pipeline through the door');
      await restartHost(target);
    }
  }
  // the window's own console, so a silent failure is readable from the shell
  const logPath = require('node:path').join(app.getPath('temp'), 'rodd-window.log');
  // Electron 41 passes a single event object; older builds passed (event, level, message).
  win.webContents.on('console-message', (event, level, message) => {
    const line = (event && typeof event === 'object' && event.message) ? `[${event.level}] ${event.message}` : `[${level}] ${message}`;
    try { fs.appendFileSync(logPath, line + '\n'); } catch {}
  });
  // a failed connection must be visible, not silent
  win.webContents.on('did-fail-load', (_e, code, desc, url) => {
    try { fs.appendFileSync(logPath, `FAIL-LOAD ${code} ${desc} ${url}\n`); } catch {}
  });
  await win.loadURL(`http://127.0.0.1:${port}/?camera=${process.env.RODD_CAMERA === '1' ? '1' : '0'}`);
  win.on('closed', () => { try { proc.kill(); } catch {} });
}).catch((err) => {
  // anything that escapes the boot path is still a sentence and an exit, never a crash
  console.error(bootFailureLine(err));
  try { showBootFailure(err); } catch { app.exit(1); }
});

app.on('window-all-closed', () => app.quit());

// Electron answers an unhandled rejection with a crash (the SIGTRAP in the core); a boot fault
// must be a line in the log and a clean exit instead. These two guards are the last resort
// BEHIND the handled path above, and they name what happened before they stop.
process.on('unhandledRejection', (reason) => {
  console.error('[rodd] unhandled rejection — ' + (reason && reason.message ? reason.message : String(reason)));
  app.exit(1);
});
process.on('uncaughtException', (err) => {
  console.error('[rodd] uncaught exception — ' + (err && err.stack ? err.stack.split('\n')[0] : String(err)));
  app.exit(1);
});
