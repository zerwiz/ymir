// Bilskirnir — the business hall, as a desk app.
//
// The hall is a web face served by its own server (apps/bilskirnir/server). This shell gives it what
// every other Ymir app has: a window of its own in the launcher, the bronze Ymir mark, the stable
// title "Bilskirnir", one process to open and close.
//
// It does NOT raise the server or Nanna's gateway. That is start.sh's business, in the one order
// that works (gateway → server → window). A window that claimed to host a hall it did not raise
// would be a lie told in pixels — so when the hall does not answer, the window says so in a
// sentence and names the command that raises it.
//
// Settings (RULES/07), each with one documented default:
//   BILSKIRNIR_URL           the hall to open                 (http://127.0.0.1:8787)
//   BILSKIRNIR_BOOT_TIMEOUT  seconds to wait for it to answer (30)

const { app, BrowserWindow, Menu, shell } = require('electron');
const http = require('node:http');
const path = require('node:path');

const URL_ = (process.env.BILSKIRNIR_URL || 'http://127.0.0.1:8787').replace(/\/+$/, '');
const BOOT_TIMEOUT_MS = Number(process.env.BILSKIRNIR_BOOT_TIMEOUT || 30) * 1000;
const ICON = path.join(__dirname, 'icon.png');

// one name everywhere: the title is Bilskirnir; the window class the launcher groups by is the package
// name, ymir-bilskirnir (on Wayland that is the app id; the .desktop entry's StartupWMClass matches it)
app.setName('Bilskirnir');

function answers() {
  return new Promise((resolve) => {
    const req = http.get(`${URL_}/api/health`, { timeout: 1500 }, (res) => { res.resume(); resolve(res.statusCode === 200); });
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
  });
}

// set once the app is on its way out: every wait and every late call on the window gives up
let quitting = false;
let win = null;

async function waitForHall() {
  const deadline = Date.now() + BOOT_TIMEOUT_MS;
  while (!quitting && Date.now() < deadline) {
    if (await answers()) return true;
    await new Promise((r) => setTimeout(r, 500));
  }
  return false;
}

function silentHall() {
  const esc = (s) => String(s).replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  return `<!doctype html><meta charset="utf-8"><title>Bilskirnir</title>
<body style="margin:0;height:100vh;display:flex;align-items:center;justify-content:center;background:#0e0c09;color:#cfc3a9;font:15px/1.5 system-ui,sans-serif">
<div style="max-width:440px;padding:24px;text-align:center">
<p style="font-size:18px;color:#c9973f;margin:0 0 12px">The hall is silent.</p>
<p style="margin:0 0 16px">Nothing answered at <code>${esc(URL_)}</code> within ${Math.round(BOOT_TIMEOUT_MS / 1000)} seconds.</p>
<p style="margin:0;color:#9a8f75">Raise it with <code>apps/bilskirnir/start.sh</code>, then open the window again.</p>
</div></body>`;
}

async function open() {
  win = new BrowserWindow({
    width: 1280, height: 820, minWidth: 360, minHeight: 560,
    title: 'Bilskirnir',
    icon: ICON,
    backgroundColor: '#0e0c09', // the cloth's ground, so the window never flashes white
    autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, sandbox: true },
  });
  // the page's own <title> must not rename the window: it is Bilskirnir, whatever room is open
  win.on('page-title-updated', (e) => e.preventDefault());
  // the window is gone the moment it closes: drop the handle so nothing touches a destroyed object
  win.on('closed', () => { win = null; });
  const w = win;
  // links that leave the hall open in the browser, never inside the shell
  w.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith(URL_)) return { action: 'allow' };
    shell.openExternal(url);
    return { action: 'deny' };
  });
  const up = await waitForHall();
  // closed while waiting for the hall: loading into a destroyed window is what aborted the shell
  if (quitting || w.isDestroyed()) return;
  try {
    if (up) await w.loadURL(URL_);
    else await w.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(silentHall()));
  } catch (err) {
    // a load interrupted by a close is an ending, not a fault
    if (!quitting && !w.isDestroyed()) console.error('bilskirnir: load failed:', err && err.message);
  }
}

Menu.setApplicationMenu(null);
app.whenReady().then(open);

// One road out: every ending goes through app.quit(). This shell raises no backend of its own (start.sh
// owns the gateway and the server), so there are no child processes to reap — the window is the only thing
// that must be let go of cleanly.
app.on('before-quit', () => {
  quitting = true;
  if (win && !win.isDestroyed()) win.destroy();
});
app.on('window-all-closed', () => app.quit());
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => app.quit());
