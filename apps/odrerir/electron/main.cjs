// Óðrerir — Electron shell. The Live Hall as a desktop app.
//
// Raises the hall (the Astro board on :4322) if it is down, then opens it in
// its own native window. The board stays the UI; this is the window around it.
// One app identity of its own, so it never stacks with Hlidskjalf or Smíðja.
const { app, BrowserWindow, Menu, shell, screen } = require('electron');
const { spawn } = require('node:child_process');
const http = require('node:http');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..', '..');
// A desktop shell is a LOCAL seat: it never wears a tunnel. A non-loopback URL
// (a *.zerwiz.org hostname, say) is refused, not honoured - Cloudflare has no
// business inside an Electron window.
function localOnly(url, fallback) {
  try {
    const h = new URL(url).hostname;
    if (h === '127.0.0.1' || h === 'localhost' || h === '::1') return url;
  } catch { /* not a URL at all: fall through */ }
  console.warn('[ymir] refusing a non-local URL for a desktop shell: ' + url);
  return fallback;
}
const HALL = localOnly(process.env.HALL_URL || 'http://127.0.0.1:4322/', 'http://127.0.0.1:4322/');

// One window, one app identity: Óðrerir is its own desktop app so it never
// stacks in the taskbar and carries its own icon.
const APP_NAME = 'Ymir · Óðrerir';
const APP_SLUG = 'ymir-odrerir';
const ICON = path.join(__dirname, 'icon.png');

app.setName(APP_SLUG);
if (process.platform === 'linux') {
  app.setDesktopName(`${APP_SLUG}.desktop`);
  app.commandLine.appendSwitch('class', APP_SLUG);
}

let win = null;

// Single instance: a second launch focuses the existing window instead of
// opening a new one. Must run before app 'ready'.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (win && !win.isDestroyed()) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
  });
}

function reachable(url) {
  return new Promise((resolve) => {
    const req = http.get(url, (res) => {
      res.resume();
      resolve(res.statusCode >= 200 && res.statusCode < 500);
    });
    req.on('error', () => resolve(false));
    req.setTimeout(1500, () => {
      req.destroy();
      resolve(false);
    });
  });
}

async function ensureHall() {
  if (await reachable(HALL)) return true;
  // The hall is raised by the start script's service stanza; if that wasn't
  // run, ask it to bring every Ymir surface up rather than fight it here.
  const script = path.join(ROOT, 'scripts', 'start.sh');
  const child = spawn('bash', [script], { cwd: ROOT, detached: true, stdio: 'ignore' });
  child.unref();
  for (let i = 0; i < 40; i += 1) {
    await new Promise((r) => setTimeout(r, 1000));
    if (await reachable(HALL)) return true;
  }
  return false;
}

function targetDisplay() {
  let displays = [];
  try {
    displays = screen.getAllDisplays();
  } catch {
    return null;
  }
  if (!displays.length) return null;
  const primary = (() => {
    try {
      return screen.getPrimaryDisplay();
    } catch {
      return displays[0];
    }
  })();
  const want = (process.env.YMIR_DESKTOP_DISPLAY || 'other').toLowerCase();
  const second = displays.filter((d) => d.id !== primary.id);
  if ((want === 'other' || want === '') && second.length) return second[0];
  if (/^\d+$/.test(want)) {
    const d = displays[Number(want)];
    if (d) return d;
  }
  if (want === 'primary') return primary;
  return primary;
}

function centeredBounds(display) {
  const wantW = 1440;
  const wantH = 900;
  if (!display) return { width: wantW, height: wantH };
  const wa = display.workArea || display.bounds;
  const w = Math.max(800, Math.min(wantW, wa.width));
  const h = Math.max(600, Math.min(wantH, wa.height));
  const x = Math.round(wa.x + (wa.width - w) / 2);
  const y = Math.round(wa.y + (wa.height - h) / 2);
  return { width: w, height: h, x, y };
}

function openWindow(url, title) {
  // Never stack: reuse the window we already have.
  if (win && !win.isDestroyed()) { if (win.isMinimized()) win.restore(); win.focus(); return win; }
  const bounds = centeredBounds(targetDisplay());
  win = new BrowserWindow({
    ...bounds,
    minWidth: 800,
    minHeight: 600,
    backgroundColor: '#0e0c09',
    icon: ICON,
    title,
    autoHideMenuBar: false,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  win.loadURL(url);
  win.on('page-title-updated', (e) => e.preventDefault());
  win.webContents.setWindowOpenHandler(({ url: u }) => {
    shell.openExternal(u);
    return { action: 'deny' };
  });
  win.on('closed', () => {
    win = null;
  });
  return win;
}

function buildMenu() {
  const template = [
    {
      label: 'Ymir',
      submenu: [
        { label: 'Reload', accelerator: 'CmdOrCtrl+R', click: () => win && win.reload() },
        { label: 'DevTools', accelerator: 'CmdOrCtrl+Alt+I', click: () => win && win.webContents.toggleDevTools() },
        { type: 'separator' },
        { role: 'quit' },
      ],
    },
    {
      label: 'View',
      submenu: [
        { role: 'zoomIn' },
        { role: 'zoomOut' },
        { role: 'resetZoom' },
        { type: 'separator' },
        { role: 'togglefullscreen' },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

app.whenReady().then(async () => {
  buildMenu();
  await ensureHall();
  openWindow(HALL, APP_NAME);
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) openWindow(HALL, APP_NAME);
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});