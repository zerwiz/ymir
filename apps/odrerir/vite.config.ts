import { defineConfig, type Connect, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Óðrerir — the Live Hall, built like the high seat. Ports are env-driven with
// the historic defaults (Rule 07): the window and every door know :4322.
const HALL_PORT = Number(process.env.ODRERIR_PORT ?? 4322);
const HALL_HOST = process.env.ODRERIR_HOST ?? '127.0.0.1';
// The raise buttons open the other halls through the Hlidskjalf gate — but the
// gate is on :3889, a foreign origin to this SPA. The SAME-ORIGIN road is the
// vite proxy (the high seat uses it too): /api rides to the gate, and the
// local desktop seat is trusted. (2026-09-24 — a direct cross-origin POST is
// CORS-blocked and the buttons die silently.)
const GATE_ORIGIN = process.env.ODRERIR_GATE ?? 'http://127.0.0.1:3889';
const apiProxy = { '/api': GATE_ORIGIN };

const HERE = path.dirname(fileURLToPath(import.meta.url));

// THE HALL'S LIVE FEED, AT REQUEST TIME (plan 51 P9c doctrine: resolve at the
// request, never restate at build). The board reads `/livehall.json`;
// `bin/hall-snapshot.sh` writes `public/livehall.json` from the real system
// state (runes · projects · cron · wake · smiths), and ALSO `dist/livehall.json`
// whenever a dist/ exists. This plugin serves the public/ snapshot from disk on
// EVERY request, so in the CLONE shape (vite dev, or vite preview with this
// config) the feed is whatever the snapshot job last wrote. A packaged seat
// carries no vite.config.ts (the tarball ships dist/ · electron/ · README.md),
// so this plugin never runs there — and `vite preview` serves the dist/ file
// statically, which the snapshot job rewrites in place. Either way the served
// feed is the job's last write, not a build-time bake. No file → 404 → the
// board honestly keeps the saga's tale rather than inventing rows.
function livehallFeed(): Plugin {
  const snapshot = path.resolve(HERE, 'public/livehall.json');
  const serve: Connect.NextHandleFunction = (req, res, next) => {
    if ((req.url ?? '').split('?')[0] !== '/livehall.json') return next();
    try {
      const body = fs.readFileSync(snapshot);
      res.writeHead(200, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store' });
      res.end(body);
    } catch {
      res.writeHead(404, { 'content-type': 'application/json; charset=utf-8' });
      res.end('{}');
    }
  };
  return {
    name: 'ymir-livehall-feed',
    configureServer(server) {
      server.middlewares.use(serve);
    },
    configurePreviewServer(server) {
      server.middlewares.use(serve);
    },
  };
}

export default defineConfig({
  plugins: [react(), livehallFeed()],
  base: './',
  server: {
    host: HALL_HOST,
    port: HALL_PORT,
    strictPort: false,
    proxy: apiProxy,
    fs: {
      // The canonical cloth lives at the repo root (midgard/design-system).
      allow: ['..', '../..', '../../..'],
    },
  },
  preview: {
    host: HALL_HOST,
    port: HALL_PORT,
    proxy: apiProxy,
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});