# Hlidskjalf UI — working guide

Ymir's own surface (one of the three things Ymir owns: the UI, the runtime, A2A).
Load this when touching `apps/hlidskjalf`. The design contract is `docs/design.md`;
the tokens are the single source of truth.

## Surfaces

```
surfaces[6]{part,where,note}:
  "SPA",":3888 (vite) / built dist served by the gate","React app; gates: Fleet, Chat, Runes, …"
  "gate API",":3889 (bun apps/hlidskjalf/server/index.ts)","auth + /api/* + serves dist/; static types + caching"
  "login","in-app modal → /api/login → session cookie","user/pass from .env.local HLIDSKJALF_AUTH; Heimdall (oauth2-proxy) is the target"
  "register","in-app modal → /api/register → spends an invite code","bin/ymir-invite.sh mints a limited-use code when nothing is live; argon2id account in state/accounts.json (0600, gitignored)"
  "desktop","apps/hlidskjalf/electron/main.cjs + scripts/electron.sh","single instance + one window (never stack); see the ymir skill assets/desktop.md"
  "tunnel","gjallarhorn → your hostname → :3889","outbound only; `bin/gjallarhorn-tunnel.sh`"
```

Quick rules:

- **One login, one window** — no GitHub hop before Heimdall; auth stays in-window.
- **Gate API protects `/api/*`** and serves the SPA; 401 → `ymir:unauthorized`.
- **No secrets inline** — `HLIDSKJALF_AUTH` from `.env.local`.
- **Electron:** single-instance lock; `openWindow` reuses the live window.
- Raise/repair: `scripts/start.sh`; if the window is gone but ports answer, the
  shell must be restarted (backend ≠ window).

## Location & stack

- App: `apps/hlidskjalf` — **React 19 + Vite + TypeScript**, state via **Zustand**.
- Gate API: `apps/hlidskjalf/server/index.ts` — **Bun + `bun:sqlite`**, read-only,
  bound to the runtime and the smithy trace; Vite proxies `/api` → `:3889`.
- Raise everything with the scripts (do not hand-start each process):

```bash
scripts/start.sh    # SPA :3888 · gate API :3889 · Smíðja visualizer :8437 · Nornir cron · Bifrost bridge
scripts/stop.sh     # lower them all
```

- Verify: `npm run typecheck` (`tsc --noEmit`) and `npm run build` must both be green.
- Headless check: render with Playwright/Chrome and assert **0 console errors**.

## Tokens — never hardcode colour

- Canonical tokens: `midgard/design-system/tokens.css`, imported once in
  `src/main.tsx` (Vite `server.fs.allow` grants access outside the app root).
- Style with CSS variables only (`var(--ymir-cyan-1)`, `var(--ymir-bg-2)`, …).
  **Never** write a raw hex in a component or a stylesheet — add a token instead.
- The active **accent** is driven by `--realm-tint` / `--realm-tint-2` /
  `--realm-tint-dim` on `:root`, set per realm via `data-realm` and overridable by
  the user (`state/store.ts` → `applyAccent`). Tenant overrides live in
  `tenantColors`.
- **Fonts** are the cloth's three faces, loaded from Google Fonts in `index.html`:
  Cormorant (display/runes), Newsreader (body), IBM Plex Mono (data), with Noto
  Sans Runic appended to every stack so a rune glyph falls through to the rune
  family.

### The cloth (2026-09-13)

The token *values* are the **carved cloth of the halls** — the landing page's own
palette (`CodeP/ymir-homepage/src/lore.html` `:root`; the hall carries its own
locked copy at `apps/odrerir/src/styles/cloth.css`), so Hlidskjalf, Smíðja and
Sessrúmnir are one look (`docs/design.md` §0/§4.2 is the contract):

```
canvas   bg-0 #0e0c09 · bg-1 #151209 · bg-2 #1a1610 · bg-3 #221d14   (stone)
accent   cyan-1 #c9973f bronze · cyan-2 #7d5f2a bronze-deep
         violet-1 #96a0a8 steel · violet-2 #5f686e steel-dim
lines    steel-1 #2b241a (line) · steel-2 #7d5f2a (brass rule) · chisel #c9973f
text     text-0 #cfc3a9 bone · text-1 rgba(207,195,169,.82) · text-2 #9a8f75 · text-3 #6b6250
state    ok #96a0a8 steel · warn #c9973f · danger #c2584a blood-lit · info #9a8f75
bevel    inset 0 0 0 1px rgba(201,151,79,.12)
```

Rules that hold it honest:

- **The cloth is the default, not a cage** — a user accent/background choice wins
  (`AccentPicker`), and the eight **house/domain seals keep their heraldry**
  (`DOMAINS`), exactly as the landing page keeps its house seals. Chrome is the
  cloth; heraldry is not chrome.
- The **workspace tints** are cloth too: `work` = bronze `#c9973f`, `personal` =
  steel `#96a0a8` (`src/data/realms.ts` → `WORKSPACES`, mirrored by the
  `data-realm` fallbacks in `styles/global.css`).
- The **Emblem** (`components/Emblem.tsx`, `midgard/design-system/ymir-mark.svg`)
  is brand, not cloth — it keeps its own colours on the stone.
- The login's GitHub button is a bone plate with a dark rune (the old white/navy
  literal is gone), and the `HallsChooser` cards read real tokens (they used to
  name two tokens that never existed, `--ymir-line`/`--ymir-panel`).
- Role-coloured literals in the stylesheets are now `color-mix(… var(--token) …)`,
  so a token change re-themes them.
- Geometry did not move: radius, spacing and the shell are unchanged by the cloth
  (the carved-slate squaring is still an open question).

## The shell (structural, do not redesign)

- `.shell` grid: `236px rail | 1fr`; rows `56px topbar · stage · stream`
  (the stream height is draggable, persisted in `streamHeight`).
- `.rail` (brand · gates · tenants · status), `.topbar` (realm chip · search ·
  accent · density · trace index · account), `main.stage` (the gate), `.stream`
  (Ratatoskr + Runes, pausable).
- Gates are **deep-linkable** and registered in `src/data/realms.ts` (`GATES`) and
  routed in `src/app/Shell.tsx`:
  `#/fleet` · `#/tasks` · `#/well` · `#/runes` · `#/reviews` · `#/processes` ·
  `#/files` · `#/chat` · `#/forge` · `#/profile` · `#/sessions` · `#/trace` ·
  `#/decisions` · `#/stats` · `#/cron` · `#/runtime`.

## Rules of the surface

1. **Color-only states are forbidden** — every status carries glyph + colour + text
   (`StatusChip`, `TaskChip`).
2. **Runecoded, not emoji** — use the rune family (runic glyphs fall through to
   Noto Sans Runic inside the Cormorant/mono stacks); never an emoji as an icon.
3. **Every button must act** — no dead controls. Wire to a state change, a modal, or
   a toast.
4. **Motion explains** — 120–240ms, no bounce; honour `prefers-reduced-motion`.
5. **Metrics are IBM Plex Mono, tabular** (`.mono`, `.tabular`).
6. **Metadata per page** — a gate declares its title/description/OG tags in
   `src/data/metadata.ts`; `Shell` applies them on gate/realm change.

## Interaction patterns (modal + toast)

- `src/state/ui.ts` exposes `useUI()` → `toast({kind,title,body})` and
  `openModal({variant,title,body,fields,content,onSubmit})`.
- `<Overlay/>` (mounted in `App`) renders the modal + toast host. Variants:
  `confirm`, `form` (fields), `info` (content block, e.g. a diff).
- Any consequential action **must** open a confirm/form modal, mutate the store,
  emit a rune (`pushStream`), and toast the outcome. Reference: `components/PRCard.tsx`
  (Seal / Request changes / View diff).
- Buttons get press feedback from `styles/overlays.css` (`translateY(1px) scale(.97)`).

## State & live data

- `src/state/store.ts` — session, realm, gate, accent, tenant colours, company,
  and data: agents, tasks, runes, stream, recall, processes, reviews, files, chat,
  skills, **smidja** (sessions/stats/decisions/db), **mimir**.
- **Live mode** loads the gate API (`loadLive`); every call degrades on its own and
  has a 10s timeout (`services/api.ts`). Smíðja loads on a **separate track**
  (`refreshSmidja`) so a slow endpoint (e.g. `/api/reviews`) cannot hold its gates
  hostage. `App` polls `refreshSmidja` every 5s.
- Realm switching is **granted**: `setRealm` refuses a realm the session has no
  grant. Tenant boundaries are sacred — never render another tenant's data.
- Persist user prefs to `localStorage` (`ymir.accent`, `ymir.tenant-colors`,
  `ymir.company.*`, `ymir.stream-height`).

## The gate API surface (`/api`, read-only)

`/api/health · /api/me · /api/workspace · /api/agents · /api/tasks · /api/runes ·
/api/well · /api/processes · /api/reviews · /api/files · /api/runtime · /api/cron ·
/api/loaders · /api/checks · /api/settings · /api/stream · /api/mimir …` plus the
smithy trace: `/api/smidja/{health,sessions,sessions/:id,decisions,stats}` and
chat: `/api/chat/history`, `POST /api/chat`.

`POST /api/chat` resolves the chosen model against the operator's Pi catalog and
tries **every** engine that advertises it (LM Studio `:1234`, the llama.cpp
router `:8080`, Bifrost `:4603`), never only the first — a dead engine falls
through to a live one. Recall reads `.agents/memory/well/episodes.jsonl`
directly, so restoring that file revives the chat's memory without a restart.

### The gate API reads cheaply (added 2026-09-16)

The gate reads append-only ledgers (Runes, the well's `episodes.jsonl`, masterplan
orders) and probes live runtime scripts on every request. Both grow without bound,
so the hot readers are memoised and the probes now run off the event loop:

- `runAsync()` — read-only subprocess probes via `Bun.spawn` (was `spawnSync`,
  which could block the single Bun event loop for up to 12s); results cached ~3s
  and concurrent callers share one in-flight spawn. Sync `run()` stays for
  **mutating** actions only (`setupRun`, `workspaceProvision`).
- `memo()` — `orders`, `runes`, `smidjaStats`, `chatRecall` are cached (2–3s), so a
  request never re-parses the whole ledger or well.

Measured: `/api/checks` 442ms → 4ms warm; `/api/runtime` 312ms → 5ms warm;
20 parallel `/api/runes` in 8ms.

**Ports are environment-driven.** The SPA (Vite) and the gate API read
`HLIDSKJALF_PORT` (default `3888`) and `HLIDSKJALF_API_PORT` (default `3889`);
`scripts/start.sh` passes the API port to the server as `PORT`, and the visualizer
uses `SMIDJA_VIZ_API_PORT`. A deployment should use 5-digit ports (the Quadlet/
Compose examples publish `38888`/`38889`/`54370`) to avoid colliding with other
services on a shared host; the defaults are unchanged for bare local dev. The SPA
bind host is `HLIDSKJALF_HOST` (default `127.0.0.1`); inside a container set it to
`0.0.0.0` so the published port reaches it, and pin the host-side publish to
`127.0.0.1` so the surface stays private.

## Smíðja in the UI

The smithy's trace (its own `smidja/smidja_data/smidja.db`) is rendered by four gates:

| Gate | Route | Reads |
|---|---|---|
| Sessions | `#/sessions` | every run, status, tokens/cost — **Open visualizer** + **Refresh** |
| Trace | `#/trace` | the selected run: phase lanes, events, agent sessions |
| Decisions | `#/decisions` | failures clustered by diagnosis/model |
| Stats | `#/stats` | token/cost breakdown, cache, providers |

**Open visualizer** opens `VISUALIZER_URL` (`src/data/metadata.ts`, default
`http://127.0.0.1:8437`) — Smíðja's own Vue trace UI, served by the smithy's Bun
API on the same port (`scripts/start.sh` raises it). Details: `assets/smidja.md`,
`docs/lore.md` §XIII.

## Agents, skills & mythological naming

- The Forge gate (`src/gates/Forge.tsx`) creates/edits **Eindri** and **skills**,
  and reads/edits the smithy's prompts. The skill list shows each skill's own
  text: the name + aett rune on the head row, and the description line
  underneath (`forge-item-desc`, dimmed until hover) — the description comes
  from the live `/api/skills` index, truncated to 240 chars by the gate API.
- Naming law: `src/data/mythology.ts` maps a craft/capability → the Norse figure
  whose myth matches it (smith→Sindri, skald→Bragi, sage→Huginn, judge→Tyr,
  forger→Brokk …). Skills take an **aett** prefix.
- New skills are validated in Utgard before production (Gungnir, W0007).

## Identity

- Mark: `midgard/design-system/ymir-mark.svg` (served `public/ymir-mark.svg`), used
  for login/rail logo and favicon. OG image: `public/og.png` (1200×630), source
  `public/og.svg`. Rebuild the PNG with headless Chrome if the SVG changes.

## The desktop apps (Electron)

`Hlidskjalf` and `Smíðja` each run as their own Electron app (`electron/main.cjs`,
launched by `scripts/electron.sh start --both`).

**Window placement.** The apps open on a **non-primary** display when one is
attached (the Allfather keeps the dashboards beside his work) and on the primary
otherwise. All geometry is in **logical** units — Electron's `screen` API returns
physical ÷ scale, and Omarchy commonly runs a fractional scale (e.g. a 1920×1200
panel at 1.5 is a 1280×800 logical desktop), so a 1440-wide default is clamped to
the work area rather than overflowing it. `YMIR_DESKTOP_DISPLAY` overrides the
choice: `other` (default) · `primary` · an index.

**Identity.** Never track an Electron app by the pid returned from
`.bin/electron` — that is a node shim which *spawns* the real binary, so the pid
is wrong and a second launch stacks on the first. Identify it by its own command
line (the per-view `--user-data-dir` is stable), which is what `electron.sh` does.

**GPU.** On a small-VRAM iGPU the Wayland `--type=gpu-process` can die with
`amdgpu: Not enough memory for command submission` (SIGSEGV, not an OOM).
`YMIR_DESKTOP_DISABLE_GPU=1` adds `--disable-gpu --disable-gpu-compositing` —
these are dashboards, not 3D apps. See the `ymir` skill (its omarchy asset)
skill for the full native story.

## Verification

```bash
cd apps/hlidskjalf
npm run typecheck        # tsc --noEmit
npm run build            # must be green
# headless: render the gate and assert 0 console errors (Playwright/Chrome)
```

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr-ymirsystem/SKILL.md`.
- **Mirror:** `.agents/skills/tyr-check/assets/hlidskjalf-ui.md`.
- When the shell, tokens, gates, or the gate API change, update this asset and
  `docs/design.md` together.

### The agent path the Fleet gate reads (2026-09-17)

`server/index.ts` decides whether a figure is *registered* by testing for its
profile in the OpenCode agent directory. That directory is **`.opencode/agents/`
— PLURAL**, which is what OpenCode actually loads. The singular
`.opencode/agent/` was never read by the harness, so twenty correct symlinks sat
in a directory no loader opened and the gate reported figures unregistered while
the tree held them all. Any code that resolves an agent profile must use the
plural path; the loader (`bin/valknut-load.sh`) migrates a legacy singular dir
forward and binds the plural one.

## Domains, not houses (Rule 01/03)

The eight Labs are **domains (Greinar)** — the knowledge axes — not houses. A
**house is a company** (WayOf). In the UI the eight render as an agent's
**domain** (`agent.domain` via the `DOMAINS` map in `src/data/realms.ts`); the
Forge picker is labelled **Domain**. `svartalfaheim/<company>/companies/` holds
the house card(s); the eight domain cards live under `.../domains/`.

### The GPU-process crash on a shared-memory iGPU (fixed 2026-09-12)

Symptom: both dashboards appear and work, while `coredumpctl` fills with SIGSEGV
cores from `electron --type=gpu-process`, and the kernel logs `amdgpu … Not enough
memory for command submission` immediately before each one. The window survives
because only the **GPU process** dies; Electron retries it, then falls back.

Cause: an iGPU has a small VRAM carve-out and backs the rest with system RAM
(GTT). A local model served on that same iGPU can hold several GiB of GTT, after
which the driver fails the desktop's command submissions. Electron's error path
dereferences NULL — a segfault at a constant offset, not memory corruption.

`scripts/electron.sh` now decides for itself: `igpu_vram_small()` reads
`/sys/class/drm/card*/device/mem_info_vram_total` and switches the dashboards to
software rendering when the carve-out is under `YMIR_IGPU_VRAM_SMALL_MIB`
(default 2048). `YMIR_DESKTOP_DISABLE_GPU=1` forces software, `=0` forces the GPU
path. Verified: with the fix the amdgpu submission errors stop and the
gpu-process runs SwiftShader instead of the hardware path.

If the crash returns, check GTT before anything else — `mem_info_gtt_used` on the
render device, next to whatever is serving a model on that GPU.

### The login surface carries no operator name

The in-app login (the gate shows it; there is no browser prompt) renders its
fields from the server template in `apps/hlidskjalf/server/index.ts`. Neither the
placeholder nor any default may name the operator: the field says `username`, and
the password comes from `HLIDSKJALF_AUTH` in `.env.local`, never inline. A
hardcoded name here is both a leak into the public tree and wrong for any other
operator — `bin/public-guard.sh` exists to catch exactly that class of mistake.

### One login, and it is the one with the lore (2026-09-12)

There used to be **two** ways in, and the second was a mistake:

| | what it was | fate |
|---|---|---|
| `components/LoginModal.tsx` | the gate's login, beside the saga panel | **kept** — the only login |
| `app/Login.tsx` | a mock identity picker (`MOCK_IDENTITIES`), "Mock · Heimdall W0028 pending", demo mode | **deleted** |

The mock was wrong in a way that mattered: `App` rendered it as the fallback
whenever the store had no session, so a *correct* sign-in could land on a screen
offering a hardcoded identity — the operator's own name and email among them. The
demo scaffolding went with it (`demo` flag, `setApiDemo`, `data/mock.ts`,
`enterDemo`/`signIn`, the fake chat reply that claimed the well was seeded), and
with it every branch that could invent data in a live session.

What replaced it:

- **One session shaper.** `services/auth.ts` exports `sessionFor(login)` — the
  gate decides *who*, the UI only shapes what it renders. `App` calls
  `gateApi.session()` at boot and establishes the session from the login the gate
  reports; `establishSession(login)` replaced `signIn`/`enterDemo` in the store.
- **A GitHub door on the same gate.** `LoginModal` carries *Continue with GitHub*
  → `GET /api/auth/github`, which returns the authorize URL when
  `GITHUB_CLIENT_ID`/`GITHUB_CLIENT_SECRET` are set, and the exact reason when
  they are not. The callback (`/api/auth/github/callback`) exchanges the code,
  reads `/user`, and then **requires an account for that login** — accounts come
  from an invite, so GitHub never becomes an open door.
- **A 401 still re-locks.** `noteUnauthorized` is the only thing the demo switch
  was suppressing, and it survives without it.

Verified: `tsc --noEmit` and `npm run build` green, and the served SPA renders the
lore login with the invite affordance and no baked-in identity.

### Accounts and invites — how someone else gets in (added 2026-09-12)

One operator owns an instance. `HLIDSKJALF_AUTH` is that operator. Everyone else
enters through an **invite code**: registration is closed unless a live code is
presented, and a code carries its own ceiling, so a shared link cannot quietly
become an open door.

```
POST /api/register {username,password,invite}   → 201 + session   (403 when refused)
POST /api/login    {username,password}          → 200 + session   (operator OR account)
GET  /api/session                               → {authed,login,registration}
GET  /api/invites                               → {invites,accounts}   (authed)
```

- **Store:** `apps/hlidskjalf/server/accounts.ts` owns accounts and invites.
  `SESSIONS` is a `Map<token,login>` — a session knows *who* it is, and
  `/api/me` reports that login, never a hardcoded one.
- **Where it lives:** `~/.config/ymir/accounts.json`, mode `0600`
  (`YMIR_CONFIG_DIR` overrides, for tests). Machine state, never in the repo.
- **Passwords:** `Bun.password` argon2id via `Bun.password.hash/verify`. The
  plaintext is never written; only the hash lands.
- **The operator's own tool:** `bin/ymir-invite.sh {mint,list,revoke,where,ensure}`.
  `ensure` mints only when nothing is live, so the installer stays idempotent.
- **The UI:** `LoginModal` offers "I have an invite code" **only while
  `/api/session.registration` is true**. A spent or revoked code removes the
offer, because the gate is what decides — the surface merely reports it.
- **Refusals are spoken:** the gate's own sentence ("that invite code has been
  used up") is carried to the caller by `services/api.ts` (`errorText`), so the
  login surface says what is actually wrong instead of a bare status.

### Speed-starts inside the apps (added 2026-09-12)

Each app's own UI can raise the other one — `POST /api/desktop {view}`, valid for
`hlidskjalf` and `smidja`. Both servers implement it by calling
`scripts/electron.sh start --view <view>`, the same launcher the Omarchy key
bindings use, so there is **one** way to raise a Ymir window: it raises the app
when it is already up, and starts it when it is not. The visualizer finds the
checkout by walking up to the directory holding `scripts/electron.sh`, so it
works wherever the app is served from.

**rename sweep (2026-09-12).** The `galdr` -> `galdr-ymirsystem` rename corrected a stale path reference inside `apps/hlidskjalf/server/index.ts` as well; behaviour unchanged.

### The gate's default realm is `wayof` (2026-09-12)

Three places in `apps/hlidskjalf/server/index.ts` defaulted to the retired name
`way-of` (the fleet event realm, the reviews realm, and a seeded lint review).
They now default to `wayof`, matching `svartalfaheim/README.md`: one company
container, no person realms. A retired realm name in a default is not cosmetic —
it sends an event to a directory the platform does not have.

### Reviews now reads real pull requests (added 2026-09-13)

`/api/reviews` built exactly one synthetic card (`id: 'lint'`, `number: 1`,
"Brokk lint gate") from the lint + compliance checks — it **never read a pull
request**, so a delivered change had no Glitnir card and Mjollnir's PR leg had
nowhere to land. `reviews()` now first lists the repo's **open PRs** via
`gh pr list --json …` (mapping `statusCheckRollup` to the card's checks; a
failing check sets `state: 'changes'`), then appends the lint + compliance card
(now `number: 0`). Real PRs lead the list; the compile-and-lint card stays.
The review surface's operator copy now names the **Allfather** throughout — the
seal prompt, the rune emit string, the "awaiting the Allfather" tile, and the
gate comment — retiring the imported `captain` term.

### One seat, three halls (added 2026-09-13)

- **Post-login chooser** (`src/components/Halls.tsx`): `App.tsx` shows it once
  after the gate admits the session — three cards explaining Hlidskjalf, Smíðja,
  and Sessrúmnir, each raising its hall.
- **Switcher**: `Halls.tsx` also exports `HallsSwitcher` (three rune buttons),
  which replaces the lone Smíðja speed-start button in the Topbar. Smíðja's own
  topbar and Sessrúmnir's menu carry matching switchers; all route through the
  gate's `/api/desktop`, which now raises Sessrúmnir too (`bin/sessrumnir.sh`).
- **Search box**: `.topbar .search` `min-width` was 120px — narrower than the
  text "Search work workspace…", so the placeholder clipped. Raised to 280px;
  the input may shrink (`min-width: 0`).
- **One login, Sign out everywhere — verified live, never a file.** The gate is
  the one authority: a session is an in-memory `token → login` map, handed out as
  the httpOnly `ymir_session` cookie. There is **no bearer on disk** and **no
  header credential** (`X-Ymir-Session`/`Bearer` are rejected): a persisted token
  is a credential at rest any local process could replay, and a session read from
  a file is "logged in when you are not". A gate restart ends sessions (nothing
  revives one). Other surfaces verify live: the Smíðja visualizer server forwards
  the browser's cookie to the gate's `/api/session`; Sessrúmnir, having no gate
  cookie, shows a Sign-in link rather than claiming a session. Sign out clears the
  cookie and the in-memory token (shell menu; AccountMenu).
- **The GitHub door is offered only when it can open**: `/api/auth/github`
  returns 503 when no OAuth app is configured, so `/api/session` now carries
  `github: !!(GITHUB_CLIENT_ID && GITHUB_CLIENT_SECRET)` and `LoginModal` renders
  the "Continue with GitHub" button (and its `or` divider) only when true. The
  password door (`HLIDSKJALF_AUTH`) is always present. Configure GitHub with
  `bin/ymir-setup-auth.sh github`.

Rule: a Hlidskjalf code change updates this asset in the same pass — the
compliance gate (`assets/governed assets current`) fails otherwise.

### The Hall door — one button out of the three halls (added 2026-09-13)

The **Óðrerir Live Hall** (the fleet's carved stone/bronze board; now its own
app at `apps/odrerir`, migrated from `~/CodeP/ymir-homepage` on 2026-09-15) is
**not** one of the gate's three apps but it IS its own desktop app since the
migration. The gate raises Hlidskjalf/Smíðja/Sessrúmnir (`/api/desktop` →
`scripts/electron.sh`); Óðrerir is raised with them by `scripts/start.sh` on
`:4322`, opens in its own window via `scripts/electron.sh start --view odrerir`
(native app identity `ymir-odrerir`), and its in-app door is a plain anchor in a
new tab — **never** a launcher call.

- **Where:** `app/Topbar.tsx` carries it beside `HallsSwitcher` — `.hall-btn`, the
  rune **Othala (ᛟ)** plus "To the Hall", tinted with the active realm accent so
  it reads as the same chrome as the chips around it. Styled in `styles/shell.css`
  (tokens only, no raw hex), press feedback in `styles/overlays.css`.
- **The hall app:** `apps/odrerir` — an Astro board (the Óðrerir Live Hall) that
  serves `:4322` and reads `public/livehall.json`, written by
  `bin/hall-snapshot.sh` (planning glass; public-safe). Its own Electron shell:
  `apps/odrerir/electron/main.cjs`, raised by `scripts/electron.sh --view odrerir`.
- **Target rule — one rule for all of Ymir's apps:** `HALL_URL` in
  `src/data/metadata.ts`. `window.location.host` starting with `localhost` or
  `127.0.0.1` → `http://localhost:4322`; any other host → the public
  `https://hall.ymir.zerw.org`. `VITE_HALL_URL` overrides it, exactly as
  `VISUALIZER_URL` does. Each app computes this inline — the Vite builds are
  separate, so there is no shared module to hang it on.
- **Same door** in the Smíðja visualizer's topbar and in Sessrúmnir, so every
  app's chrome has one way to the Hall.
- Verified: both branches of the rule in both apps (headless Chromium DOM probe),
  `tsc --noEmit && vite build` green, 0 console errors; `apps/odrerir` builds
  standalone and the hall answers `:4322` from `scripts/start.sh`.

## Packaging (Amendment C)

Each app ships as its own published package under the `@zerwiz` scope (the scope
that already carries `@zerwiz/ymir`) — `@zerwiz/hlidskjalf`, `@zerwiz/odrerir`,
and `apps/hlidskjalf/package.json` carries the metadata that makes that legal:
`license`, `repository`, `publishConfig.access: public`, a `files` surface, and
`prepack` where a build exists (never `prepublishOnly`: a build must not be able
to veto a publish, and neither must a documentation gate).

Two facts worth keeping:

- **The APK is not in the tarball.** `apps/hlidskjalf/dist/ymir.apk` (~13.6 MB)
  is built for Android, not for npm; `files` excludes it with `!dist/*.apk`.
  Including it took the package from 1.3 MB to 14.5 MB — npm is not an APK
  distribution channel.
- **`private: true` is the safety catch.** It stays set until the Allfather
  publishes deliberately, so no accidental `npm publish` can push a half-built
  artefact to a public registry.

Measured with `npm pack --dry-run --ignore-scripts` (see the app's `files` for
the exact surface).

## The two doors — web logs in, the desktop seat does not

There is **one** login surface (`LoginModal` → `POST /api/login`), and it belongs
to the **web** door. The desktop shell (Electron) is a local, trusted seat and is
never asked to log in.

The mechanism is deliberately narrow, because a marker a client can send is not
proof of anything:

- the Electron preload exposes `window.ymirDesktop = { desktop: true }`;
- the SPA sends `x-ymir-surface: desktop` on every request, and
  `?surface=desktop` on the SSE stream (EventSource cannot set headers);
- the gate (`server/index.ts`) honours that marker **only when the request
  arrives over loopback** — `REQUEST_IP`, recorded per request from Bun's
  `server.requestIP(req)`, because Bun's `Request` carries no socket. A remote
  web caller can send the header and still be refused.

Verified both ways: `GET /api/session` without a cookie is `authed:false` and
`/api/orders` is 401; the same calls with the marker from 127.0.0.1 are
`authed:true` (login = the operator) and 200.
