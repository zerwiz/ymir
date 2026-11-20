# odrerir · 2026-09-24 — the Live Hall is reborn as a Hlidskjalf-type app (plan 55)

## Why
The Allfather's word: rebuild Óðrerir as the **same app type as Hlidskjalf** —
not Astro anymore; the ember/translucent design; the halls buttons in the same
design. The hall was the one surface built differently (an Astro static board):
a second stack to maintain, no ember background, no translucent containers, no
halls buttons, and every UI change held hostage by the Astro build. The
plans-wears-tickets-layout errand is folded into the rebuild.

## What
- `apps/odrerir` becomes **React 19 + Vite 6 + TS**, mirroring
  `apps/hlidskjalf`'s shape: `package.json` (dev=vite, build=tsc&&vite build,
  prepack=build, `main` → `electron/main.cjs`), `vite.config.ts` (:4322,
  `base: './'`), `tsconfig.json`, `index.html`, `src/main.tsx` → `src/App.tsx`.
- **The shell is the high seat's cloth**: `src/hall.css` imports the canonical
  `midgard/design-system/tokens.css`, the hearth (`midgard/design-system/
  ember.js`, carried in-repo like the high seat's), translucent `panel`
  containers (backdrop blur), and the **halls buttons** (`HALLS` in `App.tsx`)
  that raise the other Ymir windows through the gate — same design.
- **The boards**: `TicketsBoard.tsx` (the book: filters · table · bulk · +new ·
  detail sheet with stat-strip · march · assignments · comments) and
  `PlansBoard.tsx` (the roadmap, wearing the SAME anatomy). Both read Skuld
  over the tailnet door (`whynot.tailefab81.ts.net:8320`, `VITE_SKULD_URL`
  overridable) — never a LAN IP (2026-09-24 MCP law). Hash views: `#/tickets`
  · `#/plans`.
- **The hinge stays**: port `:4322`, the raise stanza serves `dist/` via
  `vite preview` (vite is hoisted by the workspace-root install — the P3 law;
  a clone runs `npm run dev`), the electron window keeps `ymir-odrerir` and
  loads the SPA.
- **Astro leaves**: `src/index.html`, `src/pages/*.astro`, `src/scripts/`,
  `src/styles/{cloth,livehall}.css`, `astro.config.mjs`, `check:cloth` — gone.

## Verified
- `npm run build` green (tsc strict + vite build → `dist/`, 3.6M with the
  public assets).
- `npx --no-install vite preview` on `:4322` answers 200 and serves the SPA.

## Files
- `apps/odrerir/package.json` · `vite.config.ts` · `tsconfig.json` · `index.html`
- `apps/odrerir/src/{main.tsx,App.tsx,hall.css,skuld.ts,vite-env.d.ts}`
- `apps/odrerir/src/components/{EmberBackground,TicketsBoard,PlansBoard}.tsx`
- `apps/odrerir/midgard/design-system/{tokens.css,ember.js,ember.d.ts}`
- `scripts/start.sh` (odrerir stanza: vite, not astro; the stanza no longer
  names Astro) · `apps/odrerir/electron/main.cjs` (comment only)
- `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md` (rebuilt)