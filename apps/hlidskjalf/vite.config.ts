import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '127.0.0.1',
    port: 3888,
    strictPort: false,
    proxy: {
      // The local gate API (apps/hlidskjalf/server) reading the Brokk runtime.
      '/api': 'http://127.0.0.1:3889',
    },
    fs: {
      // Allow importing the canonical design tokens from midgard/.
      allow: ['..', '../..', '../../..'],
    },
  },
  preview: {
    host: '127.0.0.1',
    port: 3888,
    proxy: {
      '/api': 'http://127.0.0.1:3889',
    },
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});
