import { defineConfig } from 'astro/config';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

// Óðrerir — the Live Hall. Its own deck: the carved page (src/index.html) is
// served verbatim, exactly as the landing serves its own, and its assets are
// handed back beside it:
//
//   /styles/cloth.css    the cloth (tokens extracted from the landing's :root)
//   /styles/livehall.css the board kit
//   /livehall.json       the planning snapshot — the hall's OWN generator
//                        (the Ymir tree's bin/hall-snapshot.sh) writes it into
//                        this repo's public/, and the glass reads it same-origin.
//                        Absent, the page paints the saga's own tale and says so;
//                        the build therefore never fails on a missing snapshot.
//
// Everything else in public/ (the icons, the og image) is copied by Astro.
const page = fileURLToPath(new URL('./src/index.html', import.meta.url));
const assets = [
  ['/styles/cloth.css', fileURLToPath(new URL('./src/styles/cloth.css', import.meta.url)), 'text/css', true],
  ['/styles/livehall.css', fileURLToPath(new URL('./src/styles/livehall.css', import.meta.url)), 'text/css', true],
  ['/livehall.json', fileURLToPath(new URL('./public/livehall.json', import.meta.url)), 'application/json', false],
];

const read = async (file) => {
  try {
    return await readFile(file);
  } catch {
    return null;
  }
};

/** @type {import('astro').AstroIntegration} */
const verbatimHall = {
  name: 'verbatim-hall',
  hooks: {
    'astro:server:setup': ({ server }) => {
      server.middlewares.use(async (req, res, next) => {
        const asset = assets.find(([route]) => req.url === route);
        if (asset) {
          const body = await read(asset[1]);
          if (!body) return next();
          res.setHeader('content-type', asset[2] + '; charset=utf-8');
          res.end(body);
          return;
        }
        if (req.url !== '/' && req.url !== '/index.html') return next();
        try {
          res.setHeader('content-type', 'text/html; charset=utf-8');
          res.end(await readFile(page));
        } catch (err) {
          next(err);
        }
      });
    },
    'astro:build:done': async ({ dir }) => {
      await mkdir(fileURLToPath(new URL('styles/', dir)), { recursive: true });
      for (const [route, file, , required] of assets) {
        const body = await read(file);
        if (!body) {
          if (required) throw new Error(`livehall: missing required asset ${file}`);
          console.warn(`livehall: no snapshot at ${file} — the page will paint the saga's own tale`);
          continue;
        }
        await writeFile(new URL('.' + route, dir), body);
      }
      await mkdir(fileURLToPath(dir), { recursive: true });
      await writeFile(new URL('index.html', dir), await readFile(page));
    },
  },
};

// The Hall's deck — its own origin, its own port; the landing keeps :4321.
export default defineConfig({
  site: 'https://hall.ymir.zerwiz.org',
  output: 'static',
  integrations: [verbatimHall],
  server: { host: true, port: 4322 },
});
