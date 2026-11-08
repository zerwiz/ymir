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
const { execFile } = require('node:child_process');
const http = require('node:http');
const path = require('node:path');
const fs = require('node:fs');

const UI = path.join(__dirname, '..', 'ui');
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
function startUiServer() {
  return new Promise((resolve, reject) => {
    const port = 7800 + Math.floor(Math.random() * 90);
    const env = { ...process.env, SPEECH_TO_SPEECH_URL: process.env.SPEECH_TO_SPEECH_URL || '' };
    // the interpreter is named ONCE, and it is logged: when the spawn silently dies the
    // shell must be able to read which python and which directory it was asked for
    const py = process.env.RODD_PYTHON || path.join(process.env.HOME || '', 'venvs/s2s/bin/python');   // allow-home-default: the seat's own venv
    console.log('[rodd] ui server:', JSON.stringify(py), '-m uvicorn --app-dir', JSON.stringify(UI), 'port', port);
    const proc = execFile(
      py,
      ['-m', 'uvicorn', '--app-dir', UI, 'server:app', '--host', '127.0.0.1', '--port', String(port)],
      { env, cwd: UI, timeout: 0 },
      (err) => { if (err) console.error('[rodd] ui server exited:', err.message); },
    );
    proc.stderr.on('data', (d) => { try { fs.appendFileSync(path.join(app.getPath('temp'), 'rodd-uiserver.log'), d); } catch {} });
    const deadline = Date.now() + 30000;
    const wait = () => {
      const req = http.get({ host: '127.0.0.1', port, path: '/api/config', timeout: 1500 }, (res) => {
        res.resume();
        if (res.statusCode === 200) resolve({ port, proc });
        else retry();
      });
      req.on('error', retry);
      req.on('timeout', () => { req.destroy(); retry(); });
    };
    const retry = () => { if (Date.now() > deadline) reject(new Error('ui server did not answer')); else setTimeout(wait, 400); };
    setTimeout(wait, 600);
    app.on('before-quit', () => { try { proc.kill(); } catch {} });
  });
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
      'cd ~/ymir && ./bin/voice/voice-door.sh host'], { timeout: 240000 }, (err) => resolve(err ? String(err.message) : 'restarted'));
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

  const { port, proc } = await startUiServer();
  const win = new BrowserWindow({
    width: 1180, height: 820, title: 'Rödd',
    backgroundColor: '#0e0c09',
    autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, sandbox: true },
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
      "You also have ls, read, edit and bash, and mcp (chrome-devtools drives the browser, well and the",
      "board hold the record). edit, bash and any mcp call that can write ask him out loud first and run",
      "only on his yes; a destructive command is refused outright — say so, never work around it.",
      "For how many agents are working or where the work is, call seats (it reads the herdr panes) and",
      "pane_read or seats(pane=…) for one of them — errand_state knows only this seat's own errands.",
      "sessrumnir says whether the desktop seat is up and what its workspaces hold; you cannot post into",
      "its conversations yet, and you say so.",
      "Never claim a merge, a push, a sent mail or a changed board unless a tool returned it; the vault is",
      "closed to you and you say so.",
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
});

app.on('window-all-closed', () => app.quit());
