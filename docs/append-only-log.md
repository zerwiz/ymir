# YMIR — Append-Only Change & Planning Log

**Purpose:** Comprehensive, append-only record of every decision, research finding, and planned change for the Ymir Agent Operating System. Entries are **never edited or deleted** — corrections and revisions get new entries. `docs/lore.md` (company mythos) is written only after the naming section below is cleared.

**Format:** `YYYY-MM-DD-NNN` · Status: `proposed → approved → in-progress → done`
**Conventions:**
- Every entry states **ADD / NOT / KEEP** explicitly.
- Realm routes follow AGENTS.md: way-of (company), zerwiz (personal), craig (member).
- Append at the bottom. Never rewrite history.

---

## ENTRY 2026-09-11-001 — Scaffold & Tenant Reinstatement

- **Status:** done · **Owner:** Brokk/zerwiz
- **Context:** Built the Ymir monorepo skeleton per `Ymir.md` and AGENTS.md.
- **ADD:** Full folder tree (`.agents/`, `midgard/`, `svartalfaheim/`, `apps/`, `workspace/`, `docs/`); root `Structure.md`, `README.md`, `AGENTS.md`, `docker-compose.yml`, `Dockerfile`, `.env.example`, `.gitignore`; per-tenant `.env.realm.example` + `Brokk.md` + `workspace/README.md`.
- **NOT:** No application code yet (structure only). No template-tenant names.
- **KEEP:** `realm_alpha`/`realm_beta` replaced by real tenants.
- **Files:** `Structure.md`, `AGENTS.md`, `svartalfaheim/way-of|zerwiz|craig/`.

## ENTRY 2026-09-11-002 — Tenant Instances: way-of, zerwiz, craig

- **Status:** approved · **Owner:** zerwiz
- **Context:** User: "we are Way-Of with zerwiz (Josef) and Craig, I'm zerwiz."
- **DECISION:** Three tenants now exist as real identities:
  - `way-of` — company tenant (WayOf ecosystem: wayofteams, wayofwork, wayofcollab, OptiCat, InvestReady, softwerefactory, etc.), owners zerwiz + craig.
  - `zerwiz` — personal tenant, owner zerwiz (Josef), GitHub login `zerwiz`.
  - `craig` — member tenant, owner craig.
- **NOT:** `realm_*` placeholder names going forward.
- **ADD:** Tenant separation: `companies/` + `projects/` per tenant (partitioned below, pending clearance).
- **Files:** `svartalfaheim/*/Brokk.md`, `.env.realm.example`, `workspace/README.md`, `svartalfaheim/README.md`, root `README.md`, `Structure.md`.

## ENTRY 2026-09-11-003 — External-System Research: firstmate & command

- **Status:** approved · **Owner:** Brokk · **Source repos:** `/home/zerwiz/firstmate`, `/home/zerwiz/command`
- **Context:** Ymir must *manage what exists* instead of rebuilding it. Researched the two existing agent systems already on this machine.

| System | What it is | What it already gives us | KEEP (don't rebuild) |
|---|---|---|---|
| **command** (WayOf Command) | Ops command center for the whole WayOf ecosystem (`FEATURES.md`, `STRUCTURE.md`, `RULES/`, `.compliance/`, `tenants/josef`+`tenants/craig`, per-client deploy envs) | Software factory skill, compliance gates, telemetry, tenant dirs, runbooks, CI/CD per client | Everything in `.compliance/` (gates/envelopes/Core Four), factory, docs, tenant deploy config |
| **command-factory** (skill) | disler-style "Super Simple Software Factory": deterministic Python owns graph, agents bounded nodes, typed JSON envelopes, SQLite telemetry, Vue visualizer (`apps/visualizer/`, port 4601) | The entire build engine + trace UI | Factory scripts, roster/config, visualizer |
| **firstmate** | External agent distro by kunchenguid: one captain talks to a first mate that runs a crew of autonomous coding agents in tmux panes on git worktrees, with zero-token event-driven supervision, project modes (`no-mistakes`/`direct-PR`/`local-only`/`+yolo`) | Crew orchestration, worktree isolation (treehouse/orca), restart-proof disk state, supervision watcher, X/Discord Relay, secondmates | All crew/worker mechanics — do NOT write our own sub-agent supervisor |
| **software-compliance-research** (`command/docs/research/`) | History + working model of software factories (Bemer/Hitachi → Microsoft 2004 → disler 2023–26); orchestrator-worker, task packets, gates, "agent proposes, code disposes"; pitfalls (self-grading, token spirals, cost) | The knowledge layer Ymir needs for autonomous work | The compliance doctrine — it is the design law for Ymir skills |

- **NOT:** Building a new agent supervisor, new worktree manager, new compliance harness, or a second software factory. Ymir orchestrates and observes the above; it does not duplicate their mechanics.
- **ADD:** The *missing top layers*: Hlidskjalf portal, Mimirsbrunn memory, Ratatoskr bus, Runes audit, tenant/company/project registries, cron — see entries 004–006.
- **Þjazi backend**: Experimental agent-native terminal backend with native per-pane agent state and push events. Protocol floor covers versions 0.7.1, 0.7.3, 0.7.4, 0.7.5, and 0.8.0. Default-on presentation spaces require Þjazi 0.8.0. Þjazi dual-licensed AGPL-3.0-or-later or commercial. Firstmate invokes CLI as separate process. Þjazi provides terminal session while Treehouse provides task worktrees. (Research notes: `/home/zerwiz/firstmate/docs/herdr-backend.md`).
- **Files:** research notes above; anchors into `command/docs/research/*`.

## ENTRY 2026-09-11-004 — Company Houses (Naming) — PROPOSAL, AWAITING CLEARANCE

- **Status:** proposed · **Owner:** zerwiz (needs approval before `docs/lore.md` is written)
- **Context:** User supplied the approved name palette: **Runestone Labs / Runir · Brokk (Brokkr) Forge · Mannheim · Askr · Utgard Studios · Ymir Labs · Muninn Labs · Dvalin**. Rejected: Mimirsbrunn, Heimdall, Fenrir, Audumbla, Ratatoskr, Garm, Vidar. Rule: *"companies are named what the companies are — but each belongs under one of the suggested house names."*
- **PROPOSED MAPPING** (real ventures discovered in `command/FEATURES.md`):

| House (brand family) | Category | Real ventures belonging |
|---|---|---|
| **Ymir Labs** | Umbrella / platform | Ymir OS, Hlidskjalf, Mimirsbrunn, the master fleet itself |
| **Brokk Forge** | Engineering / build studio | WayOf Command, softwerefactory, wayofmono, way-of-pi, wot-setup, pip/pppi harnesses |
| **Runestone Labs / Runir** | Records / compliance / docs | `.compliance`, runes_audit, docs, runbooks, research |
| **Muninn Labs** | Memory / knowledge | Anchor + anchor-memory, Mimirsbrunn, vector RAG |
| **Dvalin** | Tooling / craft | OptiCat (HVAC Pro), Linkable, Todo, Desk, Material Files |
| **Utgard Studios** | Creative / entertainment | WhyNot Productions, AiPic (video), OpenChamber, sensual dojo |
| **Askr** | Human / personal | Relocation Copilot, onboarding, "first-man" human-first products |
| **Mannheim** | Holding / ops (TBD) | *Available* — assign to a real ops/legal holding entity |

- **NOT:** Writing `docs/lore.md` until the mapping above is approved/changed by the user.
- **ADD (after clearance):** `docs/lore.md` (mythos), a company entity card per house under `svartalfaheim/way-of/companies/`, and a `FEATURES` entry per house for the agentic coding tools.
- **Files:** n/a yet (pending).

## ENTRY 2026-09-11-005 — Company/Project Separation (Data Model)

- **Status:** proposed · **Owner:** zerwiz
- **Context:** "Companies and projects need their own separate places. Personal companies & projects are in their own places, with owners and realms."

```
svartalfaheim/
├── way-of/   (company realm)
│   ├── companies/      # company entity cards (houses 004)
│   │   └── <house-slug>.md   # name, owner, realm, products, repo, status
│   └── projects/       # COMPANY projects (wayofteams, wow, opt, …)
├── zerwiz/   (personal realm → OWN place)
│   ├── companies/      # personal/solo companies
│   └── projects/       # PERSONAL projects
└── craig/    (member realm → OWN place)
    ├── companies/
    └── projects/
```

Entity card fields: `name, type (company|personal), owner (zerwiz|craig), realm, house, products[], repo, status`.
- **ADD:** `companies/` dirs per tenant; entity-card template (`.agents/assets/templates/company_entity.template.md`); a `FEATURES.md` registry per house.
- **NOT:** Merging company and personal projects into one pool.
- **Files:** `svartalfaheim/*/companies/`, `Structure.md` (update), template asset.

## ENTRY 2026-09-11-006 — Features To ADD vs NOT (agentic tooling)

- **Status:** proposed · **Owner:** Brokk
- **Context:** "Get all the houses into features for agentic coding tools."

**ADD to `docs/plans/` (agent-facing feature plans):**
- `21-company-houses.md` — house registry + entity cards + per-house `FEATURES.md`
- `22-hlidskjalf-portal.md` — unified observability (factory visualizer, firstmate fleet, Ymir Runes, tenant switcher)
- `23-ymir-command-observer.md` — Ymir monitors `command` + `firstmate`; reads their state, does not edit them
- `24-cron-schedule.md` — daily brief 07:00, git backup, social poster

**NOT build (reuse instead):**
- No new factory engine (use `command-factory`)
- No new crew supervisor/worktree manager (use `firstmate`)
- No new compliance harness (use `.compliance/`)
- No new coding agents (use Pi / opencode / LM Studio already wired)
- No new trace DB/visualizer (use factory visualizer)

**KEEP & align:** Norse naming must not collide with existing subsystem names (Ratatoskr, Heimdall, Mimirsbrunn already taken by Ymir components — the houses list above excludes them).

- **Files:** `docs/plans/21…24` (created next).

## ENTRY 2026-09-11-007 — Kaia / engram memory researched → Mimirsbrunn engine

- **Status:** approved · **Owner:** Brokk/zerwiz
- **Context:** User: "read memory.md in command — we are using an open-source memory system for Kaia. We could use that here too." Ymir must keep its mythology naming and lore while *reusing* the proven memory engine instead of building its own.
- **RESEARCH — Kaia's memory (command MEMORY.md + `scripts/kaia-memory-bridge.py`):**
  - Library: **`engram` / `engdbram`** from the **TAIPANBOX** agent-governance stack (PyPI `engdbram`, v2.2.1). Open-source, runs locally via stack-up.
  - Store: a single `.engram` file = SQLite + `sqlite-vec` (KNN vectors, 384-dim via `fastembed` ONNX `bge-small-en-v1.5`) + FTS5 (BM25) + local embeddings. No server, WAL, committed per project.
  - Memory model: **episodes** (content, actors, tags, salience, importance, agent_id), **facts** (SPO triples, valid_from/superseded_at), **entities/edges** (graph for spreading activation), plus `reflect()`/`decay()`/`compress()`/`export-import`.
  - Recall: `hybrid` (0.5 cosine + 0.5 BM25, default), `cosine`, `spreading` (0.6 cosine + 0.3 graph + 0.1 importance). Agent-scoped (`agent://zerwiz/kaia`), `as_of` time-travel, access-log importance decay.
  - Bridge: `scripts/kaia-memory-bridge.py` → HTTP on `127.0.0.1:4602` — `GET /health`, `/inspect`, `/recall?q&k&mode`, `/timeline?entity`, `POST /observe`.
  - Factory wiring: `kaia_memory_for(project)` recalls top-k before orchestration/evaluation (memory is a *boost, never a blocker*); writers are `factory teach` (deterministic, no tokens), `factory learn`/auto-learn (structured run outcome), `--recon` scout maps; visualizer proxies `#/memory`.
- **DECISION (mythology kept):** Adopt engram as the engine of **Mimirsbrunn** (the well at the root of Yggdrasil). Ymir will ship the same bridge pattern at `:4602`, per-tenant/sea `.engram` stores, and expose recall via the Runes-audited `workspace_rag` skill. **Kaia** remains the oracle/memory voice (Mímir's voice by the well) — the engram well, the Kaia voice, the Mimirsbrunn name.
- **ADD:** `.agents/memory/` = engram bridge + per-tenant stores; docker-compose service `memory-bridge`; `workspace_rag.ts` uses `/recall` + `/observe`; Hlidskjalf `#/memory` view mirrors the factory visualizer's.
- **NOT:** A new vector DB, a new embedding stack, or a reimplementation of episodic recall — reuse `engdbram` + the bridge contract.
- **KEEP:** Norse naming (Mimirsbrunn/Kaia/Runes) and house lore from ENTRY-004.
- **Files:** `command/MEMORY.md`, `command/scripts/kaia-memory-bridge.py`, `.agents/memory/`, `docs/lore.md`.

--- (pending user clearance)

1. Approve/adjust ENTRY-004 house mapping → I write `docs/lore.md` + house entity cards.
2. Approve ENTRY-005 → I create `companies/` per tenant + entity template.
3. Approve ENTRY-006 → I create the four new `docs/plans/*` feature docs.
4. After any approval, append a new entry **below this line** recording the decision. Never edit entries above.

## ENTRY 2026-09-11-008 — Platform Doctrine: Reuse OSS, Differentiate on UI/UX + Runtime + A2A

- **Status:** approved · **Owner:** zerwiz · **Directive:** "If there are open-source validated projects, we use them instead of building everything ourselves for features. We will focus on the UI and UX, the agents runtime, and how the agents are collaborating. We need a great A2A system."
- **RESEARCH — agent-interop landscape (2026):**
  - **A2A Protocol v1.0** (Linux Foundation, donated by Google, Apache-2.0) is the **de-facto agent-to-agent standard**: absorbed IBM's **ACP** (Aug 2025), 150+ orgs incl. AWS/Azure/Vertex/Salesforce/SAP, v1.0 production-stable early 2026, ~22k+ stars on the core repo.
  - Wire format: **JSON-RPC 2.0 over HTTP(S)** + SSE for streaming; optional gRPC binding. Discovery via **Agent Cards** at `/.well-known/agent-card.json` (RFC 8615), JWS-signed cards. **Task lifecycle**: SUBMITTED → WORKING → COMPLETED/FAILED/REJECTED/CANCELED/INPUT_REQUIRED/AUTH_REQUIRED; terminal states cannot restart → retry/idempotency lives in the orchestrator.
  - **MCP complements, not competes**: MCP = vertical (agent→tools/resources), A2A = horizontal (agent↔agent, opaque, stateful tasks). Composed: an orchestrator delegates via A2A; each specialist uses MCP internally. Auth: OAuth 2.0 / API-key / mTLS, scoped per Agent Card; observability via OTel W3C trace context across every hop. SDKs: Python, JS/TS, Go, Java, .NET, Rust.
  - Ymir already carries a working **`a2a-bridge` skill** + integrated `a2a_*` tools (A2A 1.0 over local discovery) — reuse, don't re-derive.
- **DECISION — Ymir owns three things and reuses everything else:**
  - **Own & build:** **UI/UX (Hlidskjalf)**, the **agent runtime** (Brokk/Eindri/Kaia lifecycle, worktrees, sandbox, memory loop), and **A2A collaboration** (Ratatoskr as an A2A 1.0 backbone).
  - **Reuse validated OSS for every feature below the runtime:** engram (Mimirsbrunn), Redis (Ratatoskr queue), Traefik/Caddy + OAuth2-proxy/Authentik (Bifrost/Heimdall), cloudflared (Gjallarhorn), MinIO/FileBrowser (Skrymir), the factory visualizer + React/Vue (Hlidskjalf), PM2/Docker (Valhalla), MCP servers (all tool access), `command-factory`/`firstmate` (orchestration/supervision), `a2aproject/a2a` + SDKs (interop).
  - **Ratatoskr = A2A 1.0 backbone:** agent-card registry (Svartalfaheim-scoped discovery), Redis pub/sub as the queue *under* the A2A task model, signed cards via Heimdall, every A2A message observed into Mimirsbrunn and logged to Runes.
  - **Kaia as A2A orchestrator:** dispatch Eidri specialists as A2A tasks (SSE streaming), recall memory before dispatch, honour the `orchestrator_dispatched` gate; specialists reach tools via MCP.
- **ADD:** plan `docs/plans/25-ratatoskr-a2a.md`; AGENTS.md **law 8 (Open-source first)**; Ratatoskr section rewritten around A2A 1.0.
- **NOT:** a new inter-agent protocol, a new queue system, rebuilt portal/visualizer primitives, bespoke feature builds where a validated OSS project already exists.
- **KEEP:** Norse naming + house lore (Norse shells over OSS engines, per ENTRY-004/007); command/firstmate/factory; MCP for all tool access.

## ENTRY 2026-09-11-009 — Ymir Rut v2.6 spec adopted; stack = TypeScript + Python (port later)

- **Status:** approved · **Owner:** zerwiz · **Directive:** "Write down everything we have talked about. Add Ymir Rut — System Structure & Repository Layout Specification / Technical Architecture / Multi-Tenant Agent OS v2.6. Update README and documents more — incorporate my findings and sayings. **Use TypeScript and Python for now. No Rust — keep the stack simple for agents. Port to other stacks later when everything works end-to-end.**"
- **DECISION — Ymir Rut is the TARGET architecture** (Rust/Cargo workspace, NATS JetStream, Envoy, gRPC/Protobuf, PostgreSQL 16, libgit2, Cgroups v2/128GB, 98.4% traceability index, design system).
- **CURRENT STACK (build today):** **TypeScript (Node) + Python 3.12+**; Rust is NOT introduced now. Every Norse module gets a TS/Python service that *maps one-for-one* to a future Rut crate — so the port is a refloor, not a redesign.
- **ADD:** `docs/ymir-rut.md` (verbatim v2.6 spec, three parts, with current-stack reconciliation), upgraded `docs/Architecture.md` (topology, 7 realms, A2A, engram memory, OSS-first stack table, TS/Python stack, Rut port path), richer `README.md` (brand, design system, realms, stack table, docs index), plan docs 21–24.
- **Rut→current mapping (foundation):** bifrost→TS gateway service (Traefik/Caddy) · hlidskjalf→TS/React portal · svartalfaheim→TS tenant/credential daemon · ratatoskr→TS A2A backbone + Redis · yggdrasil→TS worktree manager (git CLI/libgit2 bindings later) · utgard→Python/Docker sandbox · brokk→Python/TS agent harness · storage→Postgres 16 (self-hosted) + MinIO later; engram (Mimirsbrunn) stays the memory well.
- **NOT:** Rust/Cargo now, custom protocols, bespoke infra where OSS exists.
- **KEEP:** the mission line, Norse lore, house palette (ENTRY-004), A2A doctrine (ENTRY-008), engram memory (ENTRY-007).

## ENTRY 2026-09-11-010 — Stack précis: TypeScript + Python + React + Vue (clarification to ENTRY-009)

- **Status:** approved · **Owner:** zerwiz
- **Context:** User mid-flight clarification: "and react, and vue, we keep stack stat agents are good at."
- **DECISION — the CURRENT stack is the agent-proficient stack:** **TypeScript (Node), Python 3.12+, React, Vue.** Hlidskjalf/Frontends = **React + Vue** (claims from the factory visualizer's Vue precedent); services/daemons/orchestration = **TypeScript + Python**; gRPC-free, JSON-RPC/HTTP + Redis over Unix sockets. **No Rust/Cargo, NATS, Envoy, or Protobuf now** (those remain the Rut v2.6 *target* for a later re-floor per ENTRY-009). Port policy: every TS/Python service decomposes into its future Rubicon crate without redesign.
- **KEEP:** Ymir Rut v2.6 spec as target (docs/ymir-rut.md); OSS-first (ENTRY-008); engram memory; Norse naming.

## ENTRY 2026-09-11-011 — Design document v1.0 + tokens

- **Status:** done · **Owner:** zerwiz
- **ADD:** `docs/design.md` — master design document (philosophy "Carved, not skinned", emblem/typography/color/space/motion system, Hlidskjalf component spec, data-viz rules, voice, a11y); `midgard/design-system/tokens.css` — consumable CSS tokens (single source; React + Vue consume the same set; no per-framework drift). House accents proposed (ENTRY-004 houses → accent colors).
- **NOT:** per-framework color palettes; emoji in UI (rune-glyph set instead); color-only status indication.
- **KEEP:** Rut v2.6 design-system rules as the base; next artifact = `midgard/design-system/icons.md` (rune-glyph map).

## ENTRY 2026-09-11-012 — Lore v2: the updated mythos

- **Status:** done · **Owner:** zerwiz
- **ADD:** `docs/lore.md` v2 — now canon for everything since ENTRY-004/007/008/009: the **Seven Gates** (Bifrost, Hlidskjalf, Svartalfaheim, Brokk, Utgard, Yggdrasil, Ratatoskr), **Kaia's charge** (recall before dispatch, the veil = anti-hallucination gate), **Ratatoskr's law** (§V.b: Agent Cards = runes of introduction signed by Heimdall; task states announced; observed + carved), house **seals** (accent colors from design.md), new **Forge-Master's Rule** (§VII, OSS-first = borrowed anvils), and **The Reforging** (§VIII, TS/Python/React/Vue first, Rut-steel port one-for-one after end-to-end).
- **NOT:** renaming houses or artifacts already fixed by ENTRY-004; subsystem-vs-house blur (kept sacred).
- **KEEP:** Hermóðr, Þjazi, and all artifact mappings unchanged; design.md and lore.md cross-reference.

## ENTRY 2026-09-11-013 — Masterplan (append-only)

- **Status:** done · **Owner:** Brokk
- **ADD:** `docs/masterplan.md` — append-only forge-order register: orders W0001–W0025 consolidating the Architecture build order (P1–P11), approved/proposed plans 21–25, and the open artifacts (`icons.md`, plan docs 01–20). Contract: never edit an order, close with `+ <date> COMPLETED —`, new work appended with next id, supersession via §4.
- **NOT:** adding to-do lists elsewhere; plans 21–25 stay canonical for their scopes.
- **KEEP:** W0022 (companies/projects entities) awaits human "go"; W0024 (Rut port) BLOCKED BY DESIGN until P1–P10 end-to-end.

## ENTRY 2026-09-11-014 — Plan 28: Hlidskjalf Rise (frontend + backend build)

- **Status:** done (plan written, DRAFT) · **Owner:** Brokk
- **ADD:** `docs/plans/28-frontend-backend-build.md` — the build plan for everything left in FE+BE: reference UI contract (`assets/reference/index.html`: tokens + shell CSS + realm tints way-of=cyan/zerwiz=violet/craig=amber), target architecture (Fastify gate, Heimdall GitHub OAuth, workspace auto-provisioner, Hermes worker runtime, Mimirsbrunn/Runes, Ratatoskr wiring, Mjollnir, **PI primary boot via firstmate adoption** with Pi supervision branch), FE-0…FE-7 and BE-0…BE-8 build orders, phase sequencing A→B→C (auth→workers→PI) with D/E free, and new masterplan orders **W0026–W0032** appended.
- **NOT:** re-writing existing plans 01–20/26/27; renumbering (renamed to 28 to clear the firstmate 26/27 rows); names changed (Hermes = worker profile, pending captain confirm).
- **KEEP:** OSS-first (firstmate reused for PI boot, not rebuilt); tokens extracted verbatim; W0026–W0032 are refs to plan 28.

## ENTRY 2026-09-11-015 — Gap audit vs assets/Ymir.md → W0033–W0038 + scope notes

- **Status:** done · **Owner:** Brokk
- **ADD:** Full audit of plan 28 + masterplan against the complete Commando Central blueprint (`assets/Ymir.md`, 4656 lines). Coverage confirmed for auth, provisioning, Hermes runtime, PI primary boot, shell, live stream, A2A, memory, isolation, pipeline, ops. **Six new masterplan orders** appended:
  - W0033 Toolchain registry & provider wrappers (toolchain.md + .agents/tools/*)
  - W0034 App-Fleet registry + process controller (portfolio.md, register_foreign_app, process_controller over PM2/Docker/systemd/npm)
  - W0035 Zero-trust GitHub deploy (gh secret sync + workflow dispatch)
  - W0036 Omnichannel gateway (Telegram bot + notify_user + web drawer)
  - W0037 Hlidskjalf Mobile (Expo React Native)
  - W0038 Workspace RAG + entity-graph facade (hybrid Markdown+vector over workspace/ with engram engine)
- **Scope notes appended:** W0008 (cross-tenant/personal→HQ inter-agent comms on Ratatoskr; inter_agent_audit = Runes) and W0030 (per-tenant Hermes.md persona + hermes.config.json + hermes_runner.ts + tenant_context_loader boundary). [assets/Yimir.md §341–178, 301–373].
- **NOT:** rewriting existing orders; templates & container fold into W0022/W0002 as scope notes; multi-tenant Hermes already scoped to W0030.
- **KEEP:** masterplan as authoritative; plan 28 §8 records the audit; all new work is append-only.

---

---

---

---
## ENTRY 2026-09-11-009 — A2A Documentation Integration

- **Status:** proposed · **Owner:** Brokk
- **Context:** Discovered A2A 1.0 documentation across `docs/plans/25-ratatoskr-a2a.md`, `AGENTS.md`, and `.a2a/bridge.log`. Documentation establishes Ratatoskr as the A2A 1.0 backbone, documents open-source reuse policy, and defines acceptance criteria for agent interoperability.
- **ADD:** A2A plan reference integration; open-source first law reinforcement; Ratatoskr/Ratatoskr bridge skill pattern documentation.
- **NOT:** Custom A2A protocol development; duplicate queue systems; rebuilding existing A2A components.
- **KEEP:** Norse naming conventions; `InterAgentMessage` schema; `a2a-bridge` skill pattern; MCP for tool access; `a2aproject/a2a` SDKs.
- **Files:** `docs/plans/25-ratatoskr-a2a.md` reviewed and referenced; `AGENTS.md` law 8 confirmed; `.a2a/bridge.log` integration noted.

## ENTRY 2026-09-11-012 — Firstmate Planning Integration

- **Status:** proposed · **Owner:** Brokk/zerwiz
- **Context:** Integrated agentic engineering workflow plans from Firstmate system (Dex Horthy's four-layer program design framework). Nine planning documents from `/home/zerwiz/firstmate/docs/plans/` incorporated into Ymir documentation structure.
- **ADD:** Four-layer framework (Product/Layer1, Architecture/Layer2, Program Design/Layer3, Vertical Slices/Layer4) documented alongside Ymir's existing five realms and A2A backbone. Measurable goals, context budget awareness, pre-mortem confidence checks, and incident-to-agent pipeline patterns documented.
- **NOT:** Rebuilding Firstmate's factory engine — Ymir reuses validated OSS projects (command-factory, firstmate) per ENTRY-008 open-source first doctrine. Only UI/UX, agent runtime, and A2A collaboration differentiated.
- **KEEP:** Norse mythology naming conventions (Mimirsbrunn well, Brokk agent, Eindri workers, Utgard sandboxes, Runes audit, Gjallarhorn tunnel, Bifrost proxy, Heimdall auth, Valhalla supervision). All firstmate plan references use Norse-styled section names.
- **Files:** `docs/plans/` integration notes; `docs/Architecture.md` updated with workflow integration; `docs/append-only-log.md` entries recorded.

## ENTRY 2026-09-11-016 — Subsystem rename: `command-factory` → **Smíðja** (+ **Völundr**)

- **Status:** ADOPTED · **Owner:** Brokk · **Authority:** Allfather directive 2026-09-11.
- **Context:** The adopted upstream software-factory skill still carried the imported name `command-factory` (and its orchestrator skill `orchestrator-kaia`). The Norse naming law (`.agents/assets/agents/naming.md`; `galdr/assets/norse-naming.md` §5/§6) requires every subsystem to carry the figure whose role matches its work, and forbids imported terms from naming Ymir components.
- **DECISION — the factory is now Smíðja; its orchestrator is Völundr.** Smíðja (the *smithy*) is the workshop — the repeatable agent+code engine (rosters, bounded phases, typed envelopes, retries/acceptance, trace). It is **not** the platform (that remains **Ymir**) and **not** the house (that remains **Brokk Forge**). Völundr (Wayland the Smith) is the factory's own orchestrator — *Kaia's seat inside the factory* (Kaia decides *what* is forged; Völundr decides *how* the smithy runs).
- **RENAME (executed):** `.agents/skills/command-factory/` → `.agents/skills/smidja/`; `.agents/skills/smidja/skills/orchestrator-kaia/` → `.agents/skills/smidja/skills/volundr/`; skill frontmatter `name: factory` → `name: smidja`, `name: orchestrator-kaia` → `name: volundr`.
- **ADD:** `docs/lore.md` §XI (Smíðja — the Smithy); registry rows in `.agents/assets/agents/naming.md` (`platform[26]`) and `galdr/assets/norse-naming.md` §3.1; reject rows (§6.2) for `command-factory`/`factory` → **Smíðja** and for `Smíðja` as a **platform** name → **Ymir**.
- **NOT:** `Smíðja` is not a second platform name (the platform is Ymir); `factory` is not to be used as a Ymir component name. Upstream "Super Simple Software Factory" remains a provenance citation only.
- **KEEP:** the upstream engine adopted as-is (borrowed anvil, per ENTRY-008); the sibling factory command verbs (`factory.config.yaml`, `factory-launcher`, `start-the-factory`) are unchanged pending a separate config/CLI rename pass.
- **Files:** `.agents/skills/smidja/**`, `.agents/assets/agents/naming.md`, `.agents/skills/galdr/assets/norse-naming.md`, `docs/lore.md`, `docs/plans/28-frontend-backend-build.md`.
