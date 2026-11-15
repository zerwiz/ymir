/**
 * Preload bridge for the smidja desktop shell.
 *
 * Runs with contextIsolation, so the only surface exposed to the page is the
 * `smidjaDesktop` handle below — the topbar uses it to (a) know it is running in
 * the desktop window and (b) drive the custom window controls (min/max/close),
 * since the native frame is hidden for a dark title bar.
 */
const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("smidjaDesktop", {
  isDesktop: true,
  // Custom window controls are only needed where the native frame is fully
  // hidden — Linux. Windows/macOS draw native overlay buttons instead.
  platform: process.platform,
  // ...and only where the PLATFORM wants them at all: on a tiling compositor
  // (Hyprland, Omarchy's session) the compositor tiles and closes with keys, so
  // the topbar draws no _ □ × (the Allfather, 2026-11-14). The answer is
  // bin/host/host-sense.sh's, resolved in main and asked for here.
  windowButtons: Boolean(ipcRenderer.sendSync("ymir:window-buttons")),
  windowControl(action) {
    ipcRenderer.send(`win:${action}`);
  },
});