# Plan 21 — Company Houses & Entity Registry

- **Status:** approved (ENTRY 2026-09-11-004/005) · **Realm:** company (way-of)
- **Owner:** zerwiz (with craig)

## Objective

Give the fleet a single registry of **who works for whom**. Every venture Ymir
carries is a **house** (a Norse myth that names a real business) with an entity
card; every project belongs to a house and an owner, scoped per tenant.

## The Houses (approved palette — ENTRY-004)

| House | Name-sake | Owes |
|---|---|---|
| **Ymir Labs** | the primordial giant | the platform itself |
| **Brokk Forge** | the bellows-smith | engineering & build tooling (WayOf Command/Runecode, softwerefactory, wayofmono) |
| **Runestone Labs (Runir)** | the runes | records & compliance (.compliance, docs, runbooks, research) |
| **Muninn Labs** | the raven *(memory)* | memory & knowledge (Anchor, Mimirsbrunn/engram, RAG) |
| **Dvalin** | the dwarf craftsman | crafted tools (OptiCat/HVAC Pro, Linkable, Todo, Desk, Material Files) |
| **Utgard Studios** | the giant-realm | creative (WhyNot Productions, AiPic, OpenChamber, sensual dojo) |
| **Askr** | the first man | human-centered products (Relocation Copilot, onboarding) |
| **Mannheim** | *(reserved clan name)* | holding — allocated when a venture claims it |

Rejected house names (collide with subsystems): Mimirsbrunn, Heimdall, Fenrir,
Audumbla, Ratatoskr, Garm, Vidar.

## Entity Card Model (per tenant `companies/`)

Per-tenant directory: `svartalfaheim/<realm>/companies/<house>/` and
`svartalfaheim/<realm>/projects/<project>/`.

Card fields: `name`, `type` (company|personal), `owner`, `realm`, `house`,
`products[]`, `repo`, `status`, `lore_line`.

Template: `.agents/assets/templates/company_entity.template.md`.

## ADD / NOT / KEEP

- **ADD:** `companies/` + `projects/` per tenant, entity-card template, house
  chapter in `docs/lore.md` (§VI), register in Hlidskjalf.
- **NOT:** hardcoded house list in code paths; cross-realm entity access.
- **KEEP:** the mythology naming; house split/merge only via a new append-only entry.