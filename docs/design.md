# YMIR — Design Document

> **Status:** v1.1 · owner: Brokk · applies to Hlidskjalf (React), Smíðja's eye
> (Vue), Sessrúmnir (Electron/Tailwind), all Norse surfaces, and the houses.
> Sources: Ymir Rut v2.6 (`docs/ymir-rut.md` Part 3), the mythos (`docs/lore.md`),
> the UI/UX-is-a-differentiator doctrine (ENTRY-008), the stack ruling
> (ENTRY-009/010), and **the carved cloth of the halls** — the landing page's
> `:root` (`CodeP/ymir-homepage/src/lore.html`), which is the reference every
> value below is cut from.
> Implementation: design tokens live in `midgard/design-system/tokens.css`
> (consumed by React and Vue apps); Sessrúmnir carries the same values in its
> Tailwind `@theme` and in the `sessrumnir`/`fensalir` theme files.

---

## 0. The cloth — one look, one source

Every hall wears the same cloth: **stone and bone, bronze and blood**, with the
three faces **Cormorant** (display), **Newsreader** (body) and **IBM Plex Mono**
(data). The reference is the landing page's `:root`; the apps carry it through
thin adapters, never by hand-copying a colour:

| Surface | Adapter | Where the values live |
|---|---|---|
| Landing page | the source | `CodeP/ymir-homepage/src/lore.html` `:root` |
| Hlidskjalf | `--ymir-*` token names | `midgard/design-system/tokens.css` |
| Smíðja's eye | `--bg/--panel/--text/--accent…` | `apps/visualizer/src/style.css` (`:root`) |
| Sessrúmnir | semantic `--color-*` (pi-theme/v1) | `src/renderer/src/index.css` `@theme` + `themes/fensalir.json` |

Two rules hold the cloth honest:

1. **The cloth is the default, not a cage.** A user theme, an accent preset, or
   Smíðja's `data-theme="classic"` / `"high-contrast"` (WCAG AAA) always wins
   when chosen. Sessrúmnir's `fensalir` and `sessrumnir` built-ins are the cloth
   under two names, held identical by test.
2. **Heraldry is not chrome.** House/domain seals (the eight accents) and the
   Emblem keep their own colours — the landing page keeps its house seals too.
   Chrome — canvas, text, borders, accent, state — is the cloth.

A colour is never written at a call site: components read tokens (or
`text-inverse` on a filled plate). Selection is part of the cloth too: the
landing's amber `#57411a` on pale bone `#f0e6cd`.

---

## 1. Philosophy — Carved, not skinned

Ymir's UI is not decoration bolted onto a system; it is **forged from the same
allegory the system runs on**. Every pixel should feel as if it were carved from
the giant's bones, hammered in a Svartalfaheim forge, lit by Bifrost transit
beams. The design behaves the way the system behaves:

- **Forged, not painted** — bevels, chiseled edges, material depth. Nothing
  floats; everything sits.
- **The well is visible** — memory, telemetry, and audit are first-class surface,
  never hidden behind "settings".
- **The forge stays hot** — status is instant, truthful, and always on screen.
- **Quiet strength** — high legibility, low noise. This is an instrument panel
  for a single operator running everything.

Design decisions always answer: *"would a dwarf smith build it this way?"*

---

## 2. Brand Identity

### 2.1 Emblem — the Ymir Root Mark

The mark combines two glyphs:

- **Algiz (ᛉ)** — the rune of protection and the branching *worker stems* of the
  agent tree (also evokes Yggdrasil spreading from the root).
- **Blacksmith anvil base** — industrial strength, heavy compute, the forge from
  which every artifact is shaped.

Construction rules:
- Dual-layer chiseled bevel: dark iron exterior `#334155`, luminous cyan inner
  edge `#7dd3fc`. The **Emblem is brand, not cloth** — it keeps its own colours on
  every surface, exactly as the landing page keeps it (a blue mark on the stone).
- One emblem per context; never gradient-bloated, never filled with imagery.
- On dark obsidian surfaces: cyan-lit variant. On light surfaces: steel variant
  with indigo edge.
- Favicon = the rune alone, 24–32px, stroke weight 2.

### 2.2 Houses — brands within the brand

Each house carries the myth that names it and a **house accent** for seals,
tags, and portal theming (proposed accents — ENTRY-004 mapping):

| House | Name-sake | House accent |
|---|---|---|
| Ymir Labs | the giant | cyan `#38bdf8` |
| Brokk Forge | the bellows-smith | forge amber `#f59e0b` |
| Runestone Labs (Runir) | the runes | rune crimson `#f43f5e` |
| Muninn Labs | the raven (memory) | raven violet `#8b5cf6` |
| Dvalin | the dwarf craftsman | cold steel `#94a3b8` |
| Utgard Studios | the giant-realm | jötun magenta `#d946ef` |
| Askr | the first man | ash green `#34d399` |
| Mannheim | *(reserved)* | slate `#64748b` |

House accents are **structural only** — tags, entity headers, chart series —
never the page chrome, and they are **heraldry, not cloth**: they keep their own
colours exactly as the landing page keeps its house seals, while the chrome
around them wears the cloth (§4.2). The same eight accents are the agent
**domains** in Hlidskjalf (`src/data/realms.ts` → `DOMAINS`).

---

## 3. Design Principles

1. **The giant is the frame** — one body, many realms. One visual system across
   every tenant; a realm is a *view*, not a redesign.
2. **Truth over ornament** — telemetry and logs render exactly as they are. No
   fake glow, no invented metrics. Traceability index is a real number on screen.
3. **Status is ambient** — NOMINAL / DEGRADED / DOWN is readable at a glance
   from across the room (color + glyph + text, never color alone).
4. **The well is a first-class citizen** — recall results, episodes, and timeline
   render inline, not in a hidden drawer.
5. **Isolation by default** — realms are visually distinct (borders, subtle
   tint), never commingled. A user must *feel* which realm they're in.
6. **Motion explains, never decorates** — transitions trace real data flow
   (task state changes, message hops). ~150–240ms, linear-ish, no bounce.
7. **Dense but calm** — keyboard-first, mono for data, generous breathing room
   for narrative text.

---

## 4. Visual Language

### 4.1 Typography

| Role | Face | Use |
|---|---|---|
| Display & runes | **Cormorant** (runic glyphs fall through to **Noto Sans Runic**) | page titles, section headers, the emblem wordmark, runic seals |
| Code, telemetry, metrics | **IBM Plex Mono** | all data: logs, IDs, states, timestamps, task/agent names, CLI |
| Body & UI | **Newsreader** | description text, labels, buttons, body of narratives, docs |

Scale (reference — fluid via clamp()):

| Token | Size / Line-height | Used for |
|---|---|---|
| s-mono-s | 12 / 16 | timestamps, badges |
| s-mono-m | 14 / 20 | telemetry, task IDs |
| s-mono-l | 18 / 24 | hero metrics (traceability index) |
| s-display | 28–44 / 1.1 | realm/page titles |
| s-body | 15 / 22 | descriptions |
| s-caption | 13 / 18 | secondary notes |

Rules: metrics are **always** IBM Plex Mono (tabular numerals enabled);
runes/glyphs fall through to the rune family inside every stack; never mix faces
mid-line. Title case stays short — one lyric line, then the deck explains.

### 4.2 Color system

The cloth (dark = the forge theme, canonical; values cut from the landing page's
`:root`):

**Canvas (the stone)**

| Token | Value | Role |
|---|---|---|
| `--ymir-bg-0` | `#0e0c09` | stone — deepest canvas, app shell |
| `--ymir-bg-1` | `#151209` | panel surface |
| `--ymir-bg-2` | `#1a1610` | elevated surface, cards |
| `--ymir-bg-3` | `#221d14` | hover, wells |

**Accents (the bronze light of the forge)**

| Token | Value | Role |
|---|---|---|
| `--ymir-cyan-1` | `#c9973f` | bronze — primary accent, active states, focus ring, links |
| `--ymir-cyan-2` | `#7d5f2a` | bronze-deep — hover/darker accent |
| `--ymir-violet-1` | `#96a0a8` | steel — realm identity, secondary accent |
| `--ymir-violet-2` | `#5f686e` | steel-dim |

**Structure (bone and brass)**

| Token | Value | Role |
|---|---|---|
| `--ymir-steel-1` | `#2b241a` | line — borders, bevel exteriors |
| `--ymir-steel-2` | `#7d5f2a` | bronze-deep — stronger rules, dividers |
| `--ymir-steel-3` | `#9a8f75` | bone-dim — secondary text, muted glyphs |
| `--ymir-chisel` | `#c9973f` | bronze — the lit chisel edge (emblem, focus) |

**Semantics (state of the forge)**

| Token | Value | Meaning |
|---|---|---|
| `--ymir-ok` | `#96a0a8` | NOMINAL (steel — the metal proved true) |
| `--ymir-warn` | `#c9973f` | DEGRADED (bronze — hot, heed it) |
| `--ymir-danger` | `#c2584a` | DOWN / sealed (blood-lit) |
| `--ymir-info` | `#9a8f75` | transit / neutral-inform (bone-dim) |
| `--ymir-ok-dim` | `rgba(150,160,168,.15)` | background wash of the above, same pattern for warn/danger/info |

**Text on stone**

| Token | Value | Role |
|---|---|---|
| `--ymir-text-0` | `#cfc3a9` | bone — primary text |
| `--ymir-text-1` | `rgba(207,195,169,.82)` | bone, blunted — secondary text |
| `--ymir-text-2` | `#9a8f75` | bone-dim — tertiary, disabled |
| `--ymir-text-3` | `#6b6250` | bone-faint — placeholder |

**Selection** (all surfaces): amber `#57411a` on pale bone `#f0e6cd` — the
landing's own selection. In Sessrúmnir it is a theme token
(`--color-selection-bg`/`-fg`), so a user theme derives its own tint from its
accent; the cloth themes pin the landing's amber.

Contrast: `--ymir-text-0` on `--ymir-bg-1` ≈ 10:1; body 15px meets WCAG AA
everywhere; never put bronze text on bronze.

### 4.3 Space & grid

- Base unit **4px**; 8px rhythm for layout.
- Panel padding `--ymir-space-4: 16px`; page gutter 24–48.
- Max content width 1440; density slider for the data views (comfortable ↔ compact).
- Components: radius `--ymir-radius: 8px` (panels 12px), 1px line borders,
  inset shadows to sell the carved edge: `inset 0 0 0 1px rgba(201,151,79,.12)`
  (a brass hairline inside the stone).
- Geometry is unchanged by the cloth: the carved-slate **squaring** (radius 2–3px
  across the apps and the seat) is an open question, not yet decided.

### 4.4 Iconography & glyphs

- **Runecoded, not emoji.** A minimal, hand-drawn-style rune set replaces emoji
  in all UI: 16×16 and 24×24 grid, 2px stroke, chisel bevel on primary.
- System subsystems each carry one rune-glyph (reuse Algiz-family geometry:
  Bifrost gate, Ratatoskr squirrel, the Well). Map is in `midgard/design-system/icons.md` (TBD) — created from this doc.
- Status dot: filled rune ring (ok) / half-ring (warn) / broken ring (danger), never color-only.

### 4.5 Surface & texture

- Background treatment: **hand-hammered steel** (very subtle noise/specular ~2%),
  and the **crystalline icosahedral grid** for hero/brand areas only (3–5% opacity).
- Emblem renders with the chisel bevel; body surfaces stay flat — motif stops at
  the chrome, never behind text.

### 4.6 Motion

| Context | Pattern | Duration |
|---|---|---|
| Task state change | fade + 2px upward drift on the state chip | 180ms |
| Message hop (Ratatoskr) | light dash along the fleet edge | 220ms |
| Panel reveal | mask + slight scale 0.99→1 | 160ms |
| Metric tick | IBM Plex Mono numeric roll (monospace, tabular) | 240ms |
| Loading | screen of the forge (glowing ember + rune), not a spinner wheel | — |

Honor `prefers-reduced-motion`: all transforms collapse to fades ≤120ms.

---

## 5. UI System — Hlidskjalf (React/Vue)

### 5.1 App shell

- Left rail: emblem + the **7 realm gates** (click = realm switch), collapsed to
  rune-only at <900px.
- Top bar: current realm chip (house accent + tenant name), global search
  (realm-scoped), traceability index chip (live), the three-hall switcher, the
  **To the Hall** door to the Óðrerir Live Hall (new tab: local `:4322` when the
  host starts with `localhost`/`127.0.0.1`, else the public hall), user menu.
- Main stage: modal-free; views are full panels with a persistent **bottom stream**:
  Ratatoskr messages + Runes entries in one mono stream (pausable).

Views: **Fleet** (agents/cards) · **Tasks** (A2A lifecycle board) · **Well**
(memory recall/timeline/observe) · **Runes** (ledger) · **Reviews** (PR cards) ·
**Processes** (Valhalla) · **Files** (Skrymir) · **Chat** (OmniChat drawer).

### 5.2 Reusable components (token-driver)

| Component | Spec |
|---|---|
| `RealmGate` | rune + label + subtle realm tint; active = bronze chisel ring |
| `AgentCard` | Agent Card JSON rendered: name, capabilities, skills, interface, status dot, house seal |
| `TaskChip` | A2A state: SUBMITTED→WORKING→terminal; color + rune + label (never color alone) |
| `TraceRow` | mono line: ts · agent · module · event · checksum |
| `RecallPanel` | query + ranked episodes (score bar = cyan), timeline view |
| `MetricTile` | mono number + delta + sparkline; beveled panel |
| `RuneTag` | house/label pills using house accents |
| `PRCard` | title, checklist progress, CI runes, review actions (Glitnir) |

All components read tokens from `tokens.css`; color-only states are forbidden
(append a rune glyph + text).

### 5.3 Data visualization

- Charts: thin 2px bronze/steel lines, no 3D, no pie explosions; gridlines at
  `--ymir-steel-2` 12% opacity.
- Series color order: bronze → steel → bone → blood-lit → bronze-deep.
- Fleet graph: nodes = Agent Cards, edges = A2A task hops; edge dashes animate on
  activity; node ring = status.
- Trace/timeline: JetBrains Mono; branch/merge glyphs reused from Yggdrasil theme.

### 5.4 Identity & accounts (the gate)

- The gate is closed by default once a credential or account exists: every
  `/api/*` route (and the Smíðja host) needs an httpOnly `ymir_session` cookie.
  Only `/api/login`, `/api/register`, `/api/session`, `/api/logout` and
  `/api/health` ride outside it.
- **Operator credential** (`HLIDSKJALF_AUTH="user:pass"` from `.env.local`,
  never inline) opens the gate and seeds the allfather account row.
- **Invite-gated registration** (`bin/ymir-invite.sh`): a code with a use-limit
  is minted when nothing is live (idempotent) and printed at the end of an
  install. `register` re-checks the invite under a re-read of the store, so two
  simultaneous registrations cannot both spend the last use. Account passwords
  are argon2id-hashed and land in `state/accounts.json` (mode 0600, gitignored).
  **Sessions are in-memory only** (a `token → login` map) and exist solely as the
  httpOnly `ymir_session` cookie — no session file and no header credential, so
  there is no bearer at rest to replay and no file that can claim a session; a
  gate restart ends them. Other surfaces verify live against the gate.
- **GitHub sign-in** is the same gate by another door, once
  `GITHUB_CLIENT_ID`/`GITHUB_CLIENT_SECRET` are set (`ymir_oauth_state` cookie,
  10-minute window).
- Sessions are httpOnly `ymir_session` cookies, SameSite=Lax, 30-day Max-Age.
- Heimdall (oauth2-proxy) remains the production road: httpOnly session cookie
  with the same shape, so the client swap is mechanical.

---

## 6. Content & voice

- **Short, operational, zero flair.** "Task failed. Diagnosis: json_contract.
  Retried as 6f1a." — not "We encountered an unexpected issue."
- Headings read like commands; decks read like log lines.
- Rune labels double as keyboard hints (`ᛉ` = Algiz/protect, used for "seal/approve").

---

## 7. Accessibility & implementation notes

- AA contrast enforced (tokens guarantee it), focus = bronze chisel ring, target
  size ≥44px, keyboard-first with all views reachable.
- React and Vue consume the **same cloth** — no per-framework color drift.
  `tokens.css` is the single source for both; component styling via CSS vars,
  not hardcoded hex. Sessrúmnir's equivalent is its `@theme` block plus
  `themes/fensalir.json`, held identical by test.
- Agents (Brokk/Eindri) generate UI from **Agent Cards and task JSON** — the
  design system guarantees any agent-produced surface is on-brand without a
  designer in the loop.

---

## 8. Files

- `docs/design.md` — this document (master).
- `midgard/design-system/tokens.css` — the consumable design tokens.
- `midgard/design-system/icons.md` — rune-glyph map (to create).
- `docs/ymir-rut.md` Part 3 — the original Rut design-system specification this
  document implements.
- `docs/lore.md` §VI — house lineage behind the house accents.