import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';

const API = process.env.GROKBOT_API ?? 'http://localhost:8787';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@shared': fileURLToPath(new URL('../server/src', import.meta.url)),
      // the house's design system: the cloth, the hearth, the mark — the app's own byte-identical copies of
      // midgard/design-system (src/design/), so it builds in its own repo, where a climb into Ymir finds nothing
      // (the split, 2026-11-19; Ymir's bin/apps/tests/test_shared_copies.py keeps them equal to the source)
      '@design': fileURLToPath(new URL('./src/design', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    strictPort: true,
    // the server's shared types are one folder up (../server); nothing outside the app is reached
    fs: { allow: ['..'] },
    proxy: {
      '/api': { target: API, changeOrigin: false, ws: true },
    },
  },
  // noVNC uses top-level await, so target ES2022+.
  build: { target: 'es2022', chunkSizeWarningLimit: 1200 },
});
