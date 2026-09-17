# Óðrerir — the Live Hall (apps/odrerir) reference

Purpose: the complete reference for **Óðrerir**, the Ymir fleet's planning glass —
the carved board that reads the machine's real state and renders it read-only:
the tally of the hall, the armed errands dealt one slate at a time, the smiths and
their states, and the carved ledger of what is underway, landed, and charted.

> The hall is its **own app** under `apps/odrerir` (an Astro board), separate from
> the landing page it once lived beside (`~/CodeP/ymir-homepage`, migrated
> 2026-09-15). The Allfather's word: only the hall came into the tree, not the
> landing. It has its **own** Electron window (`--view odrerir`), so it never
> stacks with Hlidskjalf or Smíðja.

---

## 1. What the hall is

| Thing | Value |
|---|---|
| Norse figure | **Óðrerir** — the cauldron of the mead of poetry, poured live |
| App home | `apps/odrerir` |
| Tech | Astro (static output) + a `verbatim-hall` integration |
| Port | `:4322` (env `ODRERIR_PORT`, config `server.port`) |
| Feed | `public/livehall.json` — written by `bin/hall-snapshot.sh` |
| Public face | `https://hall.ymir.zerwiz.org` (production) |
| Desktop app | `ymir-odrerir` — its own Electron shell, own icon, own `.desktop` |

The page (`src/index.html`) is served **verbatim**; assets are handed beside it.
Missing `livehall.json` is **not** a build failure — the board paints the saga's
own tale and says so.

## 2. Raising the hall

### 2.1 With the whole stack

`scripts/start.sh` raises it in its own stanza (before the Hlidskjalf SPA so a
window never waits):

```
scripts[1]{command,result}:
  "scripts/start.sh","Óðrerir — Live Hall raised (pid <pid>) → http://127.0.0.1:4322/"
```

- If `apps/odrerir/node_modules` is missing it `npm install`s once.
- Liveness is tracked by `.run/odrerir.pid`, logs to `.run/odrerir.log`.
- Idempotent: already running → "already running" line, no double spawn.
- Missing app dir → `Óðrerir — Live Hall skipped (missing apps/odrerir).`

### 2.2 Standalone (working on the hall itself)

```
hall-dev[4]{command,when}:
  "cd apps/odrerir && npm run dev","hack + watch (runs check:cloth first)"
  "cd apps/odrerir && npm run build","static build into dist/"
  "cd apps/odrerir && npm run preview","serve the built dist for a look"
  "cd apps/odrerir && npm run check:cloth","verify the cloth tokens are in step (warns+passes when the landing is absent)"
```

`npm install` is required once (`--no-audit --no-fund`). Astro is the only
dependency.

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

`--both` raises Hlidskjalf + Smíðja; Óðrerir is raised by its own `--view odrerir`
call. The hall's Electron binary is shared from `apps/hlidskjalf/node_modules`;
the app directory passed to Electron is `apps/odrerir` (its `package.json`
`main` → `electron/main.cjs`). The hall has **no** gate session — a Sign-out link
is never shown; the window is read-only chrome around a read-only board.

## 3. The planning feed — `bin/hall-snapshot.sh`

```
snapshot[1]{command,out}:
  "bin/hall-snapshot.sh","apps/odrerir/public/livehall.json (default)"
```

- Reads REAL system state: Runes tally, project registry, the Nornir loom (cron
  jobs), the wake queue, the herdr smiths (`odrerir` / `sessrumnir-cloth` /
  `hall-button`), the armed `when-*` errands, and the runes-ledger counts.
- **PUBLIC-SAFE BY LAW:** only Norse worker names, counts, and job ids — never a
  private name, path, secret, or command (the PLAN §12 gate). When the feed is
  stale the board says so rather than inventing state.
- Override the output with the first argument; override the home with
  `BROKK_ROOT_OVERRIDE`, the state dir with `BROKK_STATE_OVERRIDE`.

## 4. Working on the hall — laws and gotchas

- **Only the board lives here.** The landing page (`src/lore.html`, the site's
  prose) stays outside the tree. Any change that assumes the landing is beside
  the hall is wrong.
- **The cloth** (`src/styles/cloth.css`) carries a marked region
  (`/* >>> generated:tokens … >>> */` → `/* <<< generated:tokens <<< */`)
  extracted from the landing's `:root`. Standalone, `check:cloth` warns and
  passes — the locked copy is the source of truth for this app. Touching the
  region by hand breaks the check.
- **Snapshot freshness:** after adding an armed errand or a new smith, re-run
  `bin/hall-snapshot.sh` so the board shows it. The `verbatim-hall` integration
  serves `public/livehall.json` same-origin in dev and copies it into the build.
- **Ports are sacred:** `:4322` is Óðrerir's alone. Do not move it into a
  Hlidskjalf route or a launcher call — its door is a plain anchor in a new tab
  (`.hall-btn`, rune **ᛟ**, "To the Hall") and its own window.
- **`.astro/dev.json` is runtime state, never tracked.** Astro rewrites it on
  every start with the live `pid` and the host's own addresses (LAN + tailnet),
  so committing it leaks a private IP per run. It is gitignored; the generated
  types beside it (`content.d.ts`, `types.d.ts`) stay tracked.

## 5. Files you will touch

```
files[5]{path,what}:
  "apps/odrerir/src/index.html","the board's carved page (served verbatim)"
  "apps/odrerir/src/styles/cloth.css","the cloth (locked token region + board primitives)"
  "apps/odrerir/src/styles/livehall.css","the board kit"
  "apps/odrerir/astro.config.mjs","server port/host, verbatim-hall integration, asset slate"
  "apps/odrerir/electron/main.cjs","the hall's own window (single instance, no session)"
```

Door plumbing that reaches the hall from other apps: `HALL_URL` in
`apps/hlidskjalf/src/data/metadata.ts` (`localhost|127.0.0.1` → `:4322`, else the
public hall), surface rules in `.agents/skills/galdr-ymirsystem/assets/hlidskjalf-ui.md`
("The Hall door" section). Everything the hall renders lives only under
`apps/odrerir/`; nothing else in the tree is its feed but `bin/hall-snapshot.sh`.