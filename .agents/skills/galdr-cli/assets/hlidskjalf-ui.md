# Hlidskjalf UI — working guide

Ymir's own surface (one of the three things Ymir owns: the UI, the runtime, A2A).
Load this when touching `apps/hlidskjalf`. The design contract is `docs/design.md`;
the tokens are the single source of truth.

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
2. **Runecoded, not emoji** — use the rune family (Cinzel); never an emoji as an icon.
3. **Every button must act** — no dead controls. Wire to a state change, a modal, or
   a toast.
4. **Motion explains** — 120–240ms, no bounce; honour `prefers-reduced-motion`.
5. **Metrics are JetBrains Mono, tabular** (`.mono`, `.tabular`).
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
  and reads/edits the smithy's prompts.
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

- **Owner:** Brokk. **Router:** `.agents/skills/galdr-cli/SKILL.md`.
- **Mirror:** `.agents/skills/tyr-check/assets/hlidskjalf-ui.md`.
- When the shell, tokens, gates, or the gate API change, update this asset and
  `docs/design.md` together.

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

**rename sweep (2026-09-12).** The `galdr` -> `galdr-cli` rename corrected a stale path reference inside `apps/hlidskjalf/server/index.ts` as well; behaviour unchanged.
