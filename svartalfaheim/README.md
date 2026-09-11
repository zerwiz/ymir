# SVARTALFAHEIM — Multi-Tenant Domains (Nine Realms)

Isolated tenant domains. Each tenant has its own secrets, projects, and memory.
**Tenant boundaries are sacred** — never read, write, or reference files outside the active tenant without explicit approval.

## Tenant Template
Each tenant contains:
- `.env.realm` — tenant-specific secrets (git-ignored, see `.env.realm.example`)
- `Brokk.md` — tenant persona, directives, and system prompt
- `projects/` — cloned GitHub repos (with `.yggdrasil/` worktrees)
- `workspace/` — scoped operational memory
  - `company/` — brand identity, offers, strategy
  - `marketing/` — campaigns, copy, social calendars
  - `development/` — specs, PRDs, architectural docs
  - `life/` — personal goals, habits, health, finances
  - `memory/` — daily logs, entity graph

## Tenants
| Tenant | Type | Owner | Workspace focus |
|--------|------|-------|-----------------|
| `way-of` | Company / shared | zerwiz + craig | Business, product (WOMONO, WOW, OPT), marketing, client work |
| `zerwiz` | Personal / operator | zerwiz (Josef) | Personal goals, life execution, solo ventures |
| `craig` | Member | craig | Personal goals, live execution, solo ventures |

## Creating a New Tenant
1. `cp -r way-of <new-tenant-slug>` (template is closest to an empty tenant)
2. Edit `Brokk.md`, `workspace/README.md`, `.env.realm.example`
3. Register it in `workspace/config/portfolio.md`
4. Create `projects/` repos for the tenant

## Naming Rules
- Tenant slugs: lowercase, hyphens, descriptive of the domain (`way-of`, `zerwiz`, `craig`)
- Never use `realm_*` placeholders — every tenant must have a real identity
- Inter-tenant messaging always routes through Ratatoskr, never direct file access