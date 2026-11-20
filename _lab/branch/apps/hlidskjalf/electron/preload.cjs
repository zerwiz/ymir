// Minimal preload. The renderer is the web app; expose only what a desktop
// surface needs. Context isolation is on, node integration off.
const { contextBridge } = require('electron');

contextBridge.exposeInMainWorld('ymirDesktop', {
  platform: process.platform,
  desktop: true,
});
