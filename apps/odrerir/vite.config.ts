import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

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

export default defineConfig({
  plugins: [react()],
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