/**
 * factory trace UI — Electron shell.
 *
 * Loads the local visualizer (default http://localhost:8438, the Vite dev
 * server started by `just ui` / scripts/factory-ui.sh) in a native maximized
 * window, so wide per-agent lanes and diagrams fit on screen.
 *
 *   electron .                                  # open the UI
 *   FACTORY_UI_URL=http://localhost:8438 electron . # point elsewhere
 *
 * Cross-platform: Linux/macOS manage it with scripts/factory-electron.sh
 * (start|stop), Windows with scripts/factory-electron.ps1.
 *
 * The native frame is hidden (it follows the light system theme) and the
 * app's own dark topbar becomes the title bar, with window controls that talk
 * back over IPC. The taskbar/dock icon is wired per-OS: .desktop file +
 * app_id on Linux, AppUserModelId + window icon on Windows, dock icon on macOS.
 */
const { app, BrowserWindow, shell, ipcMain, nativeTheme } = require("electron");
const { join } = require("node:path");

const UI_URL = process.env.FACTORY_UI_URL || "http://localhost:8438";

// Force Chromium/GTK chrome to dark so nothing paints white around the page.
nativeTheme.themeSource = "dark";
app.setName("factory Trace UI");
if (process.platform === "linux") {
  // Ties the window to the installed .desktop launcher, so the compositor
  // (GNOME/Wayland app_id, X11 WM_CLASS) shows our icon in the taskbar
  // instead of the generic electron one.
  app.setDesktopName("factory-trace-ui.desktop");
}
if (process.platform === "win32") {
  // Windows taskbar groups/labels windows by AppUserModelId — set it to our
  // own id (must happen before 'ready') so the window gets its own icon.
  app.setAppUserModelId("factory-trace-ui");
}

// Window controls: the renderer's topbar buttons arrive here over IPC.
ipcMain.on("win:minimize", (event) => {
  BrowserWindow.fromWebContents(event.sender)?.minimize();
});
ipcMain.on("win:maximize", (event) => {
  const win = BrowserWindow.fromWebContents(event.sender);
  if (!win) return;
  if (win.isMaximized()) {
    win.unmaximize();
  } else {
    win.maximize();
  }
});
ipcMain.on("win:close", (event) => {
  BrowserWindow.fromWebContents(event.sender)?.close();
});

function createWindow() {
  const win = new BrowserWindow({
    title: "factory Trace UI",
    width: 1600,
    height: 1000,
    minWidth: 900,
    minHeight: 600,
    show: false,
    autoHideMenuBar: true,
    backgroundColor: "#0B0F18",
    icon: join(__dirname, "icon.png"),
    // No native frame: it follows the system's light theme and would show
    // white. The app's dark topbar is the title bar instead (drag region +
    // window controls). Windows/macOS draw native overlay controls; Linux
    // renders the topbar's own buttons (see preload.js / the Vue app).
    titleBarStyle: "hidden",
    ...(process.platform !== "linux"
      ? { titleBarOverlay: { color: "#0B0F18", symbolColor: "#FFFFFF", height: 48 } }
      : {}),
    webPreferences: {
      preload: join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });

  win.loadURL(UI_URL);

  // macOS puts its native traffic lights on the left by default; keep them on
  // the right to match the rest of the UI's controls.
  const placeTrafficLights = () => {
    if (process.platform !== "darwin") return;
    const { width } = win.getContentBounds();
    win.setTrafficLightPosition({ x: width - 80, y: 17 });
  };

  // Maximize on first paint so wide lanes/diagrams get the full screen.
  win.once("ready-to-show", () => {
    win.maximize();
    win.show();
    placeTrafficLights();
  });

  if (process.platform === "darwin") {
    win.on("resize", placeTrafficLights);
    win.on("maximize", placeTrafficLights);
  }

  // Anything that wants a new window (external links) goes to the system
  // browser instead of spawning an empty window inside the app.
  win.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: "deny" };
  });

  // Keep the trace flowing: Cmd/Ctrl+R reloads against the running servers.
  win.webContents.on("before-input-event", (event, input) => {
    if ((input.control || input.meta) && input.key.toLowerCase() === "r") {
      event.preventDefault();
      win.webContents.reload();
    }
  });
}

app.whenReady().then(() => {
  // macOS: dev builds run the bare Electron binary, so set the dock icon
  // explicitly (packaged .app bundles get theirs from the bundle's icns).
  if (process.platform === "darwin") {
    app.dock.setIcon(join(__dirname, "icon.png"));
  }

  createWindow();

  // macOS: re-create the window when the dock icon is clicked.
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  // Quit on Linux/Windows when the window closes; stay alive on macOS until
  // the app is explicitly quit.
  if (process.platform !== "darwin") app.quit();
});