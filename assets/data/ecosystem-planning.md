# WayOf Ecosystem — Planning & Organization

> **Source:** `/home/zerwiz/command/plans/masterplan/` — the masterplan lives in
> the coding repo (`command`). This file is the **firstmate summary** — the
> planning/organizing view. When the captain needs to plan, organize, or
> review the ecosystem, read this file first, then drill into `command` for
> details.
>
> **Last synced:** 2025-09-09

---

## 1. Ecosystem Overview

### Product Platforms

| Product | Domain | Role |
|---|---|---|
| **Ona** | Family / personal | Personal AI orchestrator & squad (Solin + specialists). Dual Telegram bots, web UI, Electron, PWA. |
| **WayOfTeams** | Work / production | Main SaaS at `teams.zerwiz.org`. Multi-tenant: tickets, kanban, standups, skills, AI chat, analytics. |
| **Smíðja (`wayoffactory`)** | Engineering | Agents-plus-code pipelines. Equal to smidja, better stack. Productized as WayOfTeams feature. |
| **CloudSync** | Sync hub | Headless canonical sync hub. Edges push/pull/bootstrap/stream; LWW conflict resolution. |
| **AG&F (aigeeksandfreaks)** | Marketing | Marketing platform + blog (`aigeeksnfreaks.zerwiz.org`). Blog posts, landing pages, funnels. |
| **NorthStar Rules (NSR)** | Compliance | Canonical core ruleset for every Way-Of project. Mandatory doc structure, `.agents/skills/` automation, `.smidja/` deterministic harness. |

### Marketing Stack (on zerwizserver)

| Tool | Port | Role |
|---|---|---|
| **Postiz** | `4007` | Social media scheduler (X, LinkedIn, Reddit, Threads, FB, YouTube) |
| **Activepieces** | `8080` | Workflow automation (scrapers, posting, integrations) |
| **Mautic** | `8001` | Email marketing automation (campaigns, cron sends, forms) |
| **Playwright MCP** | `—` | Browser automation — scraping, social posting, testing, form filling via MCP |
| Temporal | `7233` | Postiz durable workflows |
| Grafana | `3003` | Dashboards |

### Integration Layers

| Layer | Role |
|---|---|
| **MCP Gateway** | Exposes every internal tool/resource/prompt to any AI client |
| **A2A mesh** | Agents talk to agents (a2abridge, per-agent MCP bridge) |
| **LiteLLM** | Unified model gateway — one key to all providers (cloud + local) |
| **CloudSync protocol** | State sync between instances/edges |

### Machines

| Asset | Role |
|---|---|
| `zerwiz` (Linux, `100.100.93.103`) | Primary dev box; a2abridge hub `:7777`; local LM Studio/Ollama/llama.cpp |
| `zerwizserver` (`100.88.238.83`) | Production host: WayOfTeams, CloudSync, Supabase, SearXNG, Forgejo, etc. |
| `zerwiz-1` (Windows) | Mirror workstation |
| `craigema` (Fedora/Podman/llama.cpp) | Third environment, miniforum server |

---

## 2. Decisions Log (Locked)

| # | Decision | Status |
|---|---|---|
| D-001 | Masterplan lives in `plans/masterplan/`; ecosystem AGENTS.md inside it | **Locked** |
| D-002 | `wayofpackets` monorepo is the target home for the refactored ecosystem | **Locked** |
| D-003 | Masterplan is design + decisions + open-questions (not a build spec) | **Locked** |
| D-004 | Dead products consolidated: CTO Dashboard → wayofteams; LinkableWork → domain-core; Way of Work → jido-agents + smidja | **Locked** |
| D-005 | Packet model: `packages/` (composable) + `apps/` (entry shells) + `tools/` | **Locked** |
| D-006 | Stack pillars documented as **target** — confirm each before locking | Candidate |
| D-007 | **NSR is the compliance layer** — every repo must pass NSR harness | **Locked** |
| D-008 | Integration via MCP gateway + A2A mesh (not bespoke bridges) | Candidate |
| D-009 | **smidja is reference only.** We build **`wayoffactory`** on a better stack | **Locked** |
| D-010 | **UX principle: "spaces, not everything at once."** | **Locked** |
| D-011 | **Client-first product.** Designed for external paying customers | **Locked** |
| D-012 | **Every project ships project-specific skills** (D-012) | **Locked** |
| D-013 | **Ona + Ona-Sphere are new builds.** Netlify apps are demos | **Locked** |
| D-014 | Repo layout fixed: `~/CodeP/ona`, `~/CodeP/sphere` | **Locked** |
| D-015 | **Multi-runtime agent strategy** (Jido + coding agents + Rust + pipeline) | Candidate |
| D-016 | **AG&F is our marketing platform** — socials via Postiz, email via Mautic, automations via Activepieces | **Locked** |

---

## 3. NorthStar Rules (NSR) — Key Principles

NSR is the **canonical core ruleset** for every Way-Of project. It is what keeps everything compliant.

### Core Principles (non-negotiable)

1. **Dual-layer docs** — root routing files + granular sub-documents
2. **Zero ad-hoc shell commands** — all operations via `.agents/skills/` scripts
3. **Dual smidja** — Embedded Agent Skill Smíðja + Standalone Electron Smíðja App
4. **Deterministic harness (`.smidja/`)** — Core Four config, code-based gates, typed envelopes
5. **WayOfTeams sync** — Kanban, Knowledge Base, Anchor Memory via MCP
6. **No feature duplication** — every feature registered in `FEATURES.md`
7. **Subfolder AGENTS.md** — every functional subfolder defines scoped boundaries
8. **Env-driven config** — no hardcoded values; secrets never committed
9. **Multi-deployment + multi-tenant** — env tiers, per-client deployments
10. **Relative paths only** — absolute paths forbidden and gated
11. **Cross-platform** — Mac/Linux/Windows (WSL/Git Bash)
12. **Hosting safety** — `docs/HOSTING/` documents every hosting
13. **Developer setup** — `docs/DEVELOPER_SETUP/` documents every dev
14. **Tech-stack mapping** — `TECH_STACK.md` maps every feature to its pinned stack
15. **Work with agents per the operating manual** — agents are bounded nodes
16. **Smíðja-ready skill set** — every project implements the skills in `docs/project-skills.md`

---

## 4. Build Sequence (Phases)

### Phase 0 — Scaffold masterplan (in progress)
- [x] Create `plans/masterplan/` folder + ecosystem AGENTS.md
- [x] Inventory (`ecosystem.md`)
- [x] Target architecture (`architecture.md`)
- [x] Target monorepo layout (`packets.md`)
- [x] NSR compliance layer (`northstar-rules.md`)
- [x] UX principles (`ui-ux.md`)
- [x] Decisions + open questions (`decisions.md`, `open-questions.md`)
- [x] Migration map (`migration-map.md`)
- [x] Link from root `command/AGENTS.md` + `README.md` to the masterplan
- [ ] Record masterplan in WayOfTeams memory/knowledge; open tracking tickets

### Phase 1 — Audit & confirm
- [ ] Audit every live repo against NSR acceptance criteria
- [ ] Confirm each stack pillar → lock ADRs in `decisions.md`
- [ ] Decide monorepo tooling (pnpm vs mix umbrella hybrid)
- [ ] Decide MCP gateway shape + A2A federation scope
- [ ] Decide `core-rust` approach (fresh vs extract Ona's Rust)
- [ ] Decide fate of `wayofcollab`, `wayofinvestready`, ona-sphere

### Phase 2 — NSR compliance bootstrap
- [ ] Run `.smidja/installer/` in target repos
- [ ] Stand up `TECH_STACK.md` / `FEATURES.md` / `STRUCTURE.md` per repo
- [ ] Add `.agents/skills/` lifecycle/git-ops/features/smidja scripts
- [ ] **Author project-specific skills (D-012)**
- [ ] Pass env/paths/platform gates everywhere
- [ ] Wire WayOfTeams MCP sync per repo

### Phase 3 — Refactor to packets/apps
- [ ] Establish `packages/` baseline
- [ ] Consolidate dead products
- [ ] Fold `apps/*` onto shared packets
- [ ] **UX spaces (D-010)** — define each app's landing + named spaces
- [ ] Universal MCP gateway + A2A mesh verified

### Phase 4 — Validation
- [ ] `tools/dev.sh` starts each app standalone AND the whole stack
- [ ] Smíðja smidja run against refactored repos
- [ ] CloudSync hub reconciles multi-edge state
- [ ] NSR acceptance gates pass for every migrated repo
- [ ] Trace UI + Langfuse observability

### Phase 5 — Productization
- [ ] Smíðja-as-feature shipped in WayOfTeams
- [ ] Pilot client on NSR-compliant `wayoffactory` distribution
- [ ] Ona ↔ WayOfTeams ↔ Smíðja full A2A/MCP interop in production

### Priority Order
1. **Phase 1 audit** (know where we stand)
2. **NSR compliance** (the standard everything hangs off)
3. **`packages/domain-core` + `jido-agents` extraction** (biggest leverage)
4. **MCP gateway + A2A** (integration backbone)
5. **`apps/*` consolidation** (Ona/WayOfTeams/Smíðja/CloudSync on shared core)

---

## 5. Marketing System (AG&F)

### Platform
- **Live site:** `https://aigeeksnfreaks.zerwiz.org` (Cloudflare tunnel → `localhost:3800`)
- **App:** Next.js 16 + Tailwind + shadcn/ui + Prisma (SQLite)
- **Pages:** homepage, meetups, courses, smidja, software-smidja, way-of-teams, shipped, login, admin API

### Capabilities
| Capability | Tool | How we drive it |
|---|---|---|
| **Social posting** (X, LinkedIn, Reddit, Threads, FB, YouTube) | Postiz | Postiz API/UI; scheduled via cron |
| **Auto-manage WhatsApp / Telegram groups** | Telegram bot (pi) + agents | `telegram-message-handler` skill |
| **Blog posts** | AG&F (Next.js + Prisma) | smidja write → review → publish → Post record |
| **Landing pages + marketing funnels** | AG&F pages | agents update page content; funnels tracked with UTM |
| **Email campaigns on cron** | Mautic | Mautic campaigns + cron workers |
| **Scrape potential clients** | Activepieces + crawl4ai | scrapers as workflows: find leads, enrich, drop into Mautic/AG&F |
| **Content calendar** | Postiz + AG&F | Postiz scheduling; AG&F admin |
| **Newsletter / digests** | Mautic | cron sends, segment-based |
| **Discord** | Discord bot | `discord-integration-plan` |

### Marketing Skills (callable from workflow)
| Skill/agent | Does |
|---|---|
| `marketing-content-creator` | write posts/articles/threads from outline; repurpose across channels |
| `marketing-scheduler` | schedule content (Postiz calendar, Mautic sends, cron) |
| `marketing-publisher` | publish to channels (Postiz, AG&F blog, Discord/Telegram) |
| `social-manager` | take care of socials: X, LinkedIn, Reddit, Threads; post + reply |
| `group-manager` | handle WhatsApp/Telegram groups (via Telegram bot) |
| `blog-writer` | write + publish AG&F blog posts |
| `funnel-updater` | update landing pages + marketing funnels (AG&F pages, UTM) |
| `email-campaigner` | build + send Mautic email campaigns (cron) |
| `client-scraper` | scrape potential clients (Activepieces + crawl4ai), enrich, hand to sales |
| `analytics-reporter` | pull engagement/reach/conversion (Postiz + Mautic + AG&F) |

### Marketing Open Items
- [ ] Wire **Activepieces** → **Postiz** + **Mautic** + **AG&F** automations
- [ ] Connect **social accounts** to Postiz (X, LinkedIn, Reddit, Threads…)
- [ ] Configure **Mautic** email domain + campaigns; test cron sends
- [ ] Build the **client-scraper** workflows (Activepieces + crawl4ai)
- [ ] Build marketing **skills** into `.agents/skills/`
- [ ] AG&F **blog publishing pipeline** (smidja smidja → Post → rebuild)
- [ ] **Telegram/WhatsApp group** management via the Telegram bot (pi)
- [ ] Track **funnels** with UTM + Mautic + Postiz analytics

---

## 6. Open Questions

### Stack
- [ ] Lock each stack pillar? (Elixir, Rust, LiteLLM, Postgres/DuckDB)
- [ ] DuckDB vs Postgres analytics split in practice
- [ ] Ona core runtime — Rust-native vs under shared Elixir core
- [ ] Qdrant vs pgvector for RAG/memory
- [ ] Langfuse self-host vs OpenTelemetry-only observability
- [ ] LiteLLM deployment — on zerwizserver, per-machine, or both?

### Agent Routing & Integration
- [ ] MCP gateway: one global vs per-product MCP servers
- [ ] A2A federation scope — stay on zerwiz hub or federate?
- [ ] `AGENTS.md`/YAML routing manifests — single canonical format or per-tool?
- [ ] LiteLLM routing granularity — per-product vs one shared catalog
- [ ] Multi-runtime split — confirm which workloads run on which runtime
- [ ] Jido scope — which agents stay Jido vs move to deterministic code

### Migration / Refactor
- [ ] Monorepo tooling — pnpm workspaces or mix umbrella + pnpm?
- [ ] `core-rust` packet — build fresh or extract Ona's existing Rust?
- [ ] `wo-agent` / `wo-ai` split — map as-is or restructure?
- [ ] WayOfTeams audit follow-ups — 13 Jido agents + 10 Oban workers + 13 MCP v2 servers
- [ ] Ona audit follow-ups — Rust workspace `systems/*`
- [ ] Sphere audit follow-ups — scaffold phase: pick runtime
- [ ] justfile rollout — every packet/app gets a `justfile`
- [ ] NSR rollout order — which repos go NorthStar-compliant first?

### Marketing (AG&F)
- [ ] Activepieces → Postiz + Mautic + AG&F wiring
- [ ] Postiz social accounts — connect X, LinkedIn, Reddit, Threads, FB, YouTube
- [ ] Mautic email domain + campaigns — configure sending domain, test cron sends
- [ ] Client scraper workflows — Activepieces + crawl4ai
- [ ] Marketing skills into `.agents/skills/`
- [ ] AG&F blog publishing pipeline — smidja smidja write→review→publish
- [ ] Telegram/WhatsApp group management
- [ ] Funnel tracking — UTM + Mautic + Postiz analytics

### Compliance (NSR)
- [ ] NSR vs this masterplan's structure — how does `plans/masterplan/` comply?
- [ ] NSR harness in existing repos — run everywhere or bootstrap incrementally?
- [ ] Enforcement owner — who/when runs the acceptance gates?

### Productization
- [ ] Smíðja-as-feature — pricing, tenant scoping, resource limits
- [ ] Client onboarding — do clients get NSR-compliant repos by default?
- [ ] sphere — role once the new build lands
- [ ] Client lifecycle — signup, tenant provisioning, billing/payment, support

### UX / Product
- [ ] Define each app's landing + named spaces (≤7 top-level spaces)
- [ ] Space naming — pick plain, user-facing names
- [ ] Landing litmus test — confirm each surface lets a new user complete their #1 reason in ~3 clicks / 30s
- [ ] Agent UX defaults — standard prompt/response guidance

---

## 7. Key Files in `command` (for drilling in)

| File | Purpose |
|---|---|
| `plans/masterplan/ecosystem.md` | Full ecosystem inventory |
| `plans/masterplan/architecture.md` | Cross-cutting concerns + compliance layer |
| `plans/masterplan/decisions.md` | ADRs + decision log |
| `plans/masterplan/open-questions.md` | Unresolved questions |
| `plans/masterplan/TODO.md` | Build sequence (phases) |
| `plans/masterplan/marketing.md` | Full marketing system plan |
| `plans/masterplan/northstar-rules.md` | NSR compliance layer |
| `plans/masterplan/packets.md` | Target monorepo layout |
| `plans/masterplan/ui-ux.md` | UX principles |
| `plans/masterplan/migration-map.md` | How existing repos become compliant |
| `plans/masterplan/project-skills.md` | Project-specific skills policy |
| `plans/masterplan/AGENTS.md` | Ecosystem agent rules |
| `plans/masterplan/README.md` | File map |

---

## 8. Server Inventory (zerwizserver)

> **IP:** `100.88.238.83` · **User:** `zerwizserver` · **OS:** Ubuntu 24.04.4 LTS
> **Last scanned:** 2025-09-09

### Cloudflare Tunnels (active hostnames)

| Hostname | Port | Service |
|---|---|---|
| `teams.zerwiz.org` | 4321 | WayOfTeams main app |
| `teamsapp.zerwiz.org` | 4000 | WayOfTeams teamsapp |
| `investwayofteams.zerwiz.org` | 5179 | Investor data room |
| `ws1.zerwiz.org` – `ws10.zerwiz.org` | 3101–3110 | WebSocket workers |
| `prdteams.zerwiz.org` | 3910 | Prod teams app (bun) |
| `collab.zerwiz.org` | 4003 | WayOfCollab |
| `anchor.zerwiz.org` | 42777 | Anchor app |
| `cloudsync.zerwiz.org` | 4214 | CloudSync hub |
| `zerwiz.org` / `www.zerwiz.org` | 4322 | WhyNot Homepage |
| `supabase.zerwiz.org` | 8000 | Supabase stack |
| `aigeeksnfreaks.zerwiz.org` | 3800 | AG&F blog/marketing |
| `dojo.zerwiz.org` | 8038 | Dojo |
| `linuxcommand.zerwiz.org` | 4601 | Smíðja visualizer |
| `masterplan.zerwiz.org` | 3900 | Masterplan homepage |
| `obsidian-sync.zerwiz.org` | 5984 | Obsidian LiveSync |
| `obsidian.zerwiz.org` | 15323 | Obsidian |
| `opticat.zerwiz.org` | 8083 | OptiCat web server |
| `forgejo.zerwiz.org` | 3030 | Forgejo git server |
| `casaos.zerwiz.org` | 80 | CasaOS gateway |

### Running Services

| Service | Port | Notes |
|---|---|---|
| WayOfTeams (beam.smp) | 4321, 4000 | ~3 days uptime |
| Anchor (beam.smp) | 42777 | ~9 days uptime |
| WayOfCollab (beam.smp) | 4003 | — |
| WhyNot Homepage (node) | 4322 | — |
| Postiz (Docker) | 4007 | Social scheduler |
| Mautic (Docker) | 8001 | Email marketing |
| Activepieces (Docker) | 8080 | Workflow automation |
| Temporal (Docker) | 7233 | Durable workflows |
| Grafana (Docker) | 3003 | Dashboards |
| Forgejo (Docker) | 3030 | Git server |
| CloudSync (Docker) | 4214 | Sync hub (healthy) |
| Homepage (Docker) | 3000 | Service dashboard |
| PostgreSQL | 5432 | Multiple instances |
| Redis | 6379 | Multiple instances |
| Samba | 139, 445 | File sharing |
| SSH | 22 | Tailscale + standard |

### Docker Containers (20+)
- `forgejo`, `docker-cloudsync-1`, `homepage`, `postiz`, `postiz-postgres`, `postiz-redis`
- `mautic-web`, `mautic-db`, `mautic-cron`, `mautic-worker`
- `activepieces`, `activepieces-postgres`, `activepieces-redis`
- `temporal`, `temporal-postgresql`, `temporal-elasticsearch`, `temporal-ui`, `temporal-admin-tools`
- `grafana`, `crafty-container`, `immich-redis`, `docker-postgres-1`

### Projects on Server (`/home/zerwizserver/`)
`wayofteams`, `prdteams`, `cloudsync`, `aigeeksandfreaks`, `anchor`, `wayofcollab`, `investwayofteams`, `masterplanhomepage`, `whynothomepage`, `opticat`, `sensualdojocouple`, `obsidian-livesync`, `forgejo`, `forgejo-backups`, `searxng`, `backups`, `flutter`

---

*This file is the firstmate planning summary. For full details, read the source files in `/home/zerwiz/command/plans/masterplan/`.*
