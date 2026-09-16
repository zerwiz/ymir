// Hlidskjalf — Electron shell. Odin's high seat as a desktop app.
//
// Raises the stack if it is down, then opens the control plane (Hlidskjalf) and
// the smithy's visualizer (Smiðja) as app surfaces. The web app stays the UI;
// this is the native window and menu around it.
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
const HLIDSKJALF = localOnly(process.env.HLIDSKJALF_URL || 'http://127.0.0.1:3888/', 'http://127.0.0.1:3888/');
const SMIDJA = localOnly(process.env.SMIDJA_URL || 'http://127.0.0.1:8437/', 'http://127.0.0.1:8437/');
// The gate is the one identity: signing out here clears the shared session for
// every Ymir surface (Hlidskjalf, Smiðja, Sessrúmnir).
const GATE = process.env.YMIR_GATE_URL || 'http://127.0.0.1:3889';

// One window, one app identity: Hlidskjalf and Smíðja are separate desktop
// apps so they never stack in the taskbar and each carries its own icon.
const VIEW = (process.env.YMIR_DESKTOP_VIEW ?? 'hlidskjalf').toLowerCase();
const IS_SMIDJA = VIEW === 'smidja';
const APP_NAME = IS_SMIDJA ? 'Ymir · Smíðja' : 'Ymir · Hlidskjalf';
const APP_SLUG = IS_SMIDJA ? 'ymir-smidja' : 'ymir-hlidskjalf';
const ICON = path.join(__dirname, IS_SMIDJA ? 'smidja-icon.png' : 'icon.png');

app.setName(APP_SLUG);
if (process.platform === 'linux') {
  // Wayland/GNOME taskbar grouping + icon come from the matching .desktop file.
  app.setDesktopName(`${APP_SLUG}.desktop`);
  app.commandLine.appendSwitch('class', APP_SLUG);
}

let win = null;

// Single instance per app identity: a second launch focuses the existing
// window instead of opening a new one (this is what stacked windows on agent
// starts). Must run before app 'ready'.
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
let raised = false;

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

async function ensureStack() {
  if (await reachable(HLIDSKJALF)) return true;
  if (!raised) {
    raised = true;
    const script = path.join(ROOT, 'scripts', 'start.sh');
    const child = spawn('bash', [script], { cwd: ROOT, detached: true, stdio: 'ignore' });
    child.unref();
  }
  for (let i = 0; i < 40; i += 1) {
    await new Promise((r) => setTimeout(r, 1000));
    if (await reachable(HLIDSKJALF)) return true;
  }
  return false;
}

// Place the window on a NON-primary display when one exists, so the dashboards
// open on the Allfather's second screen and leave the primary for work. Falls
// back to the primary when only one monitor is attached (the common laptop
// case), and never goes off-screen. YMIR_DESKTOP_DISPLAY picks a display:
//   other (default) | primary | <index 0..n>
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

  // Two dashboards on two screens should not stack on the same one.
  const second = displays.filter((d) => d.id !== primary.id);
  const preferOther = want === 'other' || want === '';

  if (preferOther && second.length) {
    // Hlidskjalf takes the first secondary; Smíðja the next, or the first again.
    const idx = IS_SMIDJA ? Math.min(1, second.length - 1) : 0;
    return second[idx];
  }
  if (/^\d+$/.test(want)) {
    const d = displays[Number(want)];
    if (d) return d;
  }
  if (want === 'primary') return primary;
  return primary;
}

function centeredBounds(display) {
  // All geometry is LOGICAL (Electron's screen API): physical / scale. Omarchy
  // often uses a fractional scale (1920x1200 at 1.5 -> 1280x800 logical), so a
  // 1440-wide default would overflow a scaled laptop panel.
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
    backgroundColor: '#080c14',
    icon: ICON,
    title,
    autoHideMenuBar: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  win.loadURL(url);
  // The desktop header stays "Ymir" — never the current workspace/gate title.
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

// Sign out of the shared Ymir session: clear it at the gate, then reload so the
// login screen returns. One identity covers every surface.
async function signOut() {
  try {
    await fetch(`${GATE}/api/logout`, { method: 'POST' });
  } catch {
    /* gate down — the reload still drops the view */
  }
  for (const w of BrowserWindow.getAllWindows()) w.reload();
}

function buildMenu() {
  const template = [
    {
      label: 'Ymir',
      submenu: [
        { label: 'Ymir · Hlidskjalf', accelerator: 'CmdOrCtrl+1', click: () => win && win.loadURL(HLIDSKJALF) },
        { label: 'Smiðja — the smithy', accelerator: 'CmdOrCtrl+2', click: () => win && win.loadURL(SMIDJA) },
        { type: 'separator' },
        { label: 'Reload', accelerator: 'CmdOrCtrl+R', click: () => win && win.reload() },
        { label: 'DevTools', accelerator: 'CmdOrCtrl+Alt+I', click: () => win && win.webContents.toggleDevTools() },
        { type: 'separator' },
        { label: 'Sign out', click: () => { void signOut(); } },
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
  await ensureStack();
  if (VIEW === 'both') {
    // Back-compat only: one process for both windows shares one app identity,
    // so they stack. Prefer scripts/electron.sh --both, which starts two.
    openWindow(HLIDSKJALF, 'Ymir · Hlidskjalf');
    openWindow(SMIDJA, 'Ymir · Smíðja');
  } else {
    openWindow(IS_SMIDJA ? SMIDJA : HLIDSKJALF, APP_NAME);
  }
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      openWindow(IS_SMIDJA ? SMIDJA : HLIDSKJALF, APP_NAME);
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
