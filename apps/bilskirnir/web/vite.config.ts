import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { fileURLToPath } from 'node:url';

const API = process.env.GROKBOT_API ?? 'http://localhost:8787';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@shared': fileURLToPath(new URL('../server/src', import.meta.url)),
      // the house's design system: the cloth, the hearth, the mark (midgard/design-system)
      '@design': fileURLToPath(new URL('../../../midgard/design-system', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    strictPort: true,
    // the house cloth and the hearth live in the repo's design system, outside this folder
    fs: { allow: ['..', '../../..'] },
    proxy: {
      '/api': { target: API, changeOrigin: false, ws: true },
    },
  },
  // noVNC uses top-level await, so target ES2022+.
  build: { target: 'es2022', chunkSizeWarningLimit: 1200 },
});
