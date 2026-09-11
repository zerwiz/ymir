# PLAN 26 — Hlidskjalf Rise: Frontend & Backend Build

> **Status:** DRAFT (proposed) · **Owner:** Brokk · **Stamp:** `traceability_target: 0.984`
> Everything left to do in the frontend and backend build, in one plan:
> GitHub login → workspace provisioning → per-user **Hermes** workers running behind
> them → the system booting its **primary agents as PI**, exactly the way firstmate
> does at `/home/zerwiz/firstmate`.
> Sources: reference UI `assets/reference/index.html`, `docs/design.md`,
> `midgard/design-system/tokens.css`, `docs/masterplan.md` (orders W0001–W0025),
> `~/firstmate` (PI boot path), and the stack ruling ENTRY-009/010
> (TypeScript + Python + React + Vue).

---

## 0. The Reference

`assets/reference/index.html` is the **visual contract**. It is the design
document plus the seed stylesheet for the Hlidskjalf shell:

- **Tokens** — the CSS block carries a directive: *"extract verbatim to
  `midgard/design-system/tokens.css`"* → already done, tokens match (verified).
- **Realm tints** — `.shell[data-realm="way-of"]` cyan `#38bdf8`, `zerwiz`
  violet `#8b5cf6`, `craig` amber `#f59e0b`. Tints are structural.
- **Shell grid** — `.shell` = `236px rail | 1fr` columns; rows `56px topbar ·
  stage · 192px stream`.
- **Rail furniture** — `.rail`, `.brand`, `.emblem` (Algiz+anvil, chisel bevel),
  `.wordmark`, `.nav`, `.gate` (per-realm navigation gates).

Rules: port the reference CSS **as-is** into the app (it is the design system,
not a screenshot to redraw); never re-invent tokens; `data-realm` drives the
tenant colouring.

---

## 1. Target Architecture

```
Hlidskjalf (FE) — React 19 + Vite SPA (+ Vue sub-app for Skrymir)
        │  HTTPS / SSE / WS
        ▼
ymir-gate (BE) — Fastify (TS): /auth · /api/* · /api/stream · /api/ws
   │            │              │
   ▼            ▼              ▼
heimdall    workspace-      hermes-runtime
(GitHub     provisioner     (per-user Hermes workers
 OAuth +    svartalfaheim   in Utgard, A2A + Redis)
 JWT +      <login>/)
 JWS agent                   │
 cards                       ▼
                         mimirsbrunn · runes · ratatoskr
                         (engram :4602) (jsonl) (A2A 1.0)
   ▲
   └──── pi-primary boot ─── firstmate (fm-harness/fm-spawn/backend, pi primary)
```

Backend services run under **Valhalla** (PM2). Memory = engram bridge
(`127.0.0.1:4602`, W0004). Ledger = Runes (W0005). Backbone = Ratatoskr A2A
(W0008–W0010). Workspaces are **filesystem-first** repos on disk
(`svartalfaheim/<login>/`); a SQLite registry (`better-sqlite3`) indexes
workspaces/tasks/sessions.

---

## 2. Boot Sequence (what the whole system does)

1. **Valhalla** raises the gates: `ymir-gate`, `heimdall`, `workspace-provisioner`,
   hermes-runtime controller, memory bridge, runes.
2. **System primary boots as PI** — the operator's own crew runs the firstmate
   distro (Phase C): `fm-harness` resolves `pi` (default), `fm-spawn` launches
   crewmates into the runtime backend (tmux/herdr), the Pi supervision branch
   drains routine wakes without interrupting the captain.
3. **First GitHub login** → workspace auto-provisioned under
   `svartalfaheim/<login>/`.
4. The user's requests spawn **Hermes workers** — isolated Eindri smiths,
   `docker_ephemeral`, configured to the Hermes model profile (LM Studio by
   default), each with a clean worktree and a published A2A Agent Card.
5. Every state hop is carved into Runes and observed into the well; the same
   stream feeds Hlidskjalf live.

---

## 3. Frontend build order — Hlidskjalf (React SPA)

| # | Task | Delivers |
|---|---|---|
| FE-0 | Vite + React 19 + TS scaffold; import `tokens.css`; fonts (Cinzel, JetBrains Mono, Inter); `data-realm` runtime binding | the forge chamber renders |
| FE-1 | Auth + first-run: `/login` → GitHub; JWT session; workspace bootstrap wizard (house choice, repo clone option) | a user's gate opens |
| FE-2 | **Port the reference shell** verbatim: `.shell/.rail/.brand/.emblem/.wordmark/.nav/.gate`, 56px topbar (realm chip, traceability index, user), stage router, 192px bottom stream (Ratatoskr + Runes, pausable) | the sovereign's seat |
| FE-3 | Gates (views): **Fleet** · **Tasks** · **Well** · **Runes** · **Reviews** · **Processes** · **Files** · **OmniChat** — components per design.md §5.2 | eight realms visible |
| FE-4 | Live wiring: SSE/WS → Zustand stores → AgentCards, TaskChips, TraceRows, RecallPanel, metric tiles | the forge stays hot |
| FE-5 | **Skrymir** file browser as a Vue sub-app mounted in the Files gate | the giant hand |
| FE-6 | Chart kit, fleet graph edges, Glitnir PR cards, compact-density toggle | truth over ornament |
| FE-7 | Accessibility pass: AA contrast, `prefers-reduced-motion`, keyboard-first, focus chisel ring | everyone may enter |

## 4. Backend build order — the gates

| # | Task | Delivers |
|---|---|---|
| BE-0 | Monorepo (`apps/web`, `apps/api`, `services/*`); Fastify + zod + pino; `.env.local` secrets only | foundation |
| BE-1 | **Heimdall**: GitHub App OAuth (client id/secret in env) → code → token → `/user`; httpOnly JWT session; tenant scoping | login + signing |
| BE-2 | **Workspace provisioner**: idempotent bootstrap of `svartalfaheim/<login>/` — `companies/`, `projects/`, `workspace/{company,marketing,development,life,memory/daily}`, `.env.realm`, `Brokk.md`, Agent Card; one DB row per workspace | workspaces appear |
| BE-3 | **Gate API**: `/api/me · /api/workspace · /api/agents · /api/tasks · /api/well · /api/runes · /api/processes · /api/reviews`; `GET /api/stream` (SSE); `WS /api/tasks/:id` | all surfaces fed |
| BE-4 | **Hermes runtime controller**: spawn per-user workers (`docker_ephemeral`, Hermes model profile, clean worktree, network-none default); A2A lifecycle SUBMITTED→WORKING→TERMINAL; carve Runes; observe well | agents run behind |
| BE-5 | **Ratatoskr wiring**: every worker publishes `/.well-known/agent-card.json`; Redis pub/sub under the A2A task model; inbox poll loop; cards JWS-signed by Heimdall | the squirrel runs |
| BE-6 | **Mimirsbrunn + Runes** surface the well (recall/timeline) and ledger in the API | drink before you act |
| BE-7 | **Mjollnir** pipeline exposed (W0018): webhook listener → worktree + Utgard fix → tests → PR → Glitnir human approval | the hammer returns |
| BE-8 | **PI primary boot** — adopt `firstmate` as the operator's crew runtime: `fm-harness` resolution (`pi` default), `fm-spawn` dispatch profiles, runtime backend (herdr/tmux), Pi supervision branch, treehouse worktrees; Ymir supervises via Valhalla; read-only command observer (W0012) until Ratatoskr carries two-way | the system wakes as PI |

---

## 5. Sequencing → masterplan

| Phase | Contents | Opens orders |
|---|---|---|
| **A · Auth + Provision** | BE-1, BE-2, FE-1 | W0028, W0029, parts of W0027 |
| **B · Workers** | BE-3 (agents/tasks), BE-4, FE-3 (Fleet/Tasks) | W0030 |
| **C · PI primary** | BE-8 | W0031 |
| **D · SPA shell** | FE-0, FE-2, FE-3, FE-6 | W0026 |
| **E · Live + Skrymir** | FE-4, FE-5, FE-7 | W0032 |
| **F · Pipeline/Ops** | BE-7 + W0018/W0019 (from masterplan) | — |

Hard dependency chain: **A → B → C** (a user can start using their workspace
before either the SPA or PI boot lands); **D and E** invert freely.

---

## 6. New forge orders (append to masterplan §3)

- **W0026** — Frontend SPA, React+Vite Hlidskjalf: reference-shell port, gates, live stream (Phase D)
- **W0027** — Backend gate API, Fastify: endpoints + SSE/WS + zod schemas (Phase A/D)
- **W0028** — Heimdall GitHub OAuth: code flow, JWT session, tenant mapping (Phase A)
- **W0029** — Workspace auto-provisioner: first-login bootstrap, idempotent, SQLite registry (Phase A)
- **W0030** — Hermes worker runtime: per-user isolated workers, A2A + Redis, Hermes model profile (Phase B)
- **W0031** — PI primary boot: firstmate adoption for the system primary, Pi supervision branch (Phase C)
- **W0032** — Skrymir Vue sub-app + live-stream polish (Phase E)

---

## 7. Open questions (for the captain)

1. **Hermes** — interpreted as the *worker agent profile* for end-user fleets
   (model served via LM Studio, default `hermes`). Confirm the model id/endpoint.
2. **PI primary** — reuse the firstmate distro as-is (recommended, OSS-first)
   and let Ymir supervise it, or re-implement the harness resolution pattern?
3. **GitHub App** — need a GitHub **App** (not OAuth app) for the repo-provisioning
   scope (contents, metadata, PRs) so the bootstrap wizard can clone/mirror the
   user's repos into their workspace.
4. The reference `index.html` CSS cuts off inside `.gate` — the rail continues
   from the design doc; the plan ports the reference and completes the gates per
   design.md §5.
---

## 8. Gap audit vs `assets/Ymir.md` (append-only, 2026-09-11)

Compared against the full blueprint in `assets/Ymir.md` (Commando Central /
agent-hq), plan 28 + masterplan already cover: shell/auth/provisioning (W0026–W0029),
Hermes worker runtime (W0030), PI primary boot (W0031), Skrymir (W0032), memory/ledger/
A2A (W0004–W0010), isolation (W0001–W0003), pipeline (W0018), ops (W0019).

**Gaps found — masterplan orders W0033–W0038 appended:**

| Blueprint section (assets/Ymir.md) | Gap | Order |
|---|---|---|
| `workspace/config/toolchain.md` + `.agents/tools/*` provider wrappers (Supabase/Firebase/PocketBase/Vercel/Netlify/Expo/Stripe) + provision flow | Toolchain registry — manifests + auth-status manifest + provision/verify skills | **W0033** |
| `workspace/config/portfolio.md` + `register_foreign_app.ts` + `process_controller.ts` (PM2/Docker/systemd/npm) | App-fleet registry + deterministic process control + `register_foreign_app` skill | **W0034** |
| `.agents/skills/github_deploy.ts` (gh secret sync, `deploy-{staging,production}.yml` workflow dispatch) | Zero-trust GitHub deployments — secrets never in commits | **W0035** |
| `.agents/gateways/telegram_bot.ts` + `notify_user.ts` | Omnichannel gateway (Telegram remote command/status + notification push + web drawer) | **W0036** |
| `apps/portal` as Expo React Native (mobile web+app, tenant switcher, fleet, memory explorer, OmniChat) | Hlidskjalf Mobile (React Native/Expo) | **W0037** |
| `memory/entity_graph/` + `workspace_rag.ts` (hybrid Markdown + vector) | Workspace RAG + entity-graph facade over the engram engine | **W0038** |
| `tenants/<id>/Hermes.md` + `hermes.config.json` + `tenant_context_loader` + `hermes_runner.ts` | Strengthens W0030 scope (persona/config/loader per tenant) — append-only note added | W0030 |
| `.agents/bus/agent_bus.ts` + `inter_agent_audit.md` (featured `InterAgentMessage` in `~/.agents/bus/protocol.ts`) | Cross-tenant/personal→HQ inter-agent comms are Ratatoskr's job; `inter_agent_audit` = Runes — note added | W0008 |
| `.agents/assets` templates (PRD, ENV, system prompts) + hardened container Dockerfile | Fold into W0022 (templates) and W0002/Utgard (container) | W0022, W0002 |

**Conclusion:** after W0033–W0038, `assets/Ymir.md` has no uncaptured subsystem. The
user-facing portals now cover web (Hlidskjalf) + mobile (Expo) + Telegram (Omnichannel).

---

## 9. Gap audit — Smíðja `apps/visualizer` (append-only, 2026-09-11)

Compared `apps/hlidskjalf` against the reference implementation shipped inside the
Smíðja skill — formerly **command-factory** (`.agents/skills/smidja/apps/visualizer` —
Vue 3 + Bun + SQLite). Hlidskjalf today is a **read-only, mock-seeded Ymir ops
dashboard**; the visualizer is a **live, SQLite-backed factory control plane**.

**Verdict:** the eight Ymir gates (Fleet/Tasks/Well/Runes/Reviews/Processes/Files/
OmniChat) are present, but the entire factory observability and run-control surface
is missing. `src/services/stream.ts` still ships `MOCK = true`; `src/services/api.ts`
is defined but has **no call sites**; state is reseeded by `hydrate()` on every realm
switch (`src/state/store.ts:137`).

### 9.1 Architecture gap (root cause)

| Layer | command-factory visualizer | Hlidskjalf |
|---|---|---|
| Data | Reads real `factory/factory_data/factory.db` (WAL) via Bun API (`server/db.ts`) | 100% seeded mocks — `hydrate()` reseeds on every realm switch |
| Transport | 500ms rowid-cursor polling (`/api/sessions/:id/events?after=`) | Synthetic `setInterval` fake stream; `MOCK = true` |
| API | Full REST server (`server/index.ts`, 589 lines) | `src/services/api.ts` defined but **never called** |
| Persistence | 7 tables: sessions, phases, events, envelopes, gate_results, processes, agent_sessions | None |
| Build | Vue 3 + Bun + SQLite | React 19 + Vite, no server |

### 9.2 Missing views (whole features)

| visualizer view | Purpose | Hlidskjalf |
|---|---|---|
| **Sessions list** | all factory runs, phase-dot progress, archive/review flags | absent |
| **Session Trace** | lane waterfall, span nesting, live poll | absent |
| **Phase Detail** | envelopes, gates+evidence, tool calls, thinking, prompts, context bars, cost table | absent (gates are cosmetic only) |
| **Decisions** | failures grouped by diagnosis+model + recommended fix | absent |
| **Stats** | tokens/cost, cache-hit ratio, vendor savings, local-vs-cloud, by-chain/by-model | absent |
| **Settings** | MCP keys masked, save to `.env` | absent |
| **Memory** | live engram: inspect/recall/timeline/observe, entity graph | `Well.tsx` is static hardcoded text |
| **Chat** | real Kaia thread: history, multi-session, model picker, tool cards | `OmniChat.tsx` is a 700ms fake echo (`:23-31`) |

### 9.3 Missing control actions (writes)

Visualizer is a control plane; Hlidskjalf's buttons have no handlers
(`Processes.tsx:79-84`, `Tasks.tsx:122`, `Runes.tsx:38`).

- **Stop / Pause / Resume** — SIGTERM / SIGSTOP / SIGCONT on live agent PIDs
- **Steer** — inject guidance into a running run (`steer.md`)
- **Archive** — review triage flag
- **Launch session** — roster + orchestrator model + task
- **Recall / Observe / Timeline** — memory writes
- **Roster/model management** — `/api/rosters`, `/api/models`, weak-orchestrator guard

### 9.4 Missing data model & API

- **Types** (`shared/types.ts`, 630 lines): `Session`, `Phase`, 12 `EventType`s,
  `Envelope`, `GateResult`/`GateCheck`, `AgentSession`, `UsageBreakdown`,
  `ToolCallPayload`, `DecisionsResponse`, `StatsResponse`, `RosterInfo`, `ModelInfo`,
  `MemoryEpisode/Fact/Inspect/Recall/Timeline`. Hlidskjalf's `src/types.ts` has none.
- **Endpoints absent**: `/api/sessions` (+ detail/events/agents/gates/envelopes/
  thinking/prompts), `/api/decisions`, `/api/stats`, `/api/memory/*` (bridge proxy to
  `:4602`), `/api/rosters`, `/api/models`, `/api/chat/*`, `/api/settings`.
- **Trace semantics** from `references/observability.md`: phase-status invariants
  (`success` must be earned), gate evidence (`checks_json`), context-window occupancy
  vs. spend, per-phase cost reconciliation, subagent lane materialization — all
  unrepresented.

### 9.5 Gaps → orders (appended to masterplan §3)

| Gap | Order |
|---|---|
| Factory run-store & trace ingest (sessions/phases/events/envelopes/gates/agent_sessions) | **W0075** |
| Run control API (stop · pause · resume · steer · archive) | **W0076** |
| Roster & model catalog + session launch | **W0077** |
| Decisions (failure clustering) & Stats APIs | **W0078** |
| Local settings store (MCP keys, masked) | **W0079** |
| Sessions list (factory runs) | **W0080** |
| Session Trace (lane waterfall + live poll) | **W0081** |
| Phase Detail (envelopes · gates · thinking · prompts · tool calls · context/cost) | **W0082** |
| Decisions view | **W0083** |
| Stats view (tokens · cost · cache · savings · providers) | **W0084** |
| Settings view + OmniChat factory upgrade | **W0085** |

### 9.6 Scope notes

The visualizer's Norse mapping is clean: Sessions → **Mjollnir** runs; Trace lanes →
**Valhalla** supervision; Memory → **Mimirsbrunn**; Decisions → **Rungnir**; Chat →
**Kaia**. The `Processes` and `Reviews` gates stay Ymir-native (no factory equivalent).
**Out of scope:** the Electron desktop shell (`desktop/main.js`) and the future items
in the factory `docs/enhancement-plan.md` (WebSocket/GraphQL, presence, comparative
trace diff, token-flow Sankey, roster chain builder).
