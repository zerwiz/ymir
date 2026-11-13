/* Ymir — app-shell service worker. Network-first for navigations, cache-first
   for hashed assets; the gate API is always network-only. */
const CACHE = 'ymir-shell-v2';
const SHELL = ['/', '/index.html', '/manifest.webmanifest', '/ymir-mark.svg', '/ymir-icon.png', '/og.jpg'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  // plan 275 (2026-11-12): an update must never be served yesterday's files — every older cache is dropped
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== location.origin) return;
  if (url.pathname.startsWith('/api/')) return; // gate API: network only
  if (req.mode === 'navigate') {
    e.respondWith(
      fetch(req)
        .then((res) => {
          caches.open(CACHE).then((c) => c.put('/index.html', res.clone()));
          return res;
        })
        .catch(() => caches.match('/index.html')),
    );
    return;
  }
  // cache-first ONLY for the build's hashed files (/assets/<name>-<hash>.js): their name changes with every build.
  // Anything else (a dev server's /src or /node_modules/.vite path, an icon, a JSON feed) goes to the network, so a
  // file that changes under the same name is never served stale after an update.
  if (!url.pathname.startsWith('/assets/')) return;
  e.respondWith(
    caches.match(req).then(
      (r) =>
        r ||
        fetch(req).then((res) => {
          if (res.ok) caches.open(CACHE).then((c) => c.put(req, res.clone()));
          return res;
        }),
    ),
  );
});
