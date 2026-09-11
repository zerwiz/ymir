// Hlidskjalf — Electron shell. Odin's high seat as a desktop app.
//
// Raises the stack if it is down, then opens the control plane (Hlidskjalf) and
// the smithy's visualizer (Smiðja) as app surfaces. The web app stays the UI;
// this is the native window and menu around it.
const { app, BrowserWindow, Menu, shell } = require('electron');
const { spawn } = require('node:child_process');
const http = require('node:http');
const path = require('node:path');

const ROOT = path.resolve(__dirname, '..', '..', '..');
const HLIDSKJALF = process.env.HLIDSKJALF_URL || 'http://127.0.0.1:3888/';
const SMIDJA = process.env.SMIDJA_URL || 'http://127.0.0.1:8437/';

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

function openWindow(url, title) {
  win = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 960,
    minHeight: 640,
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
