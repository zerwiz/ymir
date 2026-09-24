# YMIR — Master Architecture

Status: **DRAFT v0.2** — consolidates `Ymir.md`, the Ymir Rut v2.6 target spec
(`docs/ymir-rut.md`), the A2A collaboration doctrine (ENTRY-008), the engram
memory engine (ENTRY-007), the house system (ENTRY-004), and the OSS-first
stack ruling (ENTRY-009/010).

> **Stack ruling (today):** **TypeScript + Python + React + Vue** — the agent-proficient
> stack, so agents can run and extend the whole platform. Rust/Cargo, NATS, Envoy,
> and Protobuf are the **Ymir Rut v2.6 target** and are ported to *after* the system
> works end-to-end. Every service below maps one-for-one to a future Rut crate
> (see **§6** and `docs/ymir-rut.md`).

## 1. What Ymir Is

Ymir is a lean, single-operator agentic operating system. One person runs an entire
**business, software development, marketing, and personal life** from a single
repository, orchestrated by autonomous Norse-named agents.

- **Local-first** — everything runs on your machine or your VPS via Docker Compose.
- **Mythos-first** — names are load-bearing allegory, not decoration (`docs/lore.md`):
  the giant (Ymir), the smiths (Brokk/Eindri), the well (Mimirsbrunn), the houses.
- **OSS-first** — for every feature below the runtime, adopt a **validated open-source
  project** first; Ymir owns only the **UI/UX (Hlidskjalf)**, the **agent runtime**
  (Brokk/Eindri/Kaia), and **A2A collaboration** (Ratatoskr).
- **Self-aware** — `AGENTS.md` in the root governs every agent's behavior.
- **Isolated-by-default** — sub-agent code executes in ephemeral containers (Utgard)
  on isolated git worktrees (Yggdrasil).
- **Memory-native** — every action is *observed* into Mimirsbrunn (engram) and
  *carved* into Runes; agents recall before they act.
- **Autonomous** — cron jobs, GitHub webhooks, and an A2A message backbone keep
  agents working while you're away.
- **Multi-tenant** — every realm (client/brand/division) gets fully isolated memory,
  secrets, and projects.

## 2. System Topology (7 realms / modules)

```
                         ┌─────────────────────────────────────┐
                         │        USER INTERFACES              │    React · Vue
                         │  Telegram  │  Web Portal (Hlidskjalf)│
                         └──────────────┬──────────────────────┘
                                        │ HTTPS / WebSockets
                         ┌──────────────▼──────────────────────┐
                         │        GJALLARHORN (Tunnel)          │
                         │        cloudflared outbound          │
                         └──────────────┬──────────────────────┘
                                        ▼
                         ┌──────────────────────────────────────┐
                         │  BIFROST (Gateway / Reverse Proxy)   │  Traefik/Caddy + Heimdall
                         │  + HEIMDALL (OAuth · signed cards)   │
                         └──────────────┬──────────────────────┘
                                        ▼
┌───────────────────────────────────────────────────────────────────────┐
│                          YMIR CORE (TS/Python)                       │
│                                                                       │
│   ┌──────────────┐   ┌────────────────┐   ┌────────────────────────┐ │
│   │   AGENTS.md  ├──►│ Brokk/Kaia     ├──►│  GUNGNIR Skill Engine  │ │
│   │  (Root Laws) │   │ Orchestrator   │   │  (Validated skills)    │ │
│   └──────────────┘   └───────┬────────┘   └────────────────────────┘ │
│                              │  A2A 1.0 dispatch (delegation)         │
│   ┌──────────┬───────────────┼──────────┬──────────────────────┐     │
│   ▼          ▼               ▼          ▼                      ▼     │
┌──────────┐┌──────────┐ ┌───────────┐┌───────────┐         ┌──────────┐│
│MIMIRSBRUNN│ RATATOSKR│ │ YGGDRASIL ││ UTGARD    │         │ MJOLLNIR ││
│ engram    │ A2A 1.0  │ │ git       ││ Docker    │         │ Issue→PR ││
│ bridge    │ + Redis  │ │ worktrees ││ sandbox   │         │ pipeline ││
└──────────┘└──────────┘ └───────────┘└───────────┘         └──────────┘│
└───────────────────────────────────────────────────────────────────────┘
```

- **Svartalfaheim** holds the realms (one directory per tenant) and per-tenant
  A2A discovery; **Midgard** is the shared cross-tenant space; **Runes** is the
  immutable ledger; **Valhalla** supervises the processes. The **meeting layer**
  (**Snotra**, the ear, and **Þing**, the assembly hall) sits beside the core —
  capture on the meeting seat, transcription on the GPU seat, the record served
  from the heart (§3.13).

## 3. Core Subsystems

### 3.1 Agent Runtime — Brokk, Eindri & Kaia
- **Brokk** is the primary autonomous agent — single-operator executive partner
  (Development, Marketing, Business Strategy, Life Execution).
- **Eindri** workers are isolated sub-agents spawned for delegated tasks, always
  inside Utgard sandboxes on Yggdrasil worktrees.
- **Kaia** is the orchestrator + the oracle by the Well: she recalls Mimirsbrunn
  before dispatch, honours the anti-hallucination gate, and dispatches specialists
  as **A2A tasks** (SSE streaming); specialists reach tools via **MCP**.
- Realm personae in `svartalfaheim/<realm>/Brokk.md`.

### 3.2 Memory — Mimirsbrunn (engram engine) + Runes
Adopted from Kaia's proven smidja memory (ENTRY-007): the well is **engram**
(`engdbram`, open source — single-file SQLite + sqlite-vec + FTS5 + local embeddings).

| Tier | Name | Engine | Use |
|------|------|--------|-----|
| Tier 1 | Hot / Active | `svartalfaheim/<realm>/workspace/**/*.md` | Human-readable identity, goals, tasks |
| Tier 2 | Deep memory | **engram** store served by the bridge (`:4602`) | episodic recall, hybrid/cosine/spreading |
| Tier 3 | Audit | `workspace/memory/runes_audit.md` | append-only ledger (Runes) |

- Every significant action → `POST /observe` (episode into the well) + Runes entry.
- Before acting: `GET /recall` — "what does the well remember about this project?"
- **Memory is a boost, never a blocker** — a dry well fires cold, never stops the forge.

### 3.3 Skills — Gungnir
- Recurring tasks become scripts/skills in `.agents/skills/`.
- Self-synthesis loop: identify gap → write skill → **validate in Utgard** → register.
- Skill index: `.agents/skills/README.md`.

### 3.4 Isolation — Yggdrasil + Utgard
- **Yggdrasil**: complex tasks never edit the main tree; each agent gets
  `./<repo>/.yggdrasil/<agent-id>/` on its own branch (`.treehouses` in Rut terms).
- **Utgard**: untrusted code, dynamic skills, Eindri tasks run in ephemeral Docker
  containers, `--network none`, strict CPU/RAM/timeouts, no root. A failed run never
  touches main. Destroyed on completion (ephemeral lifecycle).

### 3.5 Inter-Agent Bus — Ratatoskr (A2A 1.0 backbone) ⭐
The collaboration differentiator (ENTRY-008). Built on the **open A2A Protocol v1.0**
(Linux Foundation), NOT a bespoke bus:

- **Agent Cards** at `/.well-known/agent-card.json`, realm-scoped registry; discovery
  = capability, never endpoint guessing. Cards JWS-signed via Heimdall.
- **Task lifecycle**: SUBMITTED → WORKING → COMPLETED/FAILED/REJECTED/CANCELED/
  INPUT_REQUIRED/AUTH_REQUIRED; terminal states never restart (retry/idempotency
  lives in the orchestrator).
- **Redis pub/sub** is the queue *under* the A2A task model (semantics on A2A,
  throughput on Redis).
- Every A2A message is **observed into Mimirsbrunn** and **logged to Runes**.
- The `a2a-bridge` skill is the canonical collaboration skill (inbox per turn,
  complete tasks, FYI peers on contract/schema/infra changes).
- Plan: `docs/plans/25-ratatoskr-a2a.md`.

### 3.6 Multi-Tenancy — Svartalfaheim
- Each realm = isolated domain: `.env.realm`, `Brokk.md`, `projects/`, `companies/`,
  `workspace/`.
- **Rut specification:** realm::namespace + vault::keys — memory pages, env vars, and
  credential tokens cannot cross tenant boundaries (`sandbox_isolated`).
- Realm context loader (`tenant_context_loader.ts`) verifies boundaries before any task;
  cross-realm A2A requires an explicit grant.

### 3.7 Global Shared Space — Midgard
- Cross-tenant repos, design system, shared packages, infrastructure, company wiki.
- Parallel work uses Yggdrasil worktrees inside `github_org_repos/`.

### 3.8 Gateway & Security — Bifrost, Heimdall, Gjallarhorn
- **Bifrost**: Traefik/Caddy routes `/` → Hlidskjalf, `/files/` → Skrymir,
  `/webhooks/github` → Mjollnir, `/oauth2/` → Heimdall. TLS termination.
- **Heimdall**: OAuth2-proxy/Authentik (GitHub OAuth) + **Agent Card signing (JWS)**;
  tenant isolation enforced at the proxy layer.
- **Gjallarhorn**: cloudflared, outbound-only encrypted tunnel.

### 3.9 User Interfaces — Hlidskjalf & Skrymir (the UI/UX differentiator)
- **Hlidskjalf** — **React/Vue** master control dashboard per the **Ymir Rut design
  system** (`docs/ymir-rut.md` Part 3): Cinzel / JetBrains Mono / Inter typography,
  obsidian + cyan + violet palette, Algiz-anvil emblem. Views: fleet graph, A2A task
  stream, memory well (`#/memory`), PR review cards, tenant switcher, Runes stream.
- **Skrymir** — embedded file browser (FileBrowser) scoped per tenant via Bifrost.
- **Telegram / Web chat** — remote command and approve while away.

### 3.10 Automation — Cron, Mjollnir, Valhalla
- **Cron runner**: stateless spawn → inject AGENTS.md + task prompt → execute →
  write realm daily log → exit. Daily briefing 07:00, git backup, social poster.
- **Mjollnir (Issue→PR)**: HMAC-verified webhook → worktree + Utgard sub-agent →
  fix + tests → `gh pr create` → human review in Hlidskjalf. Never force-merges.
- **Valhalla**: PM2/Docker/systemd lifecycle (`process_controller.ts`) + fleet
  registry (`app_registry.json`). Missions, processes, and worker clusters.

### 3.11 Þjazi Backend Integration
- **Þjazi** is an experimental agent-native terminal backend with native per-pane agent state and push events, required when running sub-agents inside terminal panes.
- **Protocol floor**: Þjazi protocol 14 or newer is required; broad backend verification covers versions 0.7.1, 0.7.3, 0.7.4, 0.7.5, and 0.8.0, while protocol-16 features remain gated by availability.
- **Default-on presentation spaces** have a higher floor of Þjazi 0.8.0; homes can opt out by writing `off` into local `config/herdr-presentation-spaces`, and opt in by writing `on`.
- **Endpoint metadata** recorded per task: `backend=herdr`, `window=<session>:<pane-id>`, `herdr_session=<session>`, `herdr_workspace_id=<workspace-id>`, `herdr_tab_id=<tab-id>`, `herdr_pane_id=<pane-id>`.
- **Transport behavior**: Adapter starts and polls a named server before workspace/tab/pane/agent calls. Every Þjazi invocation goes through `fm_backend_herdr_cli`, which sets the environment and passes an explicit trailing `--session <name>`.
- **Push events**: Protocol 16 can subscribe to `pane.agent_status_changed` over a bounded Unix-socket reader. Polling runs every cycle and remains the permanent fallback when protocol 16, the event schema, Python, connection, subscription, or repeated reader execution is unavailable.
- **Away-mode supervisor**: Supports tmux and Þjazi supervisor panes only. Refuses Zellij, Orca, and cmux. For Þjazi, target existence, native state, capture, composer state, and verified submit all route through the shared backend dispatcher and the explicit named-session CLI owner.
- **Destructive lab safety**: `bin/fm-herdr-lab.sh` is the sole supported lifecycle helper for isolated verification. It provisions only non-default names beginning with `fm-lab-`, appends an explicit `--session` to allowed task commands, refuses caller-supplied session flags and server/session lifecycle subcommands, and performs destructive stop/delete only through its guarded lifecycle actions.
- **Active limits**: Þjazi remains experimental; presentation ordering needs protocol 16 and Python and is best-effort only; mutable labels can collide and are never placement or destructive authority; a Brokk outside Þjazi cannot resolve a launcher workspace, so a colliding home label refuses new spawns until the collision is cleared; ghost and placeholder recognition uses ANSI de-emphasis when available.
- **Regression test suite**: 18+ test scripts covering presentation, cleanup, prune safety, focus, respawn, workspace-per-home, launcher workspace, and event wait smoke tests.
- **Sub-agent orchestration**: When Brokk orchestrates sub-agents, Þjazi opens visible terminal panes/windows via `herdr run --pane-name "<role>-<branch>"` pointing to Treehouse worktrees. The user can see the sub-agent typing, executing CLI tools, and running tests live in real time. Þjazi panes are non-blocking—the main agent remains open to answer user inputs or supervise other sub-agents.

### 3.11 Company System — Houses (ENTRY-004)
- The fleet forges for **houses**: Ymir Labs, Brokk Forge, Runestone (Runir),
  Muninn Labs, Dvalin, Utgard Studios, Askr, Mannheim. Each is a real venture with
  a myth that names it (`docs/lore.md` §VI).
- Per-tenant `companies/` entity cards + `projects/` (plan 21).

## 3.12 Agentic Engineering Workflow Integration (Brokk)

### Four-Layer Program Design Framework
Integrated from Dex Horthy's agentic engineering framework (YouTube `xgkjtF89-44`, August 2026). Ymir incorporates the four-layer system alongside its existing seven realms, reinforcing the OSS-first doctrine (ENTRY-008).

**Layer 1 — Product (What & Why)**
- Problem statement, success metrics, announcement post, HTML mockups
- Aligns with Ymir's ticket-creation and PRD workflows
- Measurable goals tied to business outcomes (conversion rates, resource reduction targets)

**Layer 2 — System Architecture (How Services Fit)**
- Service topology, request/response flow, endpoint contracts, query outlines
- Complements Ymir's existing architecture layer in create-plan skill
- Service boundaries and flow diagrams map to Ymir's service orchestration

**Layer 3 — Program Design ⚠️ THE SKIPPED LAYER** (Critical Integration)
- **File locations**: Where each piece lives in the Ymir monorepo
- **Types and method signatures**: Exact interfaces before implementation
- **Call stack visualization**: Execution path when features run
- **Test shapes**: Test signatures only (not implementation)
- **Ymir enforcement**: `validate-plan` skill now mandates Layer 3 capture before spawn
- **Quote**: *"A good plan ends with the tests and the call stack. The point is that these are decisions the agent will otherwise make silently, and that you may not like."* — Dex Horthy

**Layer 4 — Vertical Slices / Tracer Bullets (Execution Order)**
- **Anti-horizontal-building**: Prevents DB→Service→API→FE sequencing that leaves nothing testable
- **Ymir implementation**: `ticket-executor` Phase 0 gate requires vertical slice definition
- **Tracer bullet approach**: Mock API → stub FE → wire together → then add migrations/logic
- **Dex's observation**: *"I have never seen a model do this without a human telling it the order."*

### Context Engineering Principles (from upstream research)
- **"Dumb zone" at ~50% context**: Real for models AND humans — structural decisions early when cheap
- **Right tokens, not more tokens**: One 43k-token planning session > re-steering 3,000-line diff later
- **Victor Tali trick**: *"Which choices are you not confident about?"* — pre-mortem before run, not post-hoc
- **Measurable goals beat instructions**: Agent given a number moves much further than one given description

### Integration with Ymir Systems
- **Mimirsbrunn memory**: Program design decisions observed into the well before agent dispatch
- **Ratatoskr A2A backbone**: Vertical slice tasks dispatched as A2A tasks to specialists
- **Yggdrasil worktrees**: Each slice runs on isolated worktrees with Utgard sandboxing
- **Brokk/Eindri runtime**: Four-layer framework enforced in plan creation and ticket execution
- **Mjollnir issue→PR pipeline**: Incident-to-agent patterns integrated (classifier → brief → PR)
- **Valhalla process supervisor**: Context budget tracking and phase transitions

### Acceptance Criteria (Ymir + Brokk Integration)
- [x] Every ship task has all 4 layers documented before spawn
- [x] Zero horizontal-first builds (Slice 1 e2e testable first)
- [x] 100% of ship tasks have measurable goals
- [ ] Context budget warnings visible in fleet digest
- [x] Pre-mortem confidence check on every program design
- [ ] High-stakes changes go through multi-model review
- [ ] Incident-to-PR pipeline operational

### 3.13 The Meeting Layer — Snotra (the ear) & Þing (the room)

Meetings are a first-class Ymir capability: heard, transcribed, and kept in the
hoard where the fleet's agents can read them.

**The role split is by seat, and it is honest about physics:**

```
THE EAR (capture)         the seat in the meeting — PipeWire mic + system monitor.
                          A headless server cannot hear a call on the operator's laptop.
THE BRAIN (transcribe)    the seat with the GPU — whisper.cpp (CUDA). CPU fallback
                          when the resident rail model starves VRAM.
THE RECORD (store/serve)  the heart — minutes in the vault, synced by the home's git
                          road, the read-only MCP face served there.
```

- **Snotra** — the meeting ear (plan 52). `bin/snotra-capture.sh` records mic +
  system audio via PipeWire (no virtual loopback device); `bin/snotra-transcribe.sh`
  discovers the seat's whisper engine (env → PATH → build trees → `voxtype`),
  normalises to 16 kHz mono, and writes Markdown minutes under
  `$YMIR_HOME/hodd/workspaces/meetings/` with a Rune per meeting. Minutes are
  summarised by the **local rail** (`llama-swap`, no cloud key).
- **The MCP face** (`tools/snotra/server.mjs`, streamable HTTP `:8321`, read-only)
  lets any seat's agent ask *"what did we decide about X?"* — `snotra_list`,
  `snotra_read`, `snotra_search`, `snotra_summary`.
- **Þing** — the assembly hall (plan 53): Ymir's own meeting room, a MiroTalk P2P
  (AGPLv3) fork on whynot (`:3000`, public door `ping.zerwiz.org`). The ear
  complements the room: Snotra records meetings held in other halls; Þing is a
  hall of our own, so the ear can know the room, the participants, and the moment
  it began.
- **The engine is per-seat** (open-source-first, no duplicate vendored): heimdall
  and whynot carry CUDA whisper.cpp builds; omarchy's `voxtype` already bundles
  whisper (models + a full `meeting` mode) and gained `extra/whisper-cpp` only for
  a uniform CLI. `bin/snotra-ensure.sh` reports and installs per-OS; the
  `snotra` step of `bin/ymir-install.sh` and the `snotra` surface of
  `bin/eir-doctor.sh` keep a fresh seat whole.
- **First Law:** audio and transcripts are private data — the hoard, never the
  repo. The repo carries the wiring, never a recording, a name, or a minute.

## 4. Execution Chain Examples

### 4.1 Inbound GitHub Bug Report
```
Webhook → Gjallarhorn → Bifrost → issue_listener.ts (HMAC verify)
→ Mjollnir routes to realm → commit from Mimirsbrunn (recall project memory)
→ treehouse worktree (fix-issue-N) → Eindri inside Utgard diagnoses + patches + tests
→ push branch → gh pr create (Fixes #N)
→ notify (Telegram + Hlidskjalf) → human reviews → merge
→ outcome observed into the well + Runes logs everything
```

### 4.2 Background Daily Briefing
```
Cron 07:00 → daily_brief.ts → loads AGENTS.md + realm context
→ RECALL Mimirsbrunn for active dev/marketing context
→ assemble prompt (untrusted_context contained)
→ spawn headless agent → write svartalfaheim/<realm>/workspace/memory/daily/YYYY-MM-DD.md
→ auto-commit sync (git_backup.ts) → exit
```

### 4.3 A2A Delegation (Kaia → specialist)
```
Kaia recalls the well (what worked here before)
→ discovers specialist via realm registry (Agent Card) → creates A2A task (SubmitTask)
→ specialist streams progress over SSE (Working → updates)
→ specialist finishes (Completed, artifacts) → tools via MCP internally
→ Kaia observes the outcome into Mimirsbrunn → logs to Runes → Hlidskjalf renders state
```

### 4.4 Parallel Feature Work (two agents, one shared repo)
```
Agent A: yggdrasil create → .yggdrasil/agent-a/ (branch agent/a/auth)
Agent B: yggdrasil create → .yggdrasil/agent-b/ (branch agent/b/logging)
Both run tests inside their own Utgard container (mount own worktree only)
On success: cleanup(merge=true) → merged to main, worktree removed
```

## 5. Data Flow & Security Boundaries

| Boundary | Enforced by |
|----------|-------------|
| Tenant independence | Svartalfaheim realm namespace + vault keys; proxy-level path scoping; per-realm `.env.realm`; realm-scoped A2A registry |
| Agent identity | **JWS-signed Agent Cards** (Heimdall); rejected tampered cards |
| Untrusted code | Utgard: network-none containers, resource caps, cgroups, no root, ephemeral destroy |
| Secrets | Only `.env.local` / `.env.realm`; never in markdown or git |
| Prompt injection | `<untrusted_context>` containment + immutable system prompt layer |
| Git safety | Yggdrasil worktrees; Mjollnir never force-merges |
| Deploy safety | Zero-trust `gh secret set` + human-approved PRs |
| Traceability | every significant action carved into Runes; target traceability index 0.984 (Rut) |

## 6. Tech Stack Reference (current = TS/Python/React/Vue; target = Ymir Rut v2.6)

### Current stack (build today)

| Layer | Choice | Norse shell |
|-------|--------|-------------|
| Control plane daemons | **TypeScript** (Node 22) | Bifrost, Svartalfaheim, Yggdrasil, Ratatoskr, Mjollnir, Valhalla |
| Agent orchestration | **Python 3.12+** + TS | Brokk / Kaia / Eindri (mirrors smidja harness) |
| UI / UX | **React + Vue** | Hlidskjalf portal, Skrymir |
| Inter-agent | **A2A 1.0** (JSON-RPC 2.0/SSE) + **Redis** | Ratatoskr |
| Memory | **engram/engdbram** bridge `:4602` | Mimirsbrunn |
| Sandbox | Docker (rootless, network-none) + Python | Utgard |
| Gateway | Traefik/Caddy | Bifrost |
| Auth | OAuth2-proxy/Authentik + JWS cards | Heimdall |
| Tunnel | cloudflared | Gjallarhorn |
| Files | FileBrowser / MinIO | Skrymir |
| Persistence | Postgres 16 (self-hosted) + engram/SQLite | Runes/Mimirsbrunn |
| Process mgmt | PM2 / Docker | Valhalla |
| CI/CD | GitHub Actions + gh CLI | Mjollnir / deploy |
| Meeting capture | **PipeWire** (mic + system monitor) + ffmpeg | Snotra (the ear) |
| Meeting transcription | **whisper.cpp** (CUDA; `voxtype` on omarchy) | Snotra (the brain) |
| Meeting room | **MiroTalk P2P** (AGPLv3 fork) | Þing (the assembly hall) |
| Reused systems | `smidja`, the upstream `firstmate` distro, `.compliance`, smidja visualizer | — |

### Target stack (Ymir Rut v2.6 — port AFTER end-to-end, ENTRY-009)

| Layer | Rut choice | Crate/module |
|-------|-----------|--------------|
| Control plane | **Rust (Edition 2024) + Tokio** | crates/{bifrost,hlidskjalf,svartalfaheim,ratatoskr,yggdrasil} |
| Broker | **NATS JetStream** | `bus::nats`, `dispatch::router` |
| IPC | **gRPC/Protobuf v3** + JSON-RPC/Unix sockets | `proto/v2/` |
| Worktrees | **libgit2** `.treehouses` | `worktree::libgit2`, `snapshot::diff` |
| Sandbox | rootless Docker + **cgroups v2** + seccomp | `runtime/utgard/` |
| Agent harness | Python 3.12+ / Node 22 (unchanged) | `runtime/brokk/` |
| Persistence | PostgreSQL 16 + MinIO/S3 | storage tier |
| Deploy | Helm charts + compose | `configs/` |

## 7. Build Order (Updated)

| Phase | Scope | Depends on |
|-------|-------|-----------|
| P0 | Monorepo skeleton, AGENTS.md, realm routing, docs (lore, Rut, architecture) | — |
| P1 | Yggdrasil worktrees + Utgard sandbox | P0 |
| P2 | Memory — engram bridge (Mimirsbrunn) + Runes audit | P0 |
| P3 | Skills engine (Gungnir) + validation loop | P1 |
| P4 | **Ratatoskr A2A 1.0 backbone** (cards, registry, Redis) | P0 |
| P5 | Cron automation | P2, P3 |
| P6 | Realm multi-tenancy + tenant context loader + companies/houses | P0 |
| P7 | Hlidskjalf portal (React/Vue, Rut design system) + Skrymir | P4 |
| P8 | Bifrost + Heimdall (OAuth + card signing) + Gjallarhorn | P6, P7 |
| P9 | Mjollnir issue→PR pipeline | P1, P4 |
| P10 | Toolchain & deploy engine (Valhalla, GitHub CI/CD) | P1 |
| P11 | **Ymir Rut port** (Rust/NATS/gRPC re-floor) — only after P0–P10 work end-to-end | P0–P10 |
| P12 | **Meeting layer** — Snotra (the ear: PipeWire capture, whisper.cpp, minutes in the hoard, the read-only MCP face) + Þing (the assembly hall) | P2, P4 |

Detailed per-feature plans: `docs/plans/`. Full v2.6 target spec: `docs/ymir-rut.md`.
Mythos & houses: `docs/lore.md`. Decision history: `docs/append-only-log.md`.