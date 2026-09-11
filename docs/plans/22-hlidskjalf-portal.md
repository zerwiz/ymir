# Plan 22 — Hlidskjalf Portal (unified observability)

- **Status:** proposed · **Realm:** platform · **Owner:** Brokk/Kaia
- **Directive:** Ymir owns the UI/UX (ENTRY-008). Build one **React/Vue** control
  plane over every Norse signal, wearing the Ymir Rut design language.

## Objective

Hlidskjalf is Odin's high seat — the sovereign's view of every realm. One screen:
fleet graph, live A2A task stream, the memory well, the Runes ledger, PR reviews,
and a tenant switcher. Agents usable, humans in control.

## Views

| View | Signal source |
|---|---|
| Fleet graph | Ratatoskr registry (Agent Cards) + Redis live state |
| A2A task stream | Ratatoskr task lifecycle (SUBMITTED→WORKING→terminal) |
| Memory well (`#/memory`) | Mimirsbrunn bridge `/recall` `/timeline` `/observe` (proxied) |
| Runes ledger | `workspace/memory/runes_audit.md` + trace DB |
| PR review cards | GitHub API via Mjollnir (Glitnir card) |
| Tenant switcher | Svartalfaheim realm registry |
| Process health | Valhalla / PM2 / Docker status |
| Houses & entities | Plan 21 company/project registry |

## Design

Ymir Rut v2.6 design system (typed in `docs/ymir-rut.md` Part 3):
- Fonts: Cinzel (headings) · JetBrains Mono (telemetry) · Inter (body).
- Colors: obsidian base, electric cyan accents, violet realm tones, slate borders.
- Emblem: Algiz rune over anvil with chiseled bevels.
- Build on the **factory visualizer** precedent (Vue) rather than a from-scratch UI.

## ADD / NOT / KEEP

- **ADD:** React/Vue portal in `apps/hlidskjalf/`, design-token styleguide, fleet + task + memory + runes modules.
- **NOT:** a second bespoke visualizer engine (reuse factory visualizer + standard chart/metrics libs).
- **KEEP:** OSS-first; portal rides existing APIs (bridge `:4602`, Redis, GitHub, PM2).