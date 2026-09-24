# Óðrerir — the Live Hall (apps/odrerir) reference

Purpose: the complete reference for **Óðrerir**, the Ymir fleet's planning glass —
the carved board that reads the machine's real state and renders it read-only:
the tally of the hall, the armed errands dealt one slate at a time, the smiths and
their states, the tickets and the plans.

> The hall is its **own app** under `apps/odrerir`, **built as a Hlidskjalf-type
> app since 2026-09-24 (plan 55)** — React + Vite + TS, the ember hearth, the
> translucent panels, and the halls buttons in the same design as the high seat.
> It was an Astro static board before, and it is one no longer. It keeps its
> **own** Electron window (`--view odrerir`) and its own port `:4322`, so it
> never stacks with Hlidskjalf or Smíðja.

---

## 1. What the hall is

| Thing | Value |
|---|---|
| Norse figure | **Óðrerir** — the cauldron of the mead of poetry, poured live |
| App home | `apps/odrerir` |
| Tech | React 19 + Vite 6 + TS (mirrors `apps/hlidskjalf`; `main` → `electron/main.cjs`) |
| Cloth | the canonical `midgard/design-system/tokens.css` + the hearth (`midgard/design-system/ember.js`, carried in-repo) |
| Boards | the tickets + plans, BOTH in the tickets anatomy (table · filters · bulk · +new · detail sheet); Skuld MCP over the tailnet door |
| Port | `:4322` (env `ODRERIR_PORT`) |
| Public face | `https://hall.ymir.zerwiz.org` (production) |
| Desktop app | `ymir-odrerir` — its own Electron shell, own icon, own `.desktop` |

The SPA (`src/App.tsx` → the EmberBackground + the topbar with the halls
buttons → the boards) builds to `dist/`. The boards read the **Skuld MCP at
`whynot.tailefab81.ts.net:8320`** — a fleet MCP is addressed by TAILNET NAME,
never a LAN IP (the 2026-09-24 law; a LAN address draws HTTP 000 from the
other seats).

## 2. Raising the hall

### 2.1 With the whole stack

`scripts/start.sh` raises it in its own stanza (before the Hlidskjalf SPA so a
window never waits):

```
scripts[1]{command,result}:
  "scripts/start.sh","Óðrerir — Live Hall raised (pid <pid>) → http://127.0.0.1:4322/"
```

- If `apps/odrerir/node_modules` is missing it installs once (workspace-aware:
  the root `npm install` hoists; vite arrives by the P3 law).
- A packaged app ships `dist/` and is served with
  `npx --no-install vite preview --port :4322`; a clone runs `npm run dev`.
- Liveness is tracked by `.run/odrerir.pid`, logs to `.run/odrerir.log`.
- Idempotent: already running → "already running" line, no double spawn.
- Missing app dir → `Óðrerir — Live Hall skipped (missing apps/odrerir).`

### 2.2 Standalone (working on the hall itself)

```
hall-dev[4]{command,when}:
  "cd apps/odrerir && npm run dev","hack + watch (vite dev server on :4322)"
  "cd apps/odrerir && npm run build","tsc --noEmit && vite build into dist/"
  "cd apps/odrerir && npm run preview","serve the built dist for a look"
  "cd apps/odrerir && npm run typecheck","tsc --noEmit"
```

`npm install` is required once (`--no-audit --no-fund`).

### 2.3 Its own window

`scripts/electron.sh start --view odrerir` opens the hall in its **own** Electron
app:

```
odrerir[4]{aspect,detail}:
  "identity","ymir-odrerir (class, .desktop, user-data-dir, single-instance lock)"
  "URL","http://127.0.0.1:4322/ (own window, never hosted inside Hlidskjalf)"
  "pid","state/electron-odrerir.pid; log state/electron-odrerir.log"
  "menu","Reload / DevTools / quit (own app menu — no cross-app Sign out)"
```

The hall's Electron binary is resolved by `bin/electron-lib.sh` (one resolver,
app-local → hoisted → sibling); the app directory passed to Electron is
`apps/odrerir` (its `package.json` `main` → `electron/main.cjs`). The hall has
**no** gate session — a Sign-out link is never shown.

## 3. The boards

- **Tickets** (`src/components/TicketsBoard.tsx`) — the hall's book (plan 43):
  the filterable table (status · priority · assignee) with bulk power and a
  +new door; pressing a row opens the detail sheet with the stat-strip, the
  state march, the assignee's pick and the comments thread. Tools over Skuld:
  `tickets/list|get|create|update`, `comments/list|post`.
- **Plans** (`src/components/PlansBoard.tsx`) — the roadmap, wearing the SAME
  anatomy: a filtered table (id · title · state · rides), a +new plan door
  whose ticket picker lists the living tickets, and a detail sheet with the
  plan's body and the tickets it rides. Tools: `plans/list|get|create`.
- **One layout, one law**: a plan's tickets must exist before the plan does.

## 4. Working on the hall — laws and gotchas

- **The halls buttons** (`src/App.tsx`, `HALLS`) are the high seat's control:
  they raise the other Ymir windows through the Hlidskjalf gate
  (`/api/desktop`). A quiet gate never breaks the board.
- **The cloth is the canonical import**: `src/hall.css` imports
  `midgard/design-system/tokens.css`; the hearth is the carried-in
  `midgard/design-system/ember.js`. No bespoke palette, no generated regions.
- **The Skuld door is env-overridable** (`VITE_SKULD_URL`), defaulting to the
  tailnet MagicDNS name — never a LAN IP (2026-09-24 law).
- **Ports are sacred:** `:4322` is Óðrerir's alone. Do not move it into a
  Hlidskjalf route or a launcher call — its door is its own window and its own
  topbar buttons.
- **Astro is gone**: no `src/index.html` verbatim page, no `.astro` pages, no
  `astro.config.mjs`, no `check:cloth` — anything that looks for them is
  looking at the old world.

## 5. Files you will touch

```
files[6]{path,what}:
  "apps/odrerir/src/App.tsx","the shell — hearth, topbar, halls buttons, hash views"
  "apps/odrerir/src/hall.css","the cloth: tokens import, glass panels, the boards' anatomy"
  "apps/odrerir/src/components/TicketsBoard.tsx","the hall's book — table · bulk · +new · detail"
  "apps/odrerir/src/components/PlansBoard.tsx","the roadmap — the same anatomy"
  "apps/odrerir/src/skuld.ts","the Skuld MCP client (tailnet door, session header)"
  "apps/odrerir/electron/main.cjs","the hall's own window (single instance, no session)"
```

Door plumbing that reaches the hall from other apps: `HALL_URL` in
`apps/hlidskjalf/src/data/metadata.ts` (`localhost|127.0.0.1` → `:4322`, else the
public hall), surface rules in `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`
("The Hall door" section), and `bin/hall-snapshot.sh` for the livehall feed if a
board ever needs it again. Everything the hall renders lives under
`apps/odrerir/`.
### The three doors + the raise hinge (2026-09-24, follow-up)
- `#/` is the **hall board** (`LivehallBoard`) — the livehall snapshot
  (`/livehall.json`: tally · smiths · the call · ledger), fail-closed when the
  snapshot is absent. `#/tickets`, `#/plans` are the boards; the topbar links
  are the board · the tickets · the plans.
- The **halls buttons** raise the other windows through the Hlidskjalf gate via
  the vite `/api` proxy (same-origin; `ODRERIR_GATE`, default
  `http://127.0.0.1:3889`) with the desktop-seat marker when the seat is one —
  a direct cross-origin POST is CORS-blocked and dies silent (fixed 2026-09-24).
- The plans board wears the tickets' skin exactly: the same status badges
  (`src/board.ts` — one palette), the same inline +new panel, the same table.
