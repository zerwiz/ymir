# odrerir · 2026-09-24 — the hall board returns, the raise buttons open, the plans wear the tickets' skin

## Why
Three failures the Allfather met at the newborn hall's first look:
1. **No way back to the hall** — the rebuild dropped the `/` board (the
   livehall) with Astro; tickets and plans were the only doors, and the hall
   was unreachable.
2. **The raise buttons did nothing** — the SPA fetched the Hlidskjalf gate
   cross-origin (`:4322 → :3889`) with no CORS and no proxy, so every POST was
   silently blocked in the browser.
3. **The plans did not look like the tickets** — a bare list, no status
   badges, no inline +new panel, so the ONE-anatomy law read as two designs.

## What
- **`LivehallBoard` (new)** — the hall board, default view at `#/`: reads
  `/livehall.json` (tally · smiths · the dealt call with a "deal the next"
  button · the ledger columns), fail-closed when the snapshot is absent; a 30s
  refresh. The topbar doors are now the board · the tickets · the plans.
- **The raise hinge**: the vite config proxies `/api` to the gate
  (`ODRERIR_GATE`, default `http://127.0.0.1:3889`) in dev AND preview;
  `raiseHall` POSTs `/api/desktop` same-origin with
  `x-ymir-surface: desktop` when the seat is a desktop one — the local seat is
  trusted, no CORS wall.
- **The plans wear the tickets' skin**: shared `src/board.ts` (one status
  palette + the badge renderer), state badges in the table, the +new plan door
  revealing an inline panel like the tickets' +new, the same shells.

## Verified
- `tsc --noEmit` + `vite build` green.

## Files
- `apps/odrerir/src/components/LivehallBoard.tsx` (new)
- `apps/odrerir/src/App.tsx` · `apps/odrerir/src/board.ts` (new)
- `apps/odrerir/src/components/PlansBoard.tsx` · `apps/odrerir/src/hall.css`
- `apps/odrerir/vite.config.ts`
- `.agents/skills/galdr-ymirsystem/assets/odrerir-hall.md`