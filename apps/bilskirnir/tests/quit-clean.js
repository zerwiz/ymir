// Harness for tests/quit-clean.sh: loads the real shell, then closes its window shortly after it opens.
const { app } = require('electron');
app.on('browser-window-created', (_e, w) => setTimeout(() => { if (!w.isDestroyed()) w.close(); }, Number(process.env.QUIT_CLOSE_MS || 800)));
require('../electron/main.js');
