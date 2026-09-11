# YMIR — MASTERPLAN
> The living plan of everything left to be wrought. Every item is a forge-order;
> every order is carved once and closed with an appended note — never edited.

**Owned by:** Brokk (docs), ratified against `docs/append-only-log.md`, `docs/Architecture.md`, `docs/ymir-rut.md`, and `docs/plans/`.
**Stamp:** `system_identifier: ymir_rut_core · operational_status: NOMINAL · traceability_index: 0.984`

---

## 0. The Append-Only Contract

This file is **append-only**, like Runes. Violating it is worse than failing the work:

1. **Never edit an existing order.** An order is carved once. If it must change, append a `+ note:` under it recording the change; if the change is fundamental, file a **new order** that supersedes it (and reference the old id).
2. **Never rewrite a status in place.** Close work by appending the line `+ <YYYY-MM-DD> COMPLETED — <what shipped>` beneath the order. The old text stays as history.
3. **New work is appended** at the end of the Backlog section with the next id (`W0026`, `W0027`, …). Never insert mid-list.
4. **Every rollout of this plan is logged** as a dated line in §5 (the Log). The Log records: what changed, which order acted, and the ENTRY/plan reference.
5. **Status vocabulary** (used in `+ notes` only):
   - `ADDED` — filed, not started
   - `WORKING` — underway
   - `BLOCKED` — waiting on something, note states what
   - `COMPLETED` — Done
   - `CLOSED/CANCELLED` — will not be done, note why

The **Active Queue** (§2) is the one legitimate "rewrite": it is a *published view*,
not an order. When the queue changes, append a `+ <date> Queue moved to: …` line
and re-publish the new list beneath it — the old list stays.

---

## 1. Campaigns (the phases that contain the orders)

| Phase | Name | Gates it raises | State |
|---|---|---|---|
| P0 | Scaffold & doctrine | docs, lore, design, plans | DONE |
| P1 | Isolation — Yggdrasil + Utgard | W0001 W0002 W0003 | TODO |
| P2 | Memory — Mimirsbrunn + Runes | W0004 W0005 W0006 | TODO |
| P3 | Skills — Gungnir | W0007 | TODO |
| P4 | Collaboration — Ratatoskr/A2A | W0008 W0009 W0010 | TODO |
| P5 | Scheduling — cron | W0011 | TODO |
| P6 | Business — company model + observer | W0012 W0013 W0022 | TODO |
| P7 | Portal — Hlidskjalf UI | W0014 W0015 W0016 W0018* | TODO |
| P8 | Gateway — Bifrost/Heimdall/Gjallarhorn | W0017 | TODO |
| P9 | Pipeline — Mjollnir | W0018 | TODO |
| P10 | Ops — Valhalla + toolchain | W0019 W0020 | TODO |
| P11 | Reforging — Ymir Rut (Rust) port | W0024 | BLOCKED BY DESIGN |

*(*W0018 is raised in P7 for its review UI and P9 for the automation; it is one order.)*

---

## 2. Active Queue (the immediate next)

+ 2026-09-11 Queue moved to: W0026 → W0028 → W0027 ahead of W0022-first ordering; CI spine + naming law gate the remaining forge.

1. **W0026** — AXI CI/CD workflow port (ymir-sdk-ci, ymir-release-please, ymir-docs-check, ymir-guard-generated-files)
2. **W0028** — Eindri spawn/monitor/merge CI (Yggdrasil + Valhalla + Glitnir)
3. **W0027** — Norse-named skill family (tyr-check, brokk-craft)
4. **W0022** — Plan 21 execution: per-tenant `companies/` + `projects/` + `company_entity.template.md` *(approved; awaiting human "go")*
5. **W0001** — Yggdrasil worktree manager daemon (TS)
6. **W0002** — Utgard rootless sandbox recipes + enforcement
7. **W0004** — Mimirsbrunn: adopt Kaia's engram bridge (`:4602`) for recall/observe
8. **W0015** — `midgard/design-system/icons.md` rune-glyph map
9. **W0021** — write individual plan docs 01–20 (currently index rows only)

---

## 3. Backlog — Forge Orders

**W0001 — Yggdrasil worktree manager daemon**
- Phase: P1 · Depends: none · Source: ENTRY-003, Structure.md
- Scope: `.yggdrasil/<agent-id>/` isolation, spawn/merge/cleanup, zero-collision.
- Done when: `brokk agent spawn` creates an isolated worktree; merge is explicit; cleanup is automated.
- Status: WORKING. + notes:
  - 2026-09-11 — `bin/yggdrasil.sh` built (Galdr-style TOON): `create` (zero-collision, refuses dup ids), `list`, `status`, `merge` (refuses unlanded work; ff-only then no-ff), `cleanup` (refuses unlanded unless `--force`), `--version`. Verified end-to-end against a scratch repo: create → list → status → commit → merge (file landed) → cleanup → empty. einherjar-spawn already uses `.yggdrasil/<id>/`.

**W0002 — Utgard rootless sandbox (execution barrier)**
- Phase: P1 · Depends: none · Source: Structure.md, AGENTS.md laws 2/3/6
- Scope: Docker/respawn with no host root, no network by default, CPU/RAM/timeout caps; a failed run never touches main branch.
- Done when: an untrusted task runs sealed and leaves no trace on fail.
- Status: WORKING. + notes:
  - 2026-09-11 — `bin/utgard.sh` built (build/status/run; Galdr-style TOON). Run wraps `docker run --rm --network none --cpus 1.0 -m 512m --security-opt no-new-privileges --read-only --tmpfs /tmp --user <host-uid> -v <worktree>:/sandbox/workspace`, bounded by `timeout`. Verified: sealed run (uid 1000, writes only the mounted worktree), network blocked, no host root, read-only rootfs, and `--timeout` kills with exit 124. Image `utgard-runner:latest` ready.

**W0003 — Brokk spawn CLI + worktree lifecycle DX**
- Phase: P1 · Depends: W0001 · Source: Rut CLI (`ymir status`, `brokk agent spawn`, `ymir init`)
- Done when: the three canonical CLI verbs exist and behave.
- Status: WORKING. + notes:
  - 2026-09-11 — `bin/brokk` built: `status` (lock/seat/cron/bridge/well), `agent spawn|list|status|merge|cleanup` (delegating to `einherjar-spawn.sh` + `yggdrasil.sh`), `recall|observe|timeline` (delegating to `mimir.sh`), `runes`. Verified: status, list, runes.

**W0004 — Mimirsbrunn: engram bridge adoption (memory)**
- Phase: P2 · Depends: none · Source: ENTRY-007, command MEMORY.md
- Scope: recall (`GET /recall`) + observe (`POST /observe`) loops over the Kaia bridge `127.0.0.1:4602`; agent-scoped keys `agent://<realm>/<agent>`; recall modes hybrid/cosine.
- Done when: Brokk drinks before dispatch and waters after; dry well never blocks.
- Status: WORKING. + notes:
  - 2026-09-11 — `bin/mimir.sh` built: `health`, `recall <q>` (bridge `/recall`, local well fallback), `observe <text>` (bridge `/observe`, local append), `timeline`. Reads `MIMIRSBRUNN_URL` (default `:4602`), falls back to `.agents/memory/well/episodes.jsonl` (367 entries). Verified health/recall/observe/timeline.

**W0005 — Runes: append-only audit ledger**
- Phase: P2 · Depends: none · Source: ENTRY-001/003, plan docs
- Scope: JSONL ledger; every significant action carved with timestamp, agent, order id, checksum; a rune stays.
- Done when: Hlidskjalf and CLI can read Runes; writes are append-strict.
- Status: ADDED. + notes:

**W0006 — Pre-dispatch context injection (drink before act)**
- Phase: P2 · Depends: W0004 · Source: plan 23/25, ANTI-hallucination gate
- Scope: Kaia reads the well and passes grounded context + the veil verdict into each Eindri dispatch.
- Done when: no dispatch starts silent.
- Status: WORKING. + notes:
  - 2026-09-11 — `bin/einherjar-spawn.sh` now recalls from the well before dispatch: writes `data/<id>/context.md` (`bin/mimir.sh recall`) and composes `data/<id>/prompt.md` (brief + recalled context) as the worker prompt. A dry well never blocks.

**W0007 — Gungnir skill synthesis + validation**
- Phase: P3 · Depends: W0002 · Source: AGENTS.md Skill Synthesis
- Scope: `.agents/skills/` authoring, Utgard validation before production, skill index registration.
- Status: ADDED. + notes:

**W0008 — Ratatoskr: A2A 1.0 backbone**
- Phase: P4 · Depends: W0004 W0005 · Source: ENTRY-008, plan 25 (approved)
- Scope: `a2a-bridge` skill adoption, `/.well-known/agent-card.json` endpoints, JWS signing via Heimdall, task lifecycle SUBMITTED→WORKING→TERMINAL.
- Status: ADDED. + notes:
  - 2026-09-11 — scope bound: cross-tenant and personal→HQ inter-agent comms (Hermes↔Hermes, Hermes↔Captain) ride this bus; the blueprint's `.agents/bus/agent_bus.ts` + `inter_agent_audit.md` are the reference; audit = Runes (W0005). [assets/Yimir.md, plan 28 §8]

**W0009 — Redis task queue under the A2A model**
- Phase: P4 · Depends: W0008 · Source: ENTRY-008
- Scope: Redis pub/sub carries throughput; A2A carries semantics; inbox poll loop per agent.
- Status: ADDED. + notes:

**W0010 — Inter-agent message schema + lifecycle machine**
- Phase: P4 · Depends: W0008 · Source: `.agents/bus/protocol.ts`
- Scope: `InterAgentMessage`; state machine; every message observed+carved.
- Status: ADDED. + notes:

**W0011 — Cron schedule spine**
- Phase: P5 · Depends: none · Source: plan 24 (proposed), Rut automation
- Scope: stateless spawn pattern (fresh process → inject → execute → write → exit), daily briefings, background git sync, canary cron example.
- Status: ADDED. + notes:

**W0012 — Ymir ↔ Command observer spine**
- Phase: P6 · Depends: none · Source: plan 23 (proposed)
- Scope: read-only transaction observer (helper) first; port to A2A after Ratatoskr rises; **never** write into `~/Ymir` from Ymir.
- Status: ADDED. + notes:
  - 2026-09-11 — scope extended (plan 23): observe BOTH `command` (FEATURES.md registry, `.compliance/` gates, tenants, `smidja.db`, `kaia.engram`) and `firstmate` (captain/crew sessions, worktree state, supervision handoffs), on schedule + webhook/file-change; each observation → Mimirsbrunn episode (`source:command|firstmate`) + filtered Runes line. Full service = W0086. [plan 23]
  - 2026-09-11 — `RETIRED` the `command` connection: the observer is now self-contained. It reads only Ymir's own tree (`docs/masterplan.md`, `.agents/agents`, `.agents/memory/well`, `workspace/memory/runes_audit.md`, `smidja/smidja_data/smidja.db`) plus the read-only external worktree root. No path under `~/command` is referenced; the smidja DB is pointed at Ymir's own install. Plan 23 rewritten as **Ymir Runtime Observer (self-observation)** (`docs/plans/23-ymir-observer.md`). [plan 23]

**W0013 — Realms & house activation**
- Phase: P6 · Depends: W0022 · Source: ENTRY-002/004/006, plan 21
- Scope: per-realm `.env.realm` handling, tenant provisioning docs, house seal wiring into UI.
- Status: ADDED. + notes:

**W0014 — Hlidskjalf portal (React/Vue, token-driven)**
- Phase: P7 · Depends: W0008 W0005 W0004, design.md · Source: ENTRY-008, plan 22 (proposed)
- Scope: fleet graph, task stream, well recall panel, Runes, reviews; consumes `tokens.css` — no per-framework drift.
- Status: ADDED. + notes:

**W0015 — Rune-glyph icon map**
- Phase: P7 · Depends: design.md · Source: design.md §4.4
- Scope: `midgard/design-system/icons.md` + 16/24px glyph set; runes, not emoji; chisel bevel on primary.
- Status: WORKING. + notes:
  - 2026-09-11 — built `midgard/design-system/icons/*.svg` (21 Elder Futhark stroke glyphs, `currentColor`, 24px viewBox) and `midgard/design-system/icons.md` (TOON map: gate + subsystem rune, usage, verification). Glyphs: fehu, tiwaz, ingwaz, raidho, algiz, dagaz, sowilo, kaunan, ansuz, ehwaz, jera, berkana, midgard, utgard, yggdrasil, ratatoskr, mimirsbrunn, valhalla, gungnir, heimdall, gjallarhorn.

**W0016 — House seals / realm tinting in UI**
- Phase: P7 · Depends: W0014 · Source: ENTRY-004, lore.md §VI
- Scope: house accents as structural color only; realm borders/tints; status = glyph + color + text.
- Status: ADDED. + notes:

**W0017 — Bifrost + Heimdall + Gjallarhorn ingress**
- Phase: P8 · Depends: W0014 · Source: lore V, AGENTS.md
- Scope: Caddy/Traefik reverse proxy; OAuth2-proxy/Authentik GitHub OAuth; cloudflared outbound tunnel; agent-card JWS signing.
- Status: ADDED. + notes:

**W0018 — Mjollnir issue→PR pipeline + review card**
- Phase: P9 (UI deps P7) · Depends: W0001 W0002 W0014 · Source: AGENTS.md Issue-to-PR
- Scope: issue listener, worktree+Utgard fix, tests, PR, human approval gate via Glitnir. **Never** force-merge.
- Status: ADDED. + notes:

**W0019 — Valhalla process health supervision**
- Phase: P10 · Depends: none · Source: lore V
- Scope: PM2/Docker supervision, health runes, dead-process bring-back, dashboard surfacing.
- Status: ADDED. + notes:

**W0020 — Toolchain adoption: firstmate, smidja, `.compliance`**
- Phase: P10 · Depends: none · Source: ENTRY-003/008
- Scope: reuse the validated OSS + existing local engines; never rebuild what exists.
- Status: WORKING. + notes:
  - 2026-09-11 — `workspace/config/toolchain.md` written: 16 engines mapped to Norse wrappers + auth env, plus an auth-status table with the exact check command per engine. TOON-check PASS.

**W0021 — Individual plan docs 01–20**
- Phase: P0 backlog · Source: `docs/plans/README.md` index rows
- Scope: one file per index row; drafted as reference, not re-approved.
- Status: WORKING. + notes:
  - 2026-09-11 — wrote `docs/plans/01-…` through `20-…` (objective, scope, done-when), statuses marked to current reality (06/07/08/12/17 built; others draft).

**W0022 — Company-house entity model**
- Phase: P6 · Depends: none · Source: plan 21 (approved), ENTRY-002/005
- Scope: per-tenant `svartalfaheim/<realm>/companies/` + `projects/` with entity-card template `.agents/assets/templates/company_entity.template.md`.
- Status: WORKING. + notes:
  - 2026-09-11 — template written; 11 entity cards seeded: `way-of/companies/{wayof,ymirlabs,brokkforge,runestone,muninn,dvalin,utgard,askr,mannheim}` and personal `zerwiz/companies/zerwiz`, `craig/companies/craig`.

**W0023 — Fediverse/community presence (Runestone, Muninn)**
- Phase: P6 optional · Depends: none · Source: house mandates
- Status: ADDED. + notes:

**W0024 — Ymir Rut v2.6 Rust port (the Reforging)**
- Phase: P11 · Depends: ALL P1–P10 · Source: ENTRY-009/010, `docs/ymir-rut.md`
- Scope: one-for-one re-floor to Rut crates — **never redesigned, only re-forged**. Not before end-to-end works.
- Status: BLOCKED BY DESIGN. + notes:

**W0025 — Realm onboarding runbook**
- Phase: P6 · Depends: W0022 · Source: Structure.md
- Scope: steps to stand up a new tenant, generate `.env.realm`, provision dirs.
- Status: WORKING. + notes:
  - 2026-09-11 — `docs/runbooks/realm-onboarding.md` written: tree, `.env.realm`, persona, entity cards, accents, verify.

**W0026 — Frontend SPA (Hlidskjalf, React + Vite)**
- Phase: P7 · Depends: W0027 · Source: plan 28, reference `assets/reference/index.html`, design.md
- Scope: port the reference shell verbatim (`.shell/.rail/.brand/.emblem/.wordmark/.nav/.gate`), `data-realm` tints, gates (Fleet/Tasks/Well/Runes/Reviews/Processes/Files/OmniChat), live SSE/WS store wiring, metric tiles + Glitnir cards, a11y pass.
- Status: ADDED. + notes:
  - 2026-09-11 WORKING — Hlidskjalf scaffolded at `apps/hlidskjalf` (React 19 + Vite + TS + Zustand). **Done:** shell grid (236px rail · 56px topbar · 192px stream), emblem/wordmark, `data-realm` tint binding, all eight gates, component set (AgentCard · TaskChip · TraceRow · RecallPanel · MetricTile · RuneTag · PRCard), bottom Ratatoskr+Runes stream (pausable), metric tiles, Glitnir PR cards, hash routes (`#/fleet…`), live mock stream. Typecheck + build green; headless render 0 console errors.
  - 2026-09-11 LEFT — real SSE/WS wiring to the gate API (depends on W0027), Skrymir Vue sub-app (W0032), `midgard/design-system/icons.md` rune set (W0015), full a11y pass (axe-core), visual-regression + E2E suites (W0048).
  - 2026-09-11 ADDED — mock GitHub auth gate + first-run workspace provisioner + multi-tenant grants (real Heimdall flow is W0028); per-user accent palette (presets + custom hex) persisted; new Ymir Mark SVG; profile + company settings and the Skills/Eindri forge (see **W0098** identity, **W0099** personalization/Profile, **W0100** Forge — the earlier cross-refs to W0051/W0052/W0053 were mis-numbered).
  - 2026-09-11 ADDED — interaction pass: global **modal + toast** system (`state/ui.ts`, `components/Overlay.tsx`) so every button acts; Glitnir PR cards wired (Seal / Request changes / View diff), process Restart/Logs, file Upload, Runes JSONL export, Fleet agent inspect, Well recall — all emit runes + toasts with press animation; draggable stream (W0115); local run scripts (W0115).

**W0027 — Backend gate API (Fastify, TS)**
- Phase: P7 · Depends: none · Source: plan 28
- Scope: monorepo scaffold; endpoints `/api/me|workspace|agents|tasks|well|runes|processes|reviews`; `GET /api/stream` (SSE), `WS /api/tasks/:id`; zod + pino; secrets only via `.env.local`.
- Status: ADDED. + notes:

**W0028 — Heimdall GitHub OAuth (login + session)**
- Phase: P6 · Depends: W0027 · Source: plan 28
- Scope: GitHub App code flow → token → `/user`; httpOnly JWT session; tenant mapping; JWS agent-card signing key.
- Status: ADDED. + notes:
  - 2026-09-11 WORKING (mock only) — the SPA ships a mock GitHub sign-in (`apps/hlidskjalf/src/services/auth.ts`, `app/Login.tsx`) with a first-run workspace provisioner and tenant grants (WayOf company; zerwiz + craig members). **LEFT:** real GitHub App code flow, httpOnly JWT session, `/user` mapping, JWS card-signing key, tenant boundary enforcement at the proxy.

**W0029 — Workspace auto-provisioner**
- Phase: P6 · Depends: W0028, W0022 · Source: plan 28, ENTRY-002
- Scope: first-login idempotent bootstrap of `svartalfaheim/<login>/` (companies/, projects/, workspace/{company,marketing,development,life,memory/daily}, `.env.realm`, `Brokk.md`, Agent Card); SQLite registry row.
- Done when: a fresh GitHub user logs in and lands in a working realm, no manual steps.
- Status: ADDED. + notes:

**W0030 — Hermes worker runtime (per-user agents)**
- Phase: P1/P4/P7 · Depends: W0027, W0008, W0002 · Source: plan 28
- Scope: controller spawns isolated Eindri workers (`docker_ephemeral`, Hermes model profile via LM Studio, clean worktree, network-none default); A2A lifecycle SUBMITTED→WORKING→TERMINAL; Redis queue; observe well + carve Runes.
- Status: ADDED. + notes:
  - 2026-09-11 — per-tenant identity per blueprint: each tenant carries `Hermes.md` persona + `hermes.config.json` (model/context/tools/workspaceRAG/dbPath) + `hermes_runner.ts` orchestration; every boot passes `tenant_context_loader` boundary checks. [assets/Yimir.md, plan 28 §8]

**W0031 — PI primary boot (firstmate adoption)**
- Phase: P10 · Depends: W0027 · Source: plan 28, `~/firstmate`
- Scope: system primary boots as PI exactly like firstmate: `fm-harness` resolution (`pi` default), `fm-spawn` dispatch, runtime backend (herdr/tmux), Pi supervision branch, treehouse worktrees; supervisord under Valhalla; command observer read-only (W0012) until Ratatoskr two-way.
- Status: ADDED. + notes:

**W0032 — Skrymir Vue sub-app + live-stream polish**
- Phase: P7 · Depends: W0026 · Source: plan 28
- Scope: Vue file-browser sub-app mounted in the Files gate; SSE/WS stream perf; compact mode.
- Status: ADDED. + notes:
  - 2026-09-11 WORKING (React placeholder) — the Files gate ships a React Skrymir tree + preview + realm-scoped paths. **LEFT:** the actual Vue sub-app mount, live file-change events, and stream perf work.

**W0033 — Toolchain registry & provider wrappers**
- Phase: P3/P7 · Depends: none · Source: `assets/Yimir.md` §196, plan 28 §8
- Scope: `workspace/config/toolchain.md` capabilities manifest (auth status per tool); `.agents/tools/*` per provider (supabase/firebase/pocketbase/vercel/netlify/expo/stripe); provision-verify-execute flow; typed wrappers replace ad-hoc CLI.
- Status: ADDED. + notes:

**W0034 — App-Fleet registry + process controller**
- Phase: P10 · Depends: none · Source: `assets/Yimir.md` (portfolio/process controller), plan 28 §8
- Scope: `workspace/config/portfolio.md` (path, proc, deployMethod, repo/env); `register_foreign_app` skill (scan+enroll any user app); `process_controller.ts` deterministic start/stop/restart/log over PM2/Docker/systemd/npm.
- Status: WORKING. + notes:
  - 2026-09-11 — `bin/valhalla.sh` built: `list` (PM2 + Docker + systemd, merged TOON), `status/restart/stop/start/logs <id>` dispatching to the owning manager (`pm2:<name>` / `docker:<name>` / `systemd:<unit>`). Wired into the gate API `/api/processes` — the Processes gate now shows the real fleet (25 daemons). `scripts/start.sh` / `stop.sh` now raise/lower the whole stack (gate API + SPA + Nornir cron + Bifrost bridge).

**W0035 — Zero-trust GitHub deployments**
- Phase: P9 · Depends: W0034 · Source: `assets/Yimir.md` (github_deploy), plan 28 §8
- Scope: `deploy-{staging,production}.yml` workflows; `gh secret sync` + `workflow run` dispatch; secrets never enter commit history; one skill `github_deploy.ts`.
- Status: ADDED. + notes:

**W0036 — Omnichannel gateway (Telegram + notify)**
- Phase: P6/P7 · Depends: W0027 · Source: `assets/Yimir.md` (gateways), plan 28 §8
- Scope: `telegram_bot.ts` remote command/status handler; `notify_user.ts` unified push (Telegram + WebSocket); web drawer; shares the same A2A/task state as Hlidskjalf.
- Status: ADDED. + notes:

**W0037 — Hlidskjalf Mobile (Expo/React Native)**
- Phase: P7 · Depends: W0026 · Source: `assets/Yimir.md` (apps/portal), plan 28 §8
- Scope: React Native (Expo) mobile dashboard — tenant switcher, fleet view, memory explorer, OmniChat drawer; consumes same API (W0027).
- Status: ADDED (optional). + notes:

**W0038 — Workspace RAG + entity-graph facade**
- Phase: P2 · Depends: W0004 · Source: `assets/Yimir.md` (workspace_rag + entity_graph), plan 28 §8
- Scope: hybrid Markdown(+vector) recall across `workspace/` (company/marketing/development/life/memory) with engram as engine; `memory/entity_graph/` relationship notes indexed; CLI skill `workspace_rag.ts`.
- Status: ADDED. + notes:

**W0039 — Backend: API specification & contract layer**
- Phase: P7 · Depends: W0027 · Source: plan 28, `assets/reference/index.html`
- Scope: OpenAPI 3.1 spec for all endpoints (`/api/me|workspace|agents|tasks|well|runes|processes|reviews`); zod schemas for request/response; versioned routes (`/api/v1/`); auth middleware (JWT + realm scoping); error envelope standard; rate limiting (token bucket); request validation pipeline; OpenAPI doc UI at `/api/docs`.
- Done when: spec is source of truth; frontend types generated from spec; all handlers conform; CI validates spec conformance.
- Status: ADDED. + notes:

**W0040 — Backend: Database layer & migrations (PostgreSQL + engram)**
- Phase: P2/P7 · Depends: W0004 W0027 · Source: Architecture.md, `assets/Yimir.md`
- Scope: Postgres 16 schema for realms, companies, projects, users, agent cards, tasks, runs, rune entries; Prisma ORM + raw SQL for engram bridge; migration runner (golang-migrate style); seed data for house seals; RLS policies for tenant isolation; backup/restore via pg_dump + MinIO.
- Done when: migrations run idempotently; tenant isolation enforced at DB level; backup/restore tested; engram bridge writes to Postgres + SQLite dual.
- Status: ADDED. + notes:

**W0041 — Backend: WebSocket/SSE real-time infrastructure**
- Phase: P7 · Depends: W0027 W0008 · Source: plan 28 §8 (A2A streaming)
- Scope: `WS /api/tasks/:id` (A2A task streaming); `GET /api/stream` (SSE for fleet/events/well); Redis pub/sub fanout; connection auth + realm scoping; heartbeat/keepalive; backpressure handling; connection pool metrics; graceful shutdown on deploy.
- Done when: Hlidskjalf fleet graph updates in real-time; A2A task SSE works end-to-end; no connection leaks under load.
- Status: ADDED. + notes:

**W0042 — Backend: Observability & telemetry (OTel + Prometheus)**
- Phase: P7 · Depends: W0027 · Source: Architecture.md (OTel), `.compliance` telemetry
- Scope: OTel SDK (traces/metrics/logs) auto-instrumented; Prometheus metrics exporter (`/metrics`); custom metrics (agent spawn latency, task duration, well recall latency, Utgard spawn time); structured JSON logging (pino); Loki log aggregation; Grafana dashboards (fleet health, API latency, error rates); alerting rules (dead agent, high error rate, well dry).
- Done when: traces flow end-to-end; dashboards show live fleet state; alerts fire correctly.
- Status: ADDED. + notes:

**W0043 — Backend: Testing infrastructure & CI pipeline**
- Phase: P10 · Depends: W0027 W0040 W0041 · Source: `.compliance` CI, plan 28
- Scope: unit tests (vitest), integration tests (testcontainers Postgres/Redis), contract tests (Pact), E2E tests (Playwright against API); test DB per suite; coverage threshold 80%; mutation testing (Stryker); property-based tests (fast-check) for schema validation; CI pipeline (lint → typecheck → unit → integration → contract → E2E).
- Done when: all test suites pass in CI; coverage ≥80%; mutation score ≥70%; PR cannot merge without green CI.
- Status: ADDED. + notes:

**W0044 — Frontend: Design system component library (React + Vue)**
- Phase: P7 · Depends: W0015 W0026 · Source: design.md, `midgard/design-system/tokens.css`
- Scope: shared component primitives (Button, Input, Card, Table, Modal, Tooltip, Avatar, Badge, Toaster, RuneGlyph); theme provider (Cinzel/JetBrains Mono/Inter, obsidian+cyan+violet); dark/light/system modes; a11y primitives (focus trap, aria live regions); Storybook documentation; visual regression tests (Chromatic); bundle size budget.
- Done when: all gates in Hlidskjalf use design system components; zero per-component CSS drift; Storybook published; a11y audit passes.
- Status: ADDED. + notes:

**W0045 — Frontend: State management & API client layer**
- Phase: P7 · Depends: W0039 W0026 · Source: plan 28
- Scope: TanStack Query v5 for server state (caching, invalidation, optimistic updates); Zustand for client state (tenant, UI prefs, chat); generated API client from OpenAPI spec (orval/hey-api); request interceptors (auth, realm headers); error boundary + toast notifications; SSE/WS hook abstraction for real-time gates.
- Done when: all data fetching through TanStack Query; zero manual fetch; optimistic updates work; type-safe API client.
- Status: ADDED. + notes:

**W0046 — Frontend: Gate implementations (Fleet, Tasks, Well, Runes, Reviews, Processes, Files, OmniChat)**
- Phase: P7 · Depends: W0044 W0045 · Source: `assets/reference/index.html`, plan 28
- Scope: Fleet gate (agent graph, status badges, live SSE); Tasks gate (A2A task list, detail, log stream, Glitnir review card); Well gate (recall search, episode timeline, memory graph); Runes gate (append-only log viewer, filter, export); Reviews gate (PR list, diff view, approve/request-changes); Processes gate (Valhalla health, restart, logs); Files gate (Skrymir Vue sub-app, tree nav, preview); OmniChat (Kaia chat, session launch, history).
- Done when: each gate renders live data from API; real-time updates via SSE/WS; keyboard navigation; a11y compliant.
- Status: ADDED. + notes:

**W0047 — Frontend: Routing, i18n, PWA & build pipeline**
- Phase: P7 · Depends: W0044 · Source: design.md, Architecture.md
- Scope: React Router v7 (file-based routes); realm-scoped routes (`/:realm/*`); i18n (en/de, Crowdin-ready); PWA (service worker, manifest, offline fallback); Vite build (code-split by gate, lazy load heavy views); bundle analyzer; CSP headers; SRI for external resources.
- Done when: routes work per realm; language switch persists; PWA installs; build output ≤ budget; CSP passes.
- Status: ADDED. + notes:

**W0048 — Frontend: E2E testing & visual regression**
- Phase: P7/P10 · Depends: W0046 · Source: plan 28
- Scope: Playwright E2E (critical paths: login → realm → fleet → task → well → review); visual regression (Chromatic/Playwright snapshots); accessibility tests (axe-core); performance budgets (LCP < 2.5s, TTI < 3.5s); cross-browser (Chromium, Firefox, WebKit).
- Done when: E2E suite green in CI; zero visual regressions; a11y score ≥95; performance budgets met.
- Status: ADDED. + notes:

**W0049 — Backend: Rate limiting, auth hardening & security audit**
- Phase: P8 · Depends: W0027 W0028 W0040 · Source: Architecture.md security boundaries
- Scope: per-realm rate limits (token bucket + Redis); JWT rotation + refresh; CSRF protection; security headers (Helmet); input sanitization; SQL injection prevention (Prisma parameterized); dependency scanning (npm audit + Snyk); secret detection (git-secrets); pen-test checklist.
- Done when: security scan clean; rate limits enforce per-realm; JWT rotation works; no high/critical vulns.
- Status: ADDED. + notes:

**W0050 — Backend: Admin/ops tooling (CLI + internal API)**
- Phase: P10 · Depends: W0027 W0034 · Source: `assets/Yimir.md` (ops), plan 28
- Scope: `ymir-admin` CLI (realm create/list/suspend, agent card rotate, well flush, rune export); internal admin API (`/api/admin/*`) with RBAC; metrics export for Prometheus; log tailing; task replay/inspect; migration runner CLI.
- Done when: admin can manage realms without DB access; CLI covers top 10 ops tasks; internal API RBAC enforced.
- Status: ADDED. + notes:

**W0051 — Realm AGENTS.md unification (persona per tenant)**
- Phase: P6 · Depends: W0022 · Source: user directive 2026-09-11
- Scope: rename `svartalfaheim/*/Brokk.md` → `AGENTS.md` for each realm (way-of, zerwiz, craig); root `AGENTS.md` becomes single source of truth for all tools (opencode, pi, claude); each realm AGENTS.md scopes directives to that tenant.
- Done when: three realm AGENTS.md exist; root AGENTS.md contains full skills/assets/tools registry; opencode/pi/claude all load from `.agents/` path.
- Status: ADDED. + notes:

**W0052 — Galdr internal registry update (skills/assets/tools)**
- Phase: P3 · Depends: W0007 · Source: user directive 2026-09-11
- Scope: update `.agents/skills/galdr/SKILL.md` with live internal skills registry (galdr, tyr-check, brokk-craft), assets inventory (Eindri profiles, build categories, TOON schemas, firstmate configs, templates), tools inventory (tasks-cli, yggdrasil, hermes_runner, herder, vector_db, firebase, supabase), opencode commands, PI/firstmate integration.
- Done when: galdr skill contains complete registry; Brokk agent file synced; root AGENTS.md mirrors same inventory.
- Status: ADDED. + notes:

**W0053 — PI/Firstmate integration in Galdr (W0031)**
- Phase: P10 · Depends: W0031 · Source: masterplan W0031, plan 28
- Scope: add PI boot stack to galdr skill (fm-harness resolution, fm-spawn dispatch, herdr runtime, Valhalla supervision, treehouse worktrees, command observer); add 6th forge gate (PI/Firstmate compatibility); create firstmate asset directory (pi-profile.yml, herdr-profile.toml, fm-spawn.schema.json, supervision-tree.yml).
- Done when: galdr documents PI CLI requirements; 6 gates pass; firstmate assets exist and referenced.
- Status: ADDED. + notes:

**W0054 — Brokk agent file operational manual**
- Phase: P6 · Depends: W0051 W0052 · Source: user directive 2026-09-11
- Scope: create `.opencode/agents/brokk.md` (now deprecated in favor of root AGENTS.md) with full operational knowledge: directory routing, append-only discipline, skills registry, TOON format, tasks-cli, current system state, Norse subsystem map, operational laws, security, PI/firstmate integration.
- Done when: root AGENTS.md contains complete operational knowledge; all tools load from single source.
- Status: ADDED. + notes:

**W0055 — Galdr-crafter cleanup**
- Phase: P3 · Depends: W0007 · Source: user directive 2026-09-11
- Scope: remove build-tool-agent content accidentally appended to galdr-crafter SKILL.md; restore clean skill definition with target agent integration section.
- Done when: galdr-crafter SKILL.md is clean; no extraneous content.
- Status: ADDED. + notes:

**W0056 — Backend: Agent Card registry & JWS signing (Heimdall)**
- Phase: P8 · Depends: W0027 W0040 · Source: AGENTS.md, Architecture.md (Heimdall)
- Scope: Agent Card CRUD (`POST/GET/PUT/DELETE /.well-known/agent-card.json`); JWS signing keys (RS256); realm-scoped registry; capability-based discovery; card validation endpoint; revocation list; expiry rotation.
- Done when: agents can publish/discover cards; Heimdall signs/verifies; cross-realm discovery works; revoked cards rejected.
- Status: ADDED. + notes:

**W0057 — Backend: A2A task executor & SSE bridge (Ratatoskr)**
- Phase: P4 · Depends: W0008 W0041 · Source: Architecture.md (Ratatoskr), plan 28
- Scope: A2A task lifecycle engine (SUBMITTED→WORKING→TERMINAL); SSE streaming for task updates; Redis queue consumer; task timeout/retry policy; idempotency keys; task artifact storage (MinIO); outcome observation to Mimirsbrunn + Runes.
- Done when: Kaia can dispatch A2A tasks to Eindri; SSE streams progress; terminal states never restart; artifacts persisted; outcomes observed.
- Status: ADDED. + notes:

**W0058 — Backend: Mimirsbrunn recall/observe API (engram bridge)**
- Phase: P2 · Depends: W0004 W0040 · Source: Architecture.md (Mimirsbrunn), ENTRY-007
- Scope: `GET /recall` (hybrid/cosine/spreading, agent-scoped, as_of time-travel); `POST /observe` (episodes, facts, entities, salience); engram bridge proxy to `:4602`; tenant isolation; access-log importance decay.
- Done when: Brokk/Kaia recall before dispatch; every action observed; dry well fires cold never blocks; hybrid mode default.
- Status: ADDED. + notes:

**W0059 — Backend: Runes audit ledger API**
- Phase: P2 · Depends: W0005 W0040 · Source: Architecture.md (Runes), ENTRY-001/003
- Scope: append-only JSONL write (`POST /runes`); read with filters (agent, realm, order, date range); checksum verification; export (NDJSON/CSV); retention policy; integrity check endpoint.
- Done when: every significant action carved; Hlidskjalf Runes gate renders; integrity check passes; export works.
- Status: ADDED. + notes:

**W0060 — Backend: Yggdrasil worktree manager API**
- Phase: P1 · Depends: W0001 W0040 · Source: Architecture.md (Yggdrasil), Structure.md
- Scope: create worktree (`.yggdrasil/<agent-id>/`); merge (squash/ff/none); cleanup; conflict detection; branch listing; lock file; atomic operations.
- Done when: `brokk agent spawn` creates isolated worktree; merge explicit; cleanup automated; zero collisions.
- Status: ADDED. + notes:

**W0061 — Backend: Utgard sandbox provisioner API**
- Phase: P1 · Depends: W0002 W0040 · Source: Architecture.md (Utgard), AGENTS.md laws 2/3/6
- Scope: container create (rootless, network-none, CPU/RAM/timeout caps); file mount (worktree only); exec (command + env); stream logs; destroy; resource metrics; health check.
- Done when: untrusted task runs sealed; failed run leaves no trace; resource caps enforced; network-none by default.
- Status: ADDED. + notes:

**W0062 — Backend: Skrymir file browser API**
- Phase: P7 · Depends: W0027 W0040 · Source: Architecture.md (Skrymir), plan 28
- Scope: tree listing (realm-scoped); file read (text/binary); preview (image/markdown/pdf); upload (chunked, resumable); delete; move/rename; search; permissions (read/write per realm).
- Done when: Files gate renders tree; preview works; upload resumable; per-realm permissions enforced.
- Status: ADDED. + notes:

**W0063 — Backend: Cron spine & daily briefing runner**
- Phase: P5 · Depends: W0011 W0027 · Source: plan 24, AGENTS.md cron
- Scope: stateless spawn pattern (fresh process → inject → execute → write → exit); daily 07:00 briefing → `workspace/memory/daily/YYYY-MM-DD.md`; git backup sync; social poster; cron DSL (cron expr + payload); run history; dead-man alert.
- Done when: daily briefing writes; git backup runs; social posts; history queryable.
- Status: ADDED. + notes:
  - 2026-09-11 — duplicate scope with W0072 (same runner). Dedupe at execution; the memory-housekeeping job and cron history/dead-man API left to build = W0089, status page = W0090. [plan 24, plan 27-context-budget]

**W0064 — Backend: Toolchain registry & provider wrappers**
- Phase: P3/P7 · Depends: W0033 W0040 · Source: `assets/Yimir.md` §196, plan 28
- Scope: `workspace/config/toolchain.md` capabilities manifest; `.agents/tools/*` per provider (supabase/firebase/pocketbase/vercel/netlify/expo/stripe); provision-verify-execute flow; typed wrappers replace ad-hoc CLI.
- Done when: manifest lists capabilities; wrappers typed; provision flow works; CLI usage eliminated.
- Status: ADDED. + notes:

**W0065 — Backend: Zero-trust GitHub deployments**
- Phase: P9 · Depends: W0035 W0027 · Source: `assets/Yimir.md` (github_deploy), plan 28
- Scope: `deploy-{staging,production}.yml` workflows; `gh secret sync` + `workflow run` dispatch; secrets never in commit history; one skill `github_deploy.ts`; rollback on failure.
- Done when: workflows run clean; secrets via `gh secret`; rollback tested; skill invoked.
- Status: ADDED. + notes:

**W0066 — Backend: Omnichannel gateway (Telegram + notify)**
- Phase: P6/P7 · Depends: W0036 W0027 · Source: `assets/Yimir.md` (gateways), plan 28
- Scope: `telegram_bot.ts` remote command/status; `notify_user.ts` unified push (Telegram + WS); web drawer; shares A2A/task state with Hlidskjalf; command allowlist.
- Done when: Telegram bot responds; push delivers; web drawer shows same state; allowlist enforced.
- Status: ADDED. + notes:

**W0067 — Frontend: OmniChat (Kaia chat + session launch + history)**
- Phase: P7 · Depends: W0045 W0041 · Source: plan 28, `assets/reference/index.html`
- Scope: chat thread (Kaia + history); session launch (Eindri dispatch); context injection (realm, active plans, well recall); markdown rendering; code blocks with copy; slash commands (`/spawn`, `/recall`, `/runes`); thread persistence.
- Done when: Kaia chat works; session launch dispatches Eindri; context injected; history persists across reloads.
- Status: ADDED. + notes:

**W0068 — Frontend: Fleet graph (live agent visualization)**
- Phase: P7 · Depends: W0044 W0041 · Source: `assets/reference/index.html`, plan 28
- Scope: force-directed graph (D3.js/Cytoscape); nodes = agents (Brokk, Kaia, Eindri); edges = A2A tasks; live SSE status badges; click → task detail; filter by realm/role/state; minimap; export PNG/SVG.
- Done when: graph renders live; SSE updates status; click navigation works; a11y compliant.
- Status: ADDED. + notes:

**W0069 — Frontend: Memory explorer (Well recall UI)**
- Phase: P7 · Depends: W0044 W0058 · Source: plan 28, smidja visualizer `#/memory`
- Scope: recall search (query + mode + k); episode timeline; entity graph (cytoscape); fact table (SPO triples); salience decay viz; `as_of` time-travel slider; export to Markdown.
- Done when: recall works; timeline scrolls; entity graph navigable; time-travel functional.
- Status: ADDED. + notes:

**W0070 — Frontend: Runes log viewer (append-only audit UI)**
- Phase: P7 · Depends: W0044 W0059 · Source: plan 28, `docs/append-only-log.md`
- Scope: infinite scroll log; filter (agent, realm, order, date, type); checksum badge; search; export NDJSON/CSV; detail modal (full entry); integrity check button.
- Done when: log renders; filters work; export downloads; integrity check passes.
- Status: ADDED. + notes:

**W0071 — Frontend: Processes gate (Valhalla health + control)**
- Phase: P7 · Depends: W0044 W0041 · Source: plan 28, Architecture.md (Valhalla)
- Scope: process table (name, pid, status, uptime, CPU, mem, realm); start/stop/restart actions; log tail modal (SSE); health runes (green/yellow/red); fleet overview; auto-refresh.
- Done when: process list live; actions execute; logs stream; health badges update.
- Status: ADDED. + notes:

**W0072 — Backend: Cron spine & daily briefing runner**
- Phase: P5 · Depends: W0011 W0027 · Source: plan 24, AGENTS.md cron
- Scope: stateless spawn pattern (fresh process → inject → execute → write → exit); daily 07:00 briefing → `workspace/memory/daily/YYYY-MM-DD.md`; git backup sync; social poster; cron DSL (cron expr + payload); run history; dead-man alert.
- Done when: daily briefing writes; git backup runs; social posts; history queryable.
- Status: ADDED. + notes:

**W0073 — Backend: PI primary boot (firstmate adoption)**
- Phase: P10 · Depends: W0031 W0027 · Source: plan 28, `~/firstmate`
- Scope: `fm-harness` resolution (`pi` profile); `fm-spawn` dispatch Eindri; herdr/tmux runtime backend; Pi supervision branch (Valhalla); treehouse worktrees; command observer read-only until Ratatoskr two-way.
- Done when: `pi` boots; `fm-spawn` dispatches; herdr panes visible; Valhalla supervises; observer read-only.
- Status: ADDED. + notes:

**W0074 — Backend: Hlidskjalf Mobile API compat layer**
- Phase: P7 · Depends: W0037 W0027 · Source: plan 28, `assets/Yimir.md` (apps/portal)
- Scope: mobile-optimized endpoints (reduced payload); push notifications (FCM/APNs); offline queue; biometric auth; deep links; session resume.
- Done when: Expo app works; push delivers; offline queues; biometric unlocks; deep links navigate.
- Status: ADDED. + notes:

**W0075 — Backend: Smíðja run-store & trace ingest (sessions · phases · events)**
- Phase: P7/P9 · Depends: W0040 W0027 · Source: smidja `references/observability.md`, visualizer `server/db.ts`
- Scope: mirror of the smidja trace — `sessions`, `phases` (kind/owner/seq/attempt/retries), `events` (12 types, `parent_id` span nesting, rowid cursor), `envelopes` (typed handoff parses), `gate_results` (+ `checks_json` evidence), `agent_sessions` (model/color/`context_tokens`/`context_window`); WAL pragmas; poll contract `?after=<rowid>&limit=500`; `reconcileStaleRunning`. Ingest the tracer so runs land in Ymir, not only in `smidja/smidja_data/smidja.db`.
- Done when: a run's phases/events/envelopes/gates/agent-sessions are queryable with rowid-cursor paging; stale running rows reconcile against live pids.
- Status: ADDED. + notes:
  - 2026-09-11 — `WORKING` (partial): the gate API serves the repo's own `smidja/smidja_data/smidja.db` read-only via `bun:sqlite` (`sessions`/`phases`/`events`/`envelopes`/`gate_results`/`agent_sessions`); `bin/factory-observe.sh` (external `~/command/factory` path) was deleted and replaced by repo-local `bin/smidja-observe.sh`. Absent db reported honestly. WAL pragmas, rowid-cursor poll, and `reconcileStaleRunning` remain. [plan 28 §9]

**W0076 — Backend: Smíðja run control API (stop · pause · resume · steer · archive)**
- Phase: P9 · Depends: W0075 W0041 · Source: visualizer `server/index.ts`
- Scope: `POST /api/smidja/:id/{stop,pause,resume,steer,archive}` — children-first SIGTERM; SIGSTOP/SIGCONT only live agent pids; steer appended to `steer.md`; idempotent `finalizeStopped`; `processes` table (kind smidja|agent, pid, command) as the only source of "what is this run running".
- Done when: a live run can be stopped/paused/resumed and steered from the gate; a Stop always leaves the session closed; archive is a review-only flag.
- Status: ADDED. + notes:

**W0077 — Backend: Roster & model catalog + session launch**
- Phase: P7/P9 · Depends: W0075 · Source: visualizer `server/roster-api.ts`, `model-catalog.ts`, `chat.ts`
- Scope: `GET /api/rosters · /api/rosters/:name · /api/models` (resolvable flags), `POST /api/smidja/session` (roster + orchestrator model + task); `roster.yaml` resolution; weak-orchestrator guard (sub-9B refused).
- Done when: pickers list real stacks/models; a task launches a run and returns its `smidja_id`.
- Status: ADDED. + notes:

**W0078 — Backend: Decisions (failure clustering) & Stats APIs**
- Phase: P7/P9 · Depends: W0075 · Source: visualizer `db.decisions()` / `db.stats()`
- Scope: `GET /api/smidja/decisions` (failures grouped by diagnosis + model, recommended fix, last_seen, runs); `GET /api/smidja/stats` (totals, usage input/output/cache_read/cache_write, cache-hit ratio, vendor cost + savings catalog, local-vs-online provider split, by_chain, by_model).
- Done when: the self-improving surface answers *what to change*; stats reconcile to the trace.
- Status: ADDED. + notes:
  - 2026-09-11 — `WORKING` (partial): `GET /api/smidja/decisions` (failed phases grouped by phase+owner model from `phases`⋈`agent_sessions`) and `GET /api/smidja/stats` (totals + by_chain + by_model) are live. Recommended-fix text, cache savings, and provider split remain. [plan 28 §9]

**W0079 — Backend: Local settings store (MCP keys, masked)**
- Phase: P7 · Depends: W0027 · Source: visualizer `server/settings.ts`
- Scope: `GET /api/settings` (masked values only), `POST /api/settings/save` writing realm `.env` keys; never return raw secrets; allowlist of writable keys.
- Done when: keys save to `.env`; GET returns masked state only.
- Status: ADDED. + notes:

**W0080 — Frontend: Sessions list (smidja runs)**
- Phase: P7 · Depends: W0044 W0045 W0075 · Source: visualizer `SessionsList.vue`, `SessionCard.vue`
- Scope: all-inclusive run list (`?scope=all`); status running/success/fail; phase-dot mini-progress; per-card agents; model; tokens/cost; archive filter; poll refresh.
- Done when: a run appears with its phase dots; click opens the trace; archive toggle works.
- Status: ADDED. + notes:
  - 2026-09-11 — `WORKING` (partial): Hlidskjalf **Sessions** gate reads `/api/smidja/sessions` (id, factory, engineer, status, tokens, cost, started); row click selects the run and opens Trace. Phase-dot mini-progress + archive filter remain. [plan 28 §9]

**W0081 — Frontend: Session Trace (lane waterfall + live poll)**
- Phase: P7 · Depends: W0044 W0045 W0075 · Source: visualizer `SessionTrace.vue`
- Scope: phase lanes by kind/owner/seq, subagent lanes stacked under dispatcher; span nesting (`parent_id`) expanding agent → tool-call; rowid-cursor 500ms poll; queued dashed vs running vs success/fail; timeout/pause/resume/steer controls surfaced.
- Done when: a live run draws lanes that grow as events land; tool calls nest; history pages on scroll.
- Status: ADDED. + notes:
  - 2026-09-11 — `WORKING` (partial): Hlidskjalf **Trace** gate renders phases (seq/kind/owner/status/attempt/error), agent context bars (`context_tokens`/`context_window`), and tool calls from `events`; `GET /api/smidja/sessions/:id` returns the full detail bundle. Span-nested waterfall, 500ms rowid poll, and controls remain. [plan 28 §9]

**W0082 — Frontend: Phase Detail (envelopes · gates+evidence · thinking · prompts · tool calls · context/cost)**
- Phase: P7 · Depends: W0044 W0045 W0075 · Source: visualizer `PhaseDetail.vue`
- Scope: typed envelope viewers; gate checks evidence (`{item, ok, note}`) not just the verdict; per-agent thinking/reasoning; exact system/user prompts; tool-call cards (args, result, duration, ok); context occupancy bar (`context_tokens/context_window`); per-phase cost table (input/output/cache_read/cache_write, reasoning nested under output).
- Done when: a green gate shows *what it verified*; thinking/prompts render; the cost table reconciles and the context bar stays blank when unknown.
- Status: ADDED. + notes:

**W0083 — Frontend: Decisions view (self-improving surface)**
- Phase: P7 · Depends: W0044 W0045 W0078 · Source: visualizer `DecisionsView.vue`
- Scope: failures by diagnosis + model; counts; last_seen; affected runs; actionable recommended fix.
- Done when: repeated failures cluster with a fix.
- Status: ADDED. + notes:
  - 2026-09-11 — `WORKING` (partial): Hlidskjalf **Decisions** gate renders the failure buckets (phase, model, count, error). Recommended-fix/action text + last_seen/affected-runs remain. [plan 28 §9]

**W0084 — Frontend: Stats view (tokens · cost · cache · savings · providers)**
- Phase: P7 · Depends: W0044 W0045 W0078 · Source: visualizer `StatsView.vue`
- Scope: totals; usage breakdown; cache-hit ratio + avg per run; vendor catalog with published-rate savings; local-vs-online provider split; by-chain and by-model tables.
- Done when: the dashboard shows where tokens/dollars went and what caching saved.
- Status: ADDED. + notes:
  - 2026-09-11 — `WORKING` (partial): Hlidskjalf **Stats** gate renders totals (runs/tokens/cost) plus by-chain and by-model tables. Cache-hit ratio, vendor savings catalog, and provider split remain. [plan 28 §9]

**W0085 — Frontend: Settings view + OmniChat smidja upgrade**
- Phase: P7 · Depends: W0044 W0045 W0079 W0067 · Source: visualizer `SettingsView.vue`, `ChatView.vue`, `ToolCallCard.vue`
- Scope: settings panel (MCP keys masked, save); chat upgrade to match the visualizer — multi-session switcher (new/switch/delete), model picker, streaming, inline tool-call cards, session-launch cards linking to the trace, roster picker.
- Done when: keys save; chat keeps history across sessions; a launched run links to its trace; tool calls expand inline.
- Status: ADDED. + notes:

**W0086 — Backend: Command/Firstmate observer service (read-only bridge)**
- Phase: P6 · Depends: W0012 W0004 W0005 · Source: plan 23, W0031
- Scope: extend the W0012 spine into a full observer — read `command` (FEATURES.md registry, `.compliance/` gates, tenants, `smidja.db`, `kaia.engram`) and `firstmate` (captain/crew sessions, worktree state, supervision handoffs) on schedule + webhook/file-change; each observation → Mimirsbrunn episode (tag `source:command|firstmate`) + filtered Runes line; **never write** into either tree (realm-boundary law).
- Done when: both systems' live state is observable; observations land in the well and the ledger; no write crosses the boundary.
- Status: ADDED. + notes:
  - 2026-09-11 — `RESCOPED` (self-observation): the full observer reads **Ymir's own runtime** (orders, roster, well, ledger, Smíðja runs) plus the read-only external worktree root. No `command`/`firstmate` paths are read. Watering the well and A2A port remain the W0086 lift. [plan 23]

**W0087 — Frontend: Houses & entities registry (Hlidskjalf)**
- Phase: P7 · Depends: W0044 W0045 W0046 W0022 · Source: plans 21/22
- Scope: registry view for per-tenant `companies/<house>/` + `projects/<project>/` entity cards (name/type/owner/realm/house/products/repo/status/lore_line); house accents from W0016; drill house → projects → card; tenant isolation.
- Done when: houses/projects render per realm; entity cards open; cross-realm data never leaks.
- Status: ADDED. + notes:

**W0088 — Frontend: External systems view (Command/Firstmate)**
- Phase: P7 · Depends: W0044 W0045 W0086 · Source: plan 23
- Scope: Hlidskjalf tab listing `command` and `firstmate` with live process/repo/smidja-run state (FEATURES registry, `.compliance/` gates, smidja runs, captain/crew + worktree state); read-only; links to observer episodes in the well.
- Done when: both external systems show live state; click-through reaches the observed episode.
- Status: ADDED. + notes:

**W0089 — Backend: Cron completion — memory housekeeping + job history API**
- Phase: P5 · Depends: W0011 W0004 W0063 · Source: plan 24, plan 27-context-budget
- Scope: nightly memory-housekeeping job (engram `decay()`/`compress()`/backup); cron job registry + run history + dead-man alert API; schedule config; every job stateless and finite.
- Done when: housekeeping runs nightly into the well; job history queryable; a missed job alerts.
- Status: ADDED. + notes:

**W0090 — Frontend: Cron status page (Hlidskjalf)**
- Phase: P7 · Depends: W0044 W0045 W0089 · Source: plan 24
- Scope: job list (last/next fire, status, output link, failures); pause/resume a schedule; run detail.
- Done when: every cron job's last/next run and status is visible; pause/resume works.
- Status: ADDED. + notes:

**W0091 — Hermóðr: `hermod-bridge` skill + `hermod_context` schema**
- Phase: P4 · Depends: W0008 W0009 W0010 W0007 · Source: plan 27
- Scope: `hermod-bridge` skill — poll inbox, execute an A2A task via its MCP tool set, stream the result back over A2A, FYI peers, self-label `<basename-cwd>-<4hex>`; Utgard-validated and registered; extend `InterAgentMessage` (`.agents/bus/protocol.ts`) with optional `hermod_context` = `{mcp_tool_set, orchestrator_id, grant_id, fallback_mcp}`.
- Done when: a Hermóðr-mediated task completes end-to-end; the schema carries the context; the skill is validated and listed.
- Status: ADDED. + notes:

**W0092 — Backend: Mimirsbrunn + Runes Hermóðr observability**
- Phase: P4/P7 · Depends: W0058 W0059 W0091 · Source: plan 27
- Scope: index both paths with `hermod=true` — A2A task states and MCP tool operations (`tool_name`, `operation`, `result_status`); `GET /timeline?hermod=true`; hybrid recall across A2A+MCP interleaved by timestamp; Runes fields `hermod_flag`, `mcp_tool`, `mcp_operation`, `mcp_result`, `grant_id`, `jws_verified`.
- Done when: A2A and MCP flows interleave by time; every Hermóðr step is carved.
- Status: ADDED. + notes:

**W0093 — Frontend: Hlidskjalf Hermóðr fleet indicators**
- Phase: P7 · Depends: W0044 W0045 W0092 W0068 · Source: plan 27
- Scope: fleet-graph overlays — A2A task state, active MCP tool set per specialist, cross-realm grant status, open tasks requiring tool access; realm-scoped.
- Done when: the fleet graph shows delegation and tool composition live.
- Status: ADDED. + notes:

**W0094 — Backend: Cross-realm grants + A2A state mapping + trace propagation**
- Phase: P4 · Depends: W0008 W0009 W0056 · Source: plans 25/26
- Scope: explicit cross-realm grant registry (`grant_id`, `from_realm`, `to_realm`, `granted_at`, scope) enforced before any A2A dispatch and carved to Runes; A2A→internal task-state mapping table; W3C trace-context propagation across A2A hops (joins W0042 OTel).
- Done when: a cross-realm call fails without a grant and succeeds with one; the state mapping is documented and enforced; traces correlate across agents.
- Status: ADDED. + notes:

**W0095 — Skills: Four-layer plan & execution gates**
- Phase: P3 · Depends: W0007 W0052 · Source: `26-firstmate-four-layer`
- Scope: adopt into `.agents/skills/` the four-layer discipline — `validate-plan` Layer 3 gate (file map, type signatures, call-stack mermaid, ≥2 test signatures), `ticket-executor` Phase 0 vertical-slice gate (no horizontal work before Slice 1 passes e2e), pre-mortem confidence prompt, measurable-goal ticket frontmatter; Utgard-validated; covers MCP registration in `command`.
- Done when: a plan missing Layer 3 is rejected; execution starts with a vertical slice; measurable goals are required.
- Status: ADDED. + notes:

**W0096 — Backend: Context-budget enforcement in PI boot + harness token reporting**
- Phase: P10 · Depends: W0031 W0058 W0053 · Source: `27-firstmate-context-budget`
- Scope: `fm-session-start` budget init; `fm-spawn` passes the budget to the worker; harness adapters (Claude/Codex/OpenCode/Pi) report token usage to Mimirsbrunn (`:4602`); budget status recalled before task spawn; budget metadata on A2A task cards; 50% "dumb zone" warning; 07:00 `fm-brief` budget section.
- Done when: workers boot budget-aware; token usage flows to the well; a task over 50% warns; metric `context_budget_warning_accuracy` tracked.
- Status: ADDED. + notes:

**W0097 — Frontend: Context-budget visibility (fleet digest + Hlidskjalf)**
- Phase: P7 · Depends: W0044 W0045 W0096 · Source: `27-firstmate-context-budget`, plan 25
- Scope: budget state in the fleet-state digest and agent/task views (green/yellow/red/critical bars), warning surface, next-best-action (compaction/handoff).
- Done when: an operator sees any task > 50% context and its suggested action.
- Status: ADDED. + notes:

**W0115 — Repo-local distro layout + per-tool loaders**
- Phase: P7/P10 · Depends: W0031 · Source: user directive 2026-09-11, plan 29
- Scope: every agent, skill, extension, and backend loads from inside `/home/zerwiz/Ymir` — `.agents/agents/` (agent definitions), `.agents/skills/` (skills), `.agents/backend/` (fleet backend scripts), `.pi/extensions/` (Pi extensions). No reliance on global `~/.pi/` or `~/.config/opencode/` for project behaviour. Ship per-tool loader scripts/config (OpenCode plugin + agent loader, Pi extension + agent loader, Claude/Codex/Cursor hooks) that point into the repo.
- Done when: a fresh clone boots with every agent/skill/extension/backend resolved from the repo; a loader script per harness proves it; nothing project-critical lives only in a global dir.

**W0113 — Galdr dual-surface (agent + skill)**
- Phase: P3 · Depends: W0052 W0115 · Source: user directive 2026-09-11
- Scope: the same Galdr content is loadable as an **agent** (`.agents/agents/galdr.md`) and a **skill** (`.agents/skills/galdr/SKILL.md`); a sync check keeps the two bodies from drifting; Galdr's routing knows `.agents/agents/galdr.md` and the `.agents/agents/*` roster.
- Done when: both surfaces load; a `--check` fails on drift; Galdr names its agent twin in its router.

**W0114 — Port firstmate `.pi/extensions` to Norse (Ró + Skuld)**
- Phase: P10 · Depends: W0073 W0115 · Source: `/home/zerwiz/firstmate/.pi/extensions`, user directive 2026-09-11
- Scope: adapt the full firstmate Pi extension set — **Ró** (calm presentation: `fm-calm.ts` + `lib/fm-calm-*.ts`), **Skuld** (supervision branch: `fm-branch-supervision.ts` + `lib/fm-branch-*.ts`), and re-port `syn-turnend-guard.ts` + `gna-pi-watch.ts` WITH the Ró + Skuld hooks (undoing the earlier strip). Retarget `fm-*`→Norse, `FM_*`→`BROKK_*`/`RO_*`/`SKULD_*`, `Firstmate`→`Brokk`, config `calm`→`config/ro`.
- Done when: Pi loads Ró, Skuld, Sýn, Gná together with no fm-* files remaining; calm mode works; the supervision branch dispatches.

**W0101 — Backend port: firstmate `bin/` → Brokk Norse backend**
- Phase: P10 · Depends: W0115 W0114 · Source: `/home/zerwiz/Ymir/.agents/backend`, user directive 2026-09-11
- Scope: adapt the copied firstmate backend under `.agents/backend/` to the Brokk Norse runtime — map every used `fm-*` script to its Norse equivalent (`saga-*`, `syn-*`, `rodd-*`, `gleipnir-*`, `nornir-*`, `einherjar-*`, `erindi-*`, `vor-*`), retire unwired scripts or mark them clearly, and wire the adapted backend into `bin/`.
- Done when: no runtime path calls an `fm-*` backend script; the Norse backend is self-contained under the repo and verified.

**W0102 — Expanded Eindri roster, loadable by OpenCode and Pi**
- Phase: P7 · Depends: W0115 · Source: `.agents/agents/`, user directive 2026-09-11
- Scope: expand the Eindri beyond Sindri/Bragi/Huginn (add the planner/reviewer/documenter/scout roles), move/store them under `.agents/agents/`, and make each loadable as an OpenCode subagent (`.opencode/agent/*.md`) and a Pi agent (repo-resolved `.pi/agents/` via the W0115 loader).
- Done when: OpenCode lists every Eindri; Pi resolves every Eindri from the repo; the three standard roles keep their profiles.

**W0103 — Pi boot auto-start of the Nornir cron (firstmate parity)**
- Phase: P10 · Depends: W0114 W0063 · Source: user directive 2026-09-11, plan 29
- Scope: the Pi session-open path must inject the Sága digest AND start the Nornir jobs automatically on boot, exactly as the upstream distro auto-arms supervision — no manual `nornir-cron-start`.
- Done when: booting Pi starts the Nornir jobs; the digest reports them running; a stop→boot cycle restarts them.
- Status: ADDED. + notes:

**W0104 — Config: adapt `.agents/config/` to the Brokk runtime**
- Phase: P10 · Depends: W0115 · Source: `.agents/config/`, user directive 2026-09-11
- Scope: `.agents/config/` carries the firstmate configs (`calm`, `startup-memory-budget`, `crew-dispatch.json`). Adapt them to Norse/repo-local: `config/ro` (Ró on/off), `config/eindri-dispatch.json`, `config/startup-memory-budget`; make the runtime read **`.agents/config/`** (or `config/`, repo-local) rather than a global home, and document every key.
- Done when: the runtime resolves each config from the repo; `config/ro` and `config/eindri-dispatch.json` are live; no config is read from a global dir.

**W0105 — Tests: adapt `.agents/tests/` and add a repo smoke test**
- Phase: P10 · Depends: W0101 · Source: `.agents/tests/`, user directive 2026-09-11
- Scope: `.agents/tests/` holds the firstmate test suite (`fm-*.test.sh`). Adapt to the Norse runtime (rename `fm-*` → Norse, retarget paths), keep the runnable subset, mark or retire the rest, and add a **repo smoke test** that boots the digest, arms Sýn, starts Nornir, and asserts the markers — the folder smoke test the Allfather asked for.
- Done when: `bash .agents/tests/smoke.test.sh` passes from a clean session; the adapted suite runs; retired tests are explicit.

**W0106 — Data logic: reuse `assets/data/` for Mimirsbrunn**
- Phase: P2 · Depends: W0004 W0038 · Source: `assets/data/`, user directive 2026-09-11
- Scope: `assets/data/` carries real data-pipeline material (server knowledge, planning, migration, `captain.md`). Copy/rewrite the scripts and shapes into the well: ingest into Mimirsbrunn, map `data/*.md` → episodes/facts, and reuse the migration/ingest logic for the engram. Keep source material tracked; ship working scripts under `.agents/tools/`.
- Done when: the data logic is implemented (not referenced), ingests into Mimirsbrunn, and is covered by a test.

**W0107 — Reference skills → Norse (`assets/reference/skills/`)**
- Phase: P3 · Depends: W0052 · Source: `assets/reference/skills/`, user directive 2026-09-11
- Scope: the upstream skill library (`afk`, `bearings`, `stow`, `project-management`, `harness-adapters`, `decision-hold-lifecycle`, `ask-user-authority`, …) is reference material. Convert each to a Norse-named skill whose role matches the figure, place it under `.agents/skills/`, register it, and keep the upstream copy only as provenance.
- Done when: every adopted skill has a Norse name + `.agents/skills/<name>/SKILL.md`; the reference tree is clearly marked provenance, not loaded.

**W0108 — Reference state → Norse (`assets/reference/state/`)**
- Phase: P10 · Depends: W0115 · Source: `assets/reference/state/`, user directive 2026-09-11
- Scope: the upstream `state/` samples define wake-queue, watch-lock, meta, and heartbeat conventions. Rewrite them into the Brokk `state/` conventions (Sága/Gleipnir/Sýn/Nornir), document the layout, and make the reference copy provenance-only.
- Done when: Brokk's `state/` conventions are documented and match the runtime; the reference samples are not loaded.

**W0109 — Reference docs → wire in (`assets/reference/docs/`)**
- Phase: P3/P10 · Depends: W0114 · Source: `assets/reference/docs/`, user directive 2026-09-11
- Scope: the upstream docs (supervision protocols, backends, turnend-guard, trace-context, subagent-guard, …) explain how the system works. Adopt the ones that describe our runtime into `docs/` (or the Galdr assets) with Norse naming; keep the rest as reference.
- Done when: our supervision/backend/protocol docs exist in `docs/` or Galdr assets; the reference set is provenance.

**W0110 — Wire `.no-mistakes.yaml` and `.tasks.toml`**
- Phase: P10 · Depends: W0115 · Source: repo root, user directive 2026-09-11
- Scope: both files came from the upstream and name upstream paths (`fm-lint.sh`, `firstmate-coding-guidelines`, `data/backlog.md`). Wire them to the Norse runtime: point no-mistakes lint at the Brokk lint gate, point tasks.toml at `data/backlog.md` (already present), and strip upstream identity.
- Done when: `no-mistakes` and `tasks-axi` resolve against the repo; no upstream path remains; both are exercised by the smoke test.

**W0111 — Reconcile `assets/skills/assets/` (duplicate of the Galdr assets)**
- Phase: P3 · Depends: W0115 · Source: `assets/skills/assets/`, user directive 2026-09-11
- Scope: `assets/skills/assets/` is a byte-identical duplicate of `.agents/skills/galdr/assets/`. Make `.agents/skills/galdr/assets/` the single canonical home, remove or symlink the copy, and document which loader (if any) reads `assets/skills/`. If a published skill bundle is wanted, generate it from the canonical tree, never hand-copied.
- Done when: one canonical asset tree; no unloaded duplicate; a check fails if the trees diverge.

---

## Appendix A — Repo-local distro layout (2026-09-11)

Everything the system needs lives inside `/home/zerwiz/Ymir`:

```
distro[6]{path,holds,loaded_by}:
  ".agents/agents/","agent definitions (brokk, galdr, Eindri)","per-tool loader (W0115)"
  ".agents/skills/","skills (`galdr`, `tyr-check`)","opencode skills.paths + Galdr router"
  ".agents/backend/","fleet backend scripts (ported from firstmate)","runtime scripts (W0101)"
  ".pi/extensions/","Pi extensions (syn, gna, ro, skuld, rodd, vordr)","Pi auto-load"
  ".opencode/plugins/","OpenCode plugins (saga, syn, rodd)","OpenCode auto-load"
  "bin/","Norse runtime CLI (saga/syn/rodd/gleipnir/nornir/einherjar)","AGENTS.md seating"
```

Global dirs (`~/.pi/agent/agents/`, `~/.config/opencode/agent/`) hold the *user's*
agents and are not the source of truth for Ymir; per-tool loaders point into the
repo instead. Galdr is dual-surface: agent (`.agents/agents/galdr.md`) and skill
(`.agents/skills/galdr/SKILL.md`).

### Inherited material brought into the repo (actions pending)

```
inherited[9]{path,holds,action}:
  ".agents/config/","firstmate config (calm, crew-dispatch.json, startup-memory-budget)","adapt + read repo-local (W0104)"
  ".agents/tests/","firstmate test suite (fm-*.test.sh)","adapt + add smoke test (W0105)"
  "assets/data/","data pipelines + planning/knowledge material","reuse for Mimirsbrunn (W0106)"
  "assets/reference/skills/","upstream internal skill library","convert to Norse skills (W0107)"
  "assets/reference/state/","upstream state samples (wake-queue, watch-lock, meta)","rewrite as Brokk state (W0108)"
  "assets/reference/docs/","upstream docs/protocols (supervision, backends, guards)","wire in / adopt (W0109)"
  ".no-mistakes.yaml",".no-mistakes gate overrides (upstream paths)","wire to the Brokk lint gate (W0110)"
  ".tasks.toml","tasks-axi backend config (points at data/backlog.md)","wire + exercise (W0110)"
  "assets/skills/assets/","**byte-identical duplicate** of `.agents/skills/galdr/assets/`","reconcile to one canonical tree (W0111)"
```

**Answer on `assets/skills/assets/`:** it is an exact copy of the Galdr asset tree
(`diff -rq` is empty). Nothing loads it. Canonical is
`.agents/skills/galdr/assets/`; the copy is to be removed or symlinked (W0111).

**W0098 — Hlidskjalf identity: Ymir Mark + OG + per-page metadata**
- Phase: P7 · Depends: W0026 · Source: user directive 2026-09-11, `assets/Gemini_Generated_Image_*`
- Scope: canonical Ymir Mark SVG (`midgard/design-system/ymir-mark.svg`), served copy + favicon/apple-touch/mask-icon, login + rail branding, 1200×630 Open Graph image (`public/og.png`) forged from the Gemini references (3D brushed-steel Y-rune on hammered steel), per-gate metadata (title, description, OG/Twitter tags) + base head tags.
- Done when: every gate sets its own title/description/OG tags; favicon + OG render; no console errors.
- Status: ADDED. + notes:
  - 2026-09-11 WORKING — mark SVG saved + used on login/rail/favicon; `og.svg` → `og.png` (1200×630); `src/data/metadata.ts` applies per-gate title/description/OG/Twitter via `Shell`. Verified headless: correct tags, assets 200, 0 console errors.

**W0099 — Personalization & Profile (personal + company settings)**
- Phase: P7 · Depends: W0026 W0028 · Source: user directive 2026-09-11
- Scope: per-user accent palette (presets + custom hex, persisted) ✓; per-tenant colour customisation so a tenant's swatch/tint reflects the operator's chosen colour (the "tenant colours don't change" fix); a Profile gate with **Personal** settings (accent, density, identity) and **Company** settings (org name, house seal, member/role list, per-tenant colours).
- Done when: a user can recolour each tenant and their own seat; profile persists per login; company page shows WayOf members (zerwiz owner, craig member).
- Status: ADDED. + notes:
  - 2026-09-11 WORKING — accent picker (14 presets + custom) persisted and applied globally; account menu lists tenant grants + sign out. **LEFT:** per-tenant colour overrides and the Profile gate (personal + company) themselves.
  - 2026-09-11 WORKING — **LEFT now closed:** per-tenant colour overrides persist (`ymir.tenant-colors`) and repaint the tenant swatch + realm tint when accent = "Realm default"; Profile gate ships Personal (identity, accent, custom hex, density) and Company (name, house seal, members/roles) plus the per-tenant colour rows. Tenant model: WayOf is the company; zerwiz (owner) and craig (member/admin) belong to it; the captain also holds Zerwiz. Verified headless.

**W0100 — Skills & Eindri Forge (create/edit agents + skills, mythological naming)**
- Phase: P3/P7 · Depends: W0007 W0026 · Source: user directive 2026-09-11
- Scope: a forge UI to create/edit **Eindri** (agents) and **skills**; every Eindri carries a mythological name whose myth matches its job (e.g. smith→Sindri, skald→Bragi, sage→Huginn, judge→Tyr, forger→Brokk) — a name-suggestion engine maps capability → Norse figure → descriptor; validate-before-register per Gungnir; publish Agent Card (A2A) on save.
- Done when: an operator can create an Eindri with a suggested mythic name + skills, edit it, and see it in the Fleet; skills register in the index (mock until W0007/Gungnir lands).
- Status: ADDED. + notes:
  - 2026-09-11 WORKING — Forge gate ships Eindri + Skills tabs; `src/data/mythology.ts` maps craft→figure (28 figures) and suggests names live (verified: "marketing content seo" → **Bragi**); create/edit agents and skills, aett suggestion, validate-in-Utgard toggle; saves emit a rune and appear in the Fleet. **LEFT:** real Utgard validation and Agent Card JWS (W0007/W0008).

**W0112 — Local run scripts + draggable stream**
- Phase: P7/P10 · Depends: W0026 · Source: user directive 2026-09-11
- Scope: `scripts/start.sh` (install if needed, `setsid npm run dev`, PID file under `.run/`, port wait) and `scripts/stop.sh` (process-group TERM, port fallback via lsof/fuser) for raising/lowering Hlidskjalf without a manual shell; plus a draggable bottom stream — drag the handle up/down (or ArrowUp/Down, Home/double-click to reset) to trade stage height for stream height, persisted to `ymir.stream-height`.
- Done when: `scripts/start.sh` raises the SPA and `scripts/stop.sh` lowers it; the stream resizes by pointer and keyboard and remembers its height.
- Status: ADDED. + notes:
  - 2026-09-11 WORKING — start/stop verified (`raised → 200`, `stopped → 000`). Stream handle (`role=separator`) drags (192→317→293), arrows step ±24, double-click resets, height persists across reload. Acting orders W0098–W0100 + W0112.

---


## 4. Supersession register (when an order is replaced)
- Phase: P10 · Depends: none · Source: `kunchenguid/axi` `.github/workflows/` (fetched 2026-09-11)
- Scope: adopt AXI's five workflow patterns under Norse names — `ymir-sdk-ci`, `ymir-release-please`, `ymir-docs-check`, `ymir-guard-generated-files`; guard generated docs against drift; protect release-please-managed files.
- Done when: the four ymir-* workflows run clean on push/PR; generated docs fail the build on drift instead of silently diverging.
- Status: ADDED. + notes:

**W0027 — Norse-named Skill family (Gungnir naming law)**
- Phase: P3 · Depends: none · Source: user directive 2026-09-11, AGENTS.md naming table
- Scope: every skill gets a myth figure whose role matches its work — `tyr-check` (the judge, validates Galdr compliance), `brokk-craft` (the forger, crafts new skills). Keep `galdr` as the core AXI incantation skill.
- Done when: skill README index lists Norse names; new skills synthesized by Gungnir inherit a myth name at creation.
- Status: ADDED. + notes:

**W0028 — Eindri spawn/monitor/merge CI (Yggdrasil + Valhalla)**
- Phase: P1/P10 · Depends: W0001 W0002 · Source: user directive 2026-09-11, Structure.md
- Scope: `.github/workflows/eindri-{spawn,monitor,merge}.yml` — dispatch creates a Yggdrasil worktree for an OpenCode-targeted Eindri worker, Valhalla monitors progress, Glitnir gates the merge human-approved; merge never forces.
- Done when: `opencode` can target `.yggdrasil/<branch>/` for an Eindri role, and the three workflow_dispatch jobs behave.
- Status: ADDED. + notes:

---

## 4. Supersession register (when an order is replaced)

*(none yet — appended as needed)*

---

## 5. The Log

- 2026-09-11 — `ADDED` this plan (W0001–W0025) from Architecture build order P0–P11, plans 21–25, and ENTRY-001→012.
- 2026-09-11 — `ADDED` W0026–W0032 (plan 28, Hlidskjalf Rise): frontend SPA, backend API, GitHub login, workspace provisioning, Hermes worker runtime, PI primary boot, Skrymir Vue app. Reference UI = `assets/reference/index.html`.
- 2026-09-11 — `ADDED` W0033–W0038 (gap audit, plan 28 §8 vs `assets/Yimir.md`): toolchain registry, app-fleet/process controller, zero-trust GitHub deploy, omnichannel gateway, Hlidskjalf Mobile (Expo), workspace RAG. Scope notes appended to W0008 (inter-agent audit→Runes) and W0030 (Hermes persona/config/tenant loader).
- 2026-09-11 — `ADDED` W0026, W0027, W0028: AXI workflow port, Norse skill naming law, Eindri CI. Acting order: W0026 W0027 W0028. Reference: `kunchenguid/axi/.github/workflows/` fetch, user directives 2026-09-11.
- 2026-09-11 — `ADDED` W0075–W0085 (gap audit, plan 28 §9 vs smidja `apps/visualizer`): smidja run-store/trace ingest, run control (stop/pause/resume/steer/archive), roster+model catalog & session launch, decisions/stats APIs, settings store; frontend Sessions list, Session Trace, Phase Detail, Decisions, Stats, Settings + OmniChat smidja upgrade. Reference: smidja `references/observability.md`, `shared/types.ts`, `apps/visualizer`.
- 2026-09-11 — `ADDED` W0051–W0055: realm AGENTS.md unification, galdr internal registry, PI/firstmate integration, Brokk operational manual, galdr-crafter cleanup. Acting order: W0051 W0052 W0053 W0054 W0055. Reference: user directives 2026-09-11; single source of truth at root AGENTS.md.
- 2026-09-11 — `ADDED` W0086–W0097 (plan 21–27 audit): full Command/Firstmate observer (W0086) + external-systems view (W0088) with W0012 scope note; Houses & entities registry view (W0087); cron completion — memory housekeeping + history API + status page (W0089/W0090, W0063 dedupe note); Hermóðr composition — `hermod-bridge` skill + `hermod_context` schema (W0091), Mimirsbrunn/Runes hermod paths (W0092), fleet indicators (W0093); cross-realm grants + A2A state mapping + W3C trace propagation (W0094); four-layer plan/execution gates (W0095); context-budget enforcement + visibility (W0096/W0097). Reference: `docs/plans/21-company-houses.md`, `22-hlidskjalf-portal.md`, `23-ymir-command-observer.md`, `24-cron-schedule.md`, `25-ratatoskr-a2a.md`, `26-a2a-planning.md`, `26-firstmate-four-layer.md`, `27-hermod-mcp-a2a-composition.md`, `27-firstmate-context-budget.md`.
- 2026-09-11 — `ADDED` W0113–W0115, W0101–W0103 + Appendix A (user directive): repo-local distro layout + per-tool loaders (agents/skills/extensions/backend all under `/home/zerwiz/Ymir` + `.agents`); Galdr dual-surface (agent + skill); port firstmate `.pi/extensions` to Norse (Ró calm + Skuld supervision branch + re-port Sýn/Gná with those hooks); port `.agents/backend/` firstmate `bin/` to the Brokk Norse backend; expand the Eindri roster and make it loadable by OpenCode + Pi; Pi boot auto-start of the Nornir cron. Acting orders: W0113–W0115, W0101–W0103.
- 2026-09-11 — `ADDED` W0104–W0111 (user directive): adapt `.agents/config/` (W0104), adapt `.agents/tests/` + add repo smoke test (W0105), reuse `assets/data/` for Mimirsbrunn (W0106), convert `assets/reference/skills/` to Norse skills (W0107), rewrite `assets/reference/state/` as Brokk state (W0108), wire `assets/reference/docs/` in (W0109), wire `.no-mistakes.yaml` + `.tasks.toml` (W0110), reconcile the duplicate `assets/skills/assets/` to the canonical `.agents/skills/galdr/assets/` (W0111). Appendix A extended with the inherited-material table; `assets/skills/assets` confirmed byte-identical (duplicate).
- 2026-09-11 — `WORKING` W0113–W0115, W0102–W0105, W0110: Galdr dual-surface (agent is a symlink to the skill); repo-local loaders (`bin/valknut-load.sh` → OpenCode `.opencode/agent/`, Pi `.pi/agents/`); Norse `.pi/extensions` (Ró `ro.ts`+libs, Skuld `skuld-branch-supervision.ts`+libs, full Sýn/Gná re-port; all `fm-*` removed); expanded Eindri roster (mimir/forseti/snotra/kvasir) + OpenCode subagents + Pi links; `.agents/config/` consolidation with `config` symlink; `.agents/tests/smoke.test.sh`; `bin/brokk-lint.sh` + `.no-mistakes.yaml` wired. Verified: compliance 8/8 PASS, lint 4/4, smoke 8/8. Remaining: W0101 backend port, W0106–W0109 asset reuse.
- 2026-09-11 — `WORKING` W0101, W0106–W0109: backend port — the runtime's `bin/` closure is Norse (`brokk-lease*`, `brokk-wake*`, `skuld-branch-*`, `brokk-classify-lib`, plus the existing saga/syn/nornir/einherjar); the full fleet-control plane (send/control/pr/teardown) is deferred and the Skuld prompt now references only installed commands. `bin/mimir-ingest.sh` drank `assets/data/` into the well (367 episodes, idempotent). `assets/reference-adoption.md` records the state conventions (W0108), the docs adoption map (W0109), and the skill→Norse map (W0107, conversion pending). Verified: compliance 8/8 (45 blocks), smoke 8/8, lint 4/4.
- 2026-09-11 — `FIX` Pi 401: Pi's `opencode-go` provider points at a local OpenAI-compatible bridge (`:4603`) that was not running, so Pi fell back to anthropic and returned `401 invalid x-api-key`. Vendored the bridge to `.agents/backend/opencode-go-bridge.py`; added `bin/bifrost-bridge.sh` (Bifrost — start/stop/status, idempotent) and wired it into `bin/saga-session-start.sh` so the model bridge auto-starts on boot; key from `.env.local`; Pi default set to `opencode-go/deepseek-v4-flash` (global `~/.pi/agent/settings.json` + repo `.pi/settings.json`). Verified: bridge up, four models served, session start reports `model bridge: up`, compliance + smoke green.
- 2026-09-11 — `WORKING` Hlidskjalf live wiring: built the gate API (`apps/hlidskjalf/server`, Bun :3889) reading the runtime (state, `.agents/config`, runes, well, agents, masterplan, status scripts); added live/demo modes with an **Enter demo mode** button; wired Fleet/Tasks/Well/Runes/Processes/Reviews/Files to real data and added **Runtime** (Sága digest) + **Cron** (Nornir) gates; built the one non-wireable surface — **OmniChat** (`POST /api/chat` + `/api/chat/history` via the first reachable OpenAI-compatible backend, local llama-server then Bifrost, recalling from the well, persisting to `state/chat.jsonl`); `scripts/start.sh` now raises the API + SPA and `stop.sh` lowers both. Verified: build green; endpoints live (agents 9, tasks/orders 117, well 60, runes, cron running 4 jobs, checks 8, loaders 4); Kaia replied live grounded in the well.
- 2026-09-11 — `WORKING` W0107: adopted the mapped upstream reference skills into 16 Norse skills under `.agents/skills/` (`hvild-afk`, `saga-bearings`, `saga-recap`, `muninn-stow`, `jord-projects`, `urdh-decisions`, `urdh-hold`, `frigg-consent`, `vor-diagnostics`, `nornir-events`, `nornir-quota`, `gjallarhorn-relay`, `eindri-homes`, `syn-recovery`, `ymir-update`, `hamr`) and registered them in `.agents/skills/README.md`; `reference-adoption.md` `skill_map` updated to adopted/folded/reference-only. Verified: compliance 8/8, smoke 8/8.
- 2026-09-11 — `WORKING` README + assets + W0015: rewrote `README.md` as the GitHub front door (banner `assets/ymir-banner-03.png`, lore, system map, all 20 skills, the Eindri roster, the runtime/session-start, the Hlidskjalf control plane, quick start, stack, structure) in human Markdown — no raw TOON. Renamed all Gemini-named art (`assets/ymir-banner-01..06.png`, `ymir-emblem-*.svg`, `ymir-mark-algiz-anvil.svg`, `ymir-stave.svg`). W0015 glyph set landed (`midgard/design-system/icons/` 21 runes + `icons.md`), TOON-check PASS.
- 2026-09-11 — `WORKING` W0001: built `bin/yggdrasil.sh` — the worktree manager (`create`/`list`/`status`/`merge`/`cleanup`, zero-collision, refuses unlanded merges and teardown without `--force`). Verified end-to-end on a scratch repo. Acting orders: W0015, W0001.
- 2026-09-11 — `WORKING` W0002: built `bin/utgard.sh` — the sealed execution barrier (`build`/`status`/`run`; network-none, cpus/mem caps, read-only rootfs, no-new-privileges, host-uid, worktree-only mount, timeout). Verified sealed: network blocked, no host root, timeout kills (exit 124). Lore refreshed to current names (`tyr-check`, `brokk-craft`, `Allfather`, `Yggdrasil`). Compliance 8/8, smoke 8/8. Acting orders: W0002.
- 2026-09-11 — `WORKING` W0003/W0004/W0006/W0021/W0022/W0025: built `bin/brokk` (status/agent/recall/observe/timeline/runes), `bin/mimir.sh` (the well: health/recall/observe/timeline, bridge `:4602` with local fallback), pre-dispatch recall in `einherjar-spawn.sh` (`context.md` + composed `prompt.md`), the 20 reference plan docs (`docs/plans/01–20`), the company-house entity model (template + 11 cards), and the realm-onboarding runbook. Acting orders: W0003, W0004, W0006, W0021, W0022, W0025.
- 2026-09-11 — `WORKING` Hlidskjalf de-mock: the Fleet graph now lays out the **real** agents (Brokk hub, edges = delegation) instead of the hardcoded `kaia/eindri-*` mock nodes; removed fake sparklines from every gate; Well/Runes/Cron/Processes tiles now compute from live data (`recall.length`, checksum head, statuses); Forge default model set to `opencode-go/deepseek-v4-flash`. Build green; live API confirmed via the SPA proxy (9 agents).
- 2026-09-11 — `WORKING` W0020: `workspace/config/toolchain.md` — 16 engines mapped to Norse wrappers + auth env, with an auth-status table (exact check command per engine). TOON-check PASS. Compliance 8/8, smoke 8/8.
- 2026-09-11 — `WORKING` W0034 + stack orchestration: built `bin/valhalla.sh` (list/status/restart/stop/start/logs over PM2/Docker/systemd) and wired it into the gate API `/api/processes` (Processes gate shows 25 real daemons); `scripts/start.sh` / `stop.sh` now raise/lower the whole stack (gate API + SPA + Nornir cron + Bifrost bridge). Verified stop→start cycle; compliance 8/8, smoke 8/8.
- 2026-09-11 — `WORKING` the remaining backend/ingress batch: **W0017** `midgard/infrastructure/ingress/{Caddyfile,oauth2-proxy.cfg,cloudflared.yml}` + `bin/bifrost-ingress.sh` (start/stop/status/validate); **W0018** `bin/mjollnir.sh` (issue→brief→Eindri→PR) + `bin/mjollnir-webhook.sh` (HMAC-256 verified; forged refused); **W0033** `bin/toolchain.sh` (list/status/run over 11 provider CLIs); **W0035** `.github/workflows/deploy-{staging,production}.yml` + `bin/github-deploy.sh` (secret sync + dispatch + status); **W0036** `bin/gjallarhorn-notify.sh` + `bin/telegram-bot.sh` (allowlisted commands); **W0037** `apps/hlidskjalf-mobile/` Expo scaffold consuming the gate API; **W0038** `bin/workspace-rag.sh` (index/query/entities/graph over the realm workspaces); **W0040** `midgard/infrastructure/db/schema.sql` (Postgres 16 + RLS) + `bin/wyrd-db.sh` (apply/status/psql); **W0075** `bin/factory-observe.sh` (read-only factory.db sessions/stats/decisions; honest ABSENT) + gate API `/api/factory`. **W0024** remains BLOCKED BY DESIGN. Verified syntax + live endpoints (factory absent reported honestly).
- 2026-09-11 — `WORKING` W0026 / W0028 (mock) / W0032 (placeholder): Hlidskjalf SPA raised at `apps/hlidskjalf` (React 19 + Vite) — shell, all eight gates, components, pausable stream, hash routes, mock stream; mock GitHub sign-in + first-run provisioner + tenant grants; per-user accent palette. Typecheck + build green; headless render 0 console errors. Notes appended to W0026, W0028, W0032.
- 2026-09-11 — `ADDED` W0098–W0100: Hlidskjalf identity (Ymir Mark SVG, favicon, OG image, per-page metadata); Personalization & Profile (per-tenant colours + personal/company settings); Skills & Eindri Forge (create/edit agents + skills with mythological naming). Acting order: W0098 W0099 W0100. Reference: user directives 2026-09-11, `assets/Gemini_Generated_Image_236pb9236pb19236p.png`, `assets/Gemini_Generated_Image_t6431it6431it6431.png`.
- 2026-09-11 — `WORKING` W0098–W0100 + `ADDED` W0112 (user directive): **W0099 closed** — per-tenant colour overrides (persisted, repaint swatch + realm tint on "Realm default"), Profile gate (Personal + Company), tenant model WayOf=company with zerwiz/craig members. **W0100 closed (mock)** — Forge gate + `data/mythology.ts` name engine (craft→figure; verified marketing→Bragi); real Utgard validation/JWS deferred to W0007/W0008. **Interaction pass** — global modal+toast (`state/ui.ts`, `Overlay.tsx`); every dead button wired (PR seal/request-changes/diff, process restart/logs, file upload, runes export, agent inspect, well recall). **W0112** — `scripts/start.sh`/`stop.sh` (verified raise/lower) + draggable stream (drag/arrows/reset, persisted). Hlidskjalf UI working guide appended to `.agents/skills/galdr/SKILL.md` §15. Typecheck + build green; headless suites 19/19 PASS, 0 console errors.
- 2026-09-11 — `DONE` full `factory` → **Smíðja** sweep (follow-up to ENTRY-016): renamed the adopted engine's paths, identifiers, config, env, routes, and prose across 158 files while preserving `default_factory`, proper repo names (`wayoffactory`/`softwerefactory`), and all immutable ledgers/history. `py_compile` + `bash -n` + Hlidskjalf `tsc`/build green. Reference: `docs/append-only-log.md` ENTRY-017.
- 2026-09-11 — `WORKING` repo-local Smiðja wiring (W0075/W0078/W0080/W0081/W0083/W0084, partial): deleted the external reader `bin/factory-observe.sh` (defaulted to `~/command/factory/factory_data/factory.db`) and built `bin/smidja-observe.sh` against the repo's own `smidja/smidja_data/smidja.db` (read-only, WAL, honest absent); replaced the gate API's `/api/factory` with `/api/smidja/{health,sessions,sessions/:id,decisions,stats}` via `bun:sqlite`; added four Hlidskjalf gates — **Sessions** (run list), **Trace** (phases · agent context · tool calls), **Decisions** (failure buckets), **Stats** (totals · by-chain · by-model) — wired through `api.ts`/`store.ts`/`realms.ts`/`metadata.ts`/`Shell.tsx`. No `command`/`factory` references remain in the runtime or UI. Acting orders: W0075, W0078, W0080, W0081, W0083, W0084. Verified: `tsc`+`vite build` green, SPA 200, endpoints honest-absent, compliance 8/8, smoke 8/8.
- 2026-09-11 — `WORKING` Stats 1:1 + Kaia chat + Forge prompts: **W0078/W0084 stats** ported 1:1 from the Smiðja visualizer into the gate API (event-derived usage, cache-hit ratio, local-vs-online provider split + per_model, 40-model vendor catalog with cached/total/savings, by-chain, by-workflow); a real run (`smidja_prompt`, 69.6k tokens, CHR 67%) renders live. **Chat** rebuilt around Kaia: per-session JSONL store under `state/chat/` with `GET /api/chat/sessions`, `GET /api/chat/history?session=`, `DELETE /api/chat/session`, `GET /api/chat/models` (314 connected models), and `POST /api/chat {session,content,model,agents}`; a rolling **40-message** window in both server context and client thread; query-grounded well recall before every dispatch (`recalling` flag); animated "Kaia is thinking…" indicator; chat-session sidebar (new/switch/delete); a model datalist (connected + free-type); and Eindri lane toggles. **Forge** gained a Prompts mode (`GET/POST /api/prompts`) to edit `smidja/smidja_data/prompt_engineering/<agent>/{system,user}.md` (path-guarded) and a connected-model datalist for agent model. Acting orders: W0078, W0084, W0100. Verified: `tsc`+`vite build` green, live chat (local `gemma-4-12b`, recall on), prompt roundtrip + traversal guard, compliance 8/8, smoke 8/8, lint 4/4.
