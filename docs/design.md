# YMIR — Design Document

> **Status:** v1.0 · owner: zerwiz · applies to Hlidskjalf (React/Vue), all Norse
> surfaces, and the houses.
> Sources: Ymir Rut v2.6 (`docs/ymir-rut.md` Part 3), the mythos (`docs/lore.md`),
> the UI/UX-is-a-differentiator doctrine (ENTRY-008), and the stack ruling
> (ENTRY-009/010).
> Implementation: design tokens live in `midgard/design-system/tokens.css`
> (consumed by React and Vue apps).

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
  edge `#7dd3fc`.
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
never the page chrome.

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
| Headings & runes | **Cinzel** | page titles, section headers, the emblem wordmark, runic seals |
| Code, telemetry, metrics | **JetBrains Mono** | all data: logs, IDs, states, timestamps, task/agent names, CLI |
| Body & UI | **Inter** | description text, labels, buttons, body of narratives, docs |

Scale (reference — fluid via clamp()):

| Token | Size / Line-height | Used for |
|---|---|---|
| s-mono-s | 12 / 16 | timestamps, badges |
| s-mono-m | 14 / 20 | telemetry, task IDs |
| s-mono-l | 18 / 24 | hero metrics (traceability index) |
| s-cinzel | 28–44 / 1.1 | realm/page titles |
| s-body | 15 / 22 | descriptions |
| s-caption | 13 / 18 | secondary notes |

Rules: metrics are **always** JetBrains Mono (tabular numerals enabled);
runes/glyphs are Cinzel; never mix faces mid-line. Title case stays short —
one lyric line, then the deck explains.

### 4.2 Color system

Foundations (light = dom, dark = forge) — **the forge theme is default and canonical**:

**Canvas (the forge chamber)**

| Token | Value | Role |
|---|---|---|
| `--ymir-bg-0` | `#080c14` | deepest canvas, app shell |
| `--ymir-bg-1` | `#0b101c` | panel surface |
| `--ymir-bg-2` | `#101726` | elevated surface, cards |
| `--ymir-bg-3` | `#182334` | hover, wells |
| light base | `#f4f6fa` | (light theme only, optional) |

**Accents (two lights of Bifrost)**

| Token | Value | Role |
|---|---|---|
| `--ymir-cyan-1` | `#38bdf8` | primary accent, active states, focus ring, links |
| `--ymir-cyan-2` | `#0ea5e9` | hover/darker accent, gradients |
| `--ymir-violet-1` | `#818cf8` | realm identity, secondary accent |
| `--ymir-violet-2` | `#6366f1` | darker violet |

**Structure (hammered steel)**

| Token | Value | Role |
|---|---|---|
| `--ymir-steel-1` | `#334155` | borders, bevel exteriors |
| `--ymir-steel-2` | `#475569` | stronger lines, dividers |
| `--ymir-steel-3` | `#94a3b8` | secondary text, muted glyphs |
| `--ymir-chisel` | `#7dd3fc` | cyan inner bevel edge (emblem, focus) |

**Semantics (state of the forge)**

| Token | Value | Meaning |
|---|---|---|
| `--ymir-ok` | `#34d399` | NOMINAL (emerald) |
| `--ymir-warn` | `#fbbf24` | DEGRADED (amber) |
| `--ymir-danger` | `#f87171` | DOWN / sealed (ember red) |
| `--ymir-info` | `#38bdf8` | transit / neutral-inform |
| `--ymir-ok-dim` | `rgba(52,211,153,.15)` | background wash of the above three, same pattern for warn/danger/info |

**Text on forge**

| Token | Value | Role |
|---|---|---|
| `--ymir-text-0` | `#e8edf6` | primary text |
| `--ymir-text-1` | `#b3c0d4` | secondary text |
| `--ymir-text-2` | `#7b8aa3` | tertiary, disabled |
| `--ymir-text-3` | `#4b5a73` | placeholder |

Contrast: `--ymir-text-0` on `--ymir-bg-1` ≈ 13:1; body 15px meets WCAG AA
everywhere; never put cyan text on cyan.

### 4.3 Space & grid

- Base unit **4px**; 8px rhythm for layout.
- Panel padding `--ymir-space-4: 16px`; page gutter 24–48.
- Max content width 1440; density slider for the data views (comfortable ↔ compact).
- Components: radius `--ymir-radius: 8px` (panels 12px), 1px steel borders,
  inset shadows to sell the bevel: `inset 0 0 0 1px rgba(125,211,252,.12)`.

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
| Metric tick | JetBrains Mono numeric roll (monospace, tabular) | 240ms |
| Loading | screen of the forge (glowing ember + rune), not a spinner wheel | — |

Honor `prefers-reduced-motion`: all transforms collapse to fades ≤120ms.

---

## 5. UI System — Hlidskjalf (React/Vue)

### 5.1 App shell

- Left rail: emblem + the **7 realm gates** (click = realm switch), collapsed to
  rune-only at <900px.
- Top bar: current realm chip (house accent + tenant name), global search
  (realm-scoped), traceability index chip (live), user menu.
- Main stage: modal-free; views are full panels with a persistent **bottom stream**:
  Ratatoskr messages + Runes entries in one mono stream (pausable).

Views: **Fleet** (agents/cards) · **Tasks** (A2A lifecycle board) · **Well**
(memory recall/timeline/observe) · **Runes** (ledger) · **Reviews** (PR cards) ·
**Processes** (Valhalla) · **Files** (Skrymir) · **Chat** (OmniChat drawer).

### 5.2 Reusable components (token-driver)

| Component | Spec |
|---|---|
| `RealmGate` | rune + label + subtle realm tint; active = cyan chisel ring |
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

- Charts: thin 2px cyan/violet lines, no 3D, no pie explosions; gridlines at
  `--ymir-steel-2` 12% opacity.
- Series color order: cyan → violet → emerald → amber → crimson.
- Fleet graph: nodes = Agent Cards, edges = A2A task hops; edge dashes animate on
  activity; node ring = status.
- Trace/timeline: JetBrains Mono; branch/merge glyphs reused from Yggdrasil theme.

---

## 6. Content & voice

- **Short, operational, zero flair.** "Task failed. Diagnosis: json_contract.
  Retried as 6f1a." — not "We encountered an unexpected issue."
- Headings read like commands; decks read like log lines.
- Rune labels double as keyboard hints (`ᛉ` = Algiz/protect, used for "seal/approve").

---

## 7. Accessibility & implementation notes

- AA contrast enforced (tokens guarantee it), focus = cyan chisel ring, target
  size ≥44px, keyboard-first with all views reachable.
- React and Vue consume the **same token set** — no per-framework color drift.
  `tokens.css` is the single source; component styling via CSS vars, not hardcoded hex.
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