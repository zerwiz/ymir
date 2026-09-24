import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Óðrerir — the Live Hall, built like the high seat. Ports are env-driven with
// the historic defaults (Rule 07): the window and every door know :4322.
const HALL_PORT = Number(process.env.ODRERIR_PORT ?? 4322);
const HALL_HOST = process.env.ODRERIR_HOST ?? '127.0.0.1';

export default defineConfig({
  plugins: [react()],
  base: './',
  server: {
    host: HALL_HOST,
    port: HALL_PORT,
    strictPort: false,
    fs: {
      // The canonical cloth lives at the repo root (midgard/design-system).
      allow: ['..', '../..', '../../..'],
    },
  },
  preview: {
    host: HALL_HOST,
    port: HALL_PORT,
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});