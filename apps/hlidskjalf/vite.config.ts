import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '127.0.0.1',
    port: 3888,
    strictPort: false,
    // Tunnelled hostnames (Cloudflare -> gate API -> vite) must be allowed or
    // Vite blocks them with "Blocked request. This host … is not allowed."
    // Keep hostnames in env (private); default to allowing any host on this
    // localhost-bound dev server rather than hardcoding an operator domain.
    allowedHosts: (() => {
      const list = (process.env.YMIR_ALLOWED_HOSTS ?? '').split(',').map((h) => h.trim()).filter(Boolean);
      return list.length ? list : true;
    })(),
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
