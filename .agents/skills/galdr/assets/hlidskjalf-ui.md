# Hlidskjalf UI — working guide

Ymir's own surface (one of the three things Ymir owns: the UI, the runtime, A2A).
Load this when touching `apps/hlidskjalf`. The design contract is `docs/design.md`;
the tokens are the single source of truth.

## 15.1 Location & stack

- App: `apps/hlidskjalf` — **React 19 + Vite + TypeScript**, state via **Zustand**.
- Run: `cd apps/hlidskjalf && npm install && npm run dev` → `http://127.0.0.1:3888/`.
- Verify: `npm run typecheck` (`tsc --noEmit`) and `npm run build` must both be green.
- Headless check: render with Playwright/Chrome and assert **0 console errors**
  before claiming done.

## 15.2 Tokens — never hardcode colour

- Canonical tokens: `midgard/design-system/tokens.css`, imported once in
  `src/main.tsx` (Vite `server.fs.allow` grants access outside the app root).
- Style with CSS variables only (`var(--ymir-cyan-1)`, `var(--ymir-bg-2)`, …).
  **Never** write a raw hex in a component or a stylesheet — add a token instead.
- The active **accent** is driven by `--realm-tint` / `--realm-tint-2` /
  `--realm-tint-dim` on `:root`, set per realm via `data-realm` and overridable by
  the user (`state/store.ts` → `applyAccent`). Tenant overrides live in
  `tenantColors`.

## 15.3 The shell (structural, do not redesign)

- `.shell` grid: `236px rail | 1fr`; rows `56px topbar · stage · 192px stream`.
- `.rail` (brand · gates · tenants · status), `.topbar` (realm chip · search ·
  accent · density · trace index · account), `main.stage` (the gate), `.stream`
  (Ratatoskr + Runes).
- Gates are **deep-linkable**: `#/fleet`, `#/tasks`, `#/well`, `#/runes`,
  `#/reviews`, `#/processes`, `#/files`, `#/chat`, `#/forge`, `#/profile`.

## 15.4 Rules of the surface

1. **Color-only states are forbidden** — every status carries glyph + colour + text
   (`StatusChip`, `TaskChip`).
2. **Runecoded, not emoji** — use the rune family (Cinzel); never an emoji as an icon.
3. **Every button must act** — no dead controls. Wire to a state change, a modal, or
   a toast. New actions use the overlay system below.
4. **Motion explains** — 120–240ms, no bounce; honour `prefers-reduced-motion`.
5. **Metrics are JetBrains Mono, tabular** (`.mono`, `.tabular`).
6. **Metadata per page** — a gate declares its title/description/OG tags in
   `src/data/metadata.ts`; `Shell` applies them on gate/realm change.

## 15.5 Interaction patterns (modal + toast)

- `src/state/ui.ts` exposes `useUI()` → `toast({kind,title,body})` and
  `openModal({variant,title,body,fields,content,onSubmit})`.
- `<Overlay/>` (mounted in `App`) renders the modal + toast host. Variants:
  `confirm` (glyph + confirm), `form` (fields), `info` (content block, e.g. a diff).
- Any destructive or consequential action **must** open a confirm/form modal, mutate
  the store, emit a rune (`pushStream`), and toast the outcome. See
  `components/PRCard.tsx` (Seal / Request changes / View diff) as the reference
  implementation.
- Buttons get press feedback from `styles/overlays.css` (`translateY(1px) scale(.97)`).

## 15.6 State

- `src/state/store.ts` — session, realm, gate, accent, tenant colours, company, data
  (agents, tasks, runes, stream, recall, processes, reviews, files, chat, skills).
- Realm switching is **granted**: `setRealm` refuses a realm the session has no grant
  for. Tenant boundaries are sacred — never render another tenant's data.
- Persist user prefs to `localStorage` (`ymir.accent`, `ymir.tenant-colors`,
  `ymir.company.*`).

## 15.7 Adding a gate (checklist)

1. Add the id to `GateId` in `src/types.ts`.
2. Add its `{ id, label, glyph, hint }` to `GATES` in `src/data/realms.ts`.
3. Add its `PageMeta` to `GATE_META` in `src/data/metadata.ts`.
4. Create `src/gates/<Gate>.tsx`; render it in the `Stage` switch in
   `src/app/Shell.tsx`.
5. Components are token-driven; reuse `AgentCard`, `TaskChip`, `TraceRow`,
   `RecallPanel`, `MetricTile`, `RuneTag`, `PRCard`, `StatusChip`.
6. Extend the headless verification (`/tmp/verify.cjs` pattern) and keep it green.

## 15.8 Agents, skills & mythological naming

- The Forge gate (`src/gates/Forge.tsx`) creates/edits **Eindri** and **skills**.
- Naming law: `src/data/mythology.ts` maps a craft/capability → the Norse figure
  whose myth matches it (smith→Sindri, skald→Bragi, sage→Huginn, judge→Tyr,
  forger→Brokk …). Every new Eindri takes a name from the suggestion engine; skills
  take an **aett** prefix (`galdr-`, `mimir-`, `yggd-`, `rat-`, `heimd-`, `bifr-`,
  `val-`, `skyr-`).
- New skills are **validated in Utgard** before production (mock flag today;
  W0007/Gungnir lands the real gate). On save they register in the skill index and
  emit a rune.

## 15.9 Identity

- Mark: `midgard/design-system/ymir-mark.svg` (served copy
  `apps/hlidskjalf/public/ymir-mark.svg`), used for the login/rail logo and favicon.
  OG image: `public/og.png` (1200×630), source `public/og.svg`. Rebuild the PNG with
  headless Chrome if the SVG changes.

## Verification

```
cd apps/hlidskjalf
npm run typecheck        # tsc --noEmit
npm run build            # must be green
# headless: render the gate and assert 0 console errors (Playwright/Chrome)
```

## Maintaining this

- **Owner:** Brokk. **Router:** `.agents/skills/galdr/SKILL.md`.
- **Mirror:** `.agents/skills/tyr-check/assets/hlidskjalf-ui.md`.
- When the shell, tokens, or gate contract changes, update this asset and
  `docs/design.md` together.
