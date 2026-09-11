# Plan 29 — Brokk Distro Runtime (upstream distro function adoption)

- **Status:** proposed · **Realm:** platform · **Owner:** Brokk
- **Source:** `/home/zerwiz/upstream distro` (the distro pattern), `AGENTS.md` (YSOS mandate),
  plan 23 (observer), plan 24 (cron), `docs/masterplan.md` W0031/W0053/W0073 (PI primary),
  W0006 (context injection), W0011/W0063/W0089 (cron), W0086–W0097 (runtime surfaces).
- **Directive:** Give Ymir the *same function* the upstream distro gives its Allfather — a primary
  agent that **ascends Hlidskjalf** the moment a harness opens in the repo, **gets context
  injected before its first turn**, and **starts the fleet's background jobs** — so Ymir's
  agents take the role of **Brokk** exactly the way a upstream distro harness takes the role of
  the Allfather's primary agent.

---

## 0. The Sequencing Law (read first)

> **Frontend completes before backend. No platform backend order starts until the
> frontend gate (§4) is green.**

- **Phase 0** is the only work allowed before the frontend gate: it is *identity and
  high-seat contract* (text + one config entry), not platform backend.
- **Phase 1 — Frontend** (Hlidskjalf runtime surfaces) must land first.
- **Phase 2 — Backend** carries everything else, including the **Brokk distro runtime**
  itself (session-start digest, context injection, harness adapters, cron startup,
  spawn/supervise). The Brokk runtime is backend and waits for the gate.

This mirrors plan 28's hard chain (`A → B → C`) and extends it: **Frontend → Backend →
Brokk Runtime lives inside the backend.**

---

## 1. The Reference — what the upstream distro actually does

upstream distro is not a model, harness, or CLI — it is an **agent distro**: a directory of
instructions, skills, tooling, policies, and state conventions that turns a general-purpose
agent into a specialized one. Launching a supported harness inside the clone *instantiates
the primary agent and makes the user the Allfather* (`README.md:36-41`).

| upstream distro mechanism | File(s) | What it buys |
|---|---|---|
| **Role adoption on launch** | `AGENTS.md` header (`AGENTS.md:1-12`), `CLAUDE.md` pointer | "You are the primary agent. The user is the Allfather." |
| **One-command session start** | `bin/the upstream digest` (9 ordered stages) | owner, wake-queue, supervision, fleet + context digests in one block |
| **Native harness injection** | `bin/saga-sessionstart-run.sh`, `.opencode/plugins/saga-sessionstart.js`, `.pi/extensions/syn-turnend-guard.ts`, `.claude/settings.json` hooks | digest runs *before the model's first turn* (run-tier) or is nudged (nudge-tier) |
| **Home separation** | `FM_HOME` vs tracked root (`AGENTS.md:47-54`) | private `data/ state/ config/ projects/` never mixed with shared code |
| **Context sources** | `data/projects.md · operator.md · operator-shared.md · learnings.md`, `state/*.meta`, `state/*.status` (`AGENTS.md:184-186`) | the agent wakes already knowing the fleet and your preferences |
| **Harness detection + dispatch** | `bin/hamr-harness.sh`, `bin/einherjar-spawn.sh`, `config/eindri-harness`, `config/eindri-dispatch.json` | pick a harness, spawn sub-agents into isolated worktrees |
| **Supervision (no cron)** | `bin/syn-watch-arm.sh`, `docs/supervision-protocols/*.md`, `.opencode/plugins/gna-watch-arm.js` | zero-token, event-driven wake instead of polling |
| **Isolation** | upstream worktrees + isolated homes | parallel work never collides |

Ymir already owns the labels (`AGENTS.md`: Brokk = primary, Eindri = sub-agents, Ymir =
platform). What is missing is the **runtime function**: no `.opencode`/`.pi` hooks, no
`data/ state/ config/` home, no session-start digest, no cron-at-boot. This plan builds them.

---

## 2. Target architecture

```
        Allfather (the operator)
              │  chat: orders, decisions, "merge it"
              ▼
┌──────────────────────────────────────────────────────────────┐
│ BROKK HOME  (BROKK_HOME = repo root, or svartalfaheim/<realm>/)│
│  tracked: AGENTS.md · opencode.json · .agents/ · bin/         │
│  private: data/ · state/ · config/ · projects/  (gitignored)  │
│                                                               │
│  harness opens ─► bin/saga-session-start.sh                  │
│       1 lock  2 bootstrap  3 wake-queue  4 supervision        │
│       5 fleet digest  6 context digest  7 START CRON          │
│       8 next step  (one digest, injected before first turn)   │
└──┬───────────────────────────────┬───────────────────┬────────┘
   │ dispatch Eindri               │ observe           │ audit
   ▼                               ▼                   ▼
Yggdrasil worktree            Mimirsbrunn          Runes
+ Utgard sandbox              (:4602 well)         (append-only)
+ Valhalla supervision
   │
   ├─ Eidri ship: PR / local merge → Glitnir human gate
   └─ Eidri scout: report → decision inventory
```

**Brokk = upstream distro** (primary, read-only over projects except approved operations).
**Eindri = sub-agents** (one autonomous agent per task, isolated worktree/sandbox).
**Allfather = the operator** (talks only to Brokk; Eindri never address the Allfather).

---

## 3. Home layout (mirror upstream distro, mapped to Ymir)

| upstream distro | Ymir / Brokk | Notes |
|---|---|---|
| `FM_HOME` | `BROKK_HOME` | repo root (platform) or `svartalfaheim/<realm>/` (realm home) |
| `data/backlog.md` | `data/backlog.md` | mirror of `docs/masterplan.md` open orders; `tasks-cli` is the backend |
| `data/operator.md` | `data/operator.md` | operator preferences/working style (inspect-then-update) |
| `data/projects.md` | `data/projects.md` | realm/project registry (plan 21 houses) |
| `data/learnings.md` | `data/learnings.md` | curated fleet gotchas |
| `state/<id>.status` | `state/<id>.status` | A2A/Eindri wake-event lines |
| `state/<id>.meta` | `state/<id>.meta` | task metadata (backend, worktree, harness) |
| `config/crew-harness` | `config/eindri-harness` | override harness for spawned Eindri |
| `config/crew-dispatch.json` | `config/eindri-dispatch.json` | per-task harness/model/effort profiles |
| `projects/` | `svartalfaheim/<realm>/projects/` | realm-scoped clones (read-only to Brokk) |
| `.claude/skills` symlink | `.agents/skills` | already present; one skill source |

All private paths are gitignored, exactly as upstream distro keeps `data/ state/ config/ projects/`
private (`AGENTS.md:43`).

---

## 4. Phase 1 — FRONTEND (do this first; gate for backend)

**Gate:** every runtime view renders against the scaffolded client with no console errors
and `MOCK` toggles cleanly to the live transport; typecheck + build green.

| # | Task | Delivers |
|---|---|---|
| F-1 | **Runtime digest view** — render the session-start digest (fleet, wake-queue, context, cron) read-only in Hlidskjalf | operator can see what Brokk was injected |
| F-2 | **Cron status page** (W0090) | job last/next/status/pause |
| F-3 | **Sessions list + Session Trace + Phase Detail** (W0080–W0082) | smidja-run observability |
| F-4 | **Decisions + Stats + Settings views** (W0083–W0085) | self-improving + config surfaces |
| F-5 | **External systems + Houses & Entities views** (W0087–W0088) | command/upstream distro + companies |
| F-6 | **Context editors** — operator.md / learning / project registry read+edit with masked secrets | the operator can shape what gets injected |
| F-7 | Gate review: a11y pass, deep-links, `#/runtime` `#/cron`, no mock leaks | **frontend gate green** |

*Dependency:* all Phase 2 work depends on F-1…F-7. Frontend consumes the gate API
surface; until it is raised it uses the mock store, exactly like the current
`apps/hlidskjalf` build.

---

## 5. Phase 2 — BACKEND (after the frontend gate)

### 5A. Brokk distro runtime (the upstream distro function)

| # | Task | Delivers |
|---|---|---|
| B-0 | **Phase 0 identity** — `AGENTS.md` header "You are Brokk. The operator is the Allfather."; `opencode.json` primary agent `brokk`; a ascend-Hlidskjalf contract that the digest runs before the first turn | role adoption |
| B-1 | **`BROKK_HOME` + home layout** — gitignored `data/ state/ config/`; realm homes under `svartalfaheim/<realm>/`; `.env.realm` load | private state separation |
| B-2 | **`bin/saga-session-start.sh`** — one ordered digest: lock → bootstrap → wake-queue → supervision instructions → fleet digest → context digest → **cron start** → next step. Composes existing scripts; never re-implements them (the upstream digest contract) | the high seat is taken in one block |
| B-3 | **Harness adapters** — `.opencode/plugins/saga-sessionstart.js` + `.pi/extensions/syn-turnend-guard.ts` + `.claude/settings.json` SessionStart hook + codex/grok/cursor equivalents, each run-or-nudge per `saga-sessionstart-*` | digest injected before the first turn |
| B-4 | **Harness detection** — `bin/hamr-harness.sh` (Norse: Hamr): claude/codex/opencode/pi/grok/kimi/cursor | correct adapter + flags per harness |
| B-5 | **Context injection sources** — `data/operator.md`, `data/projects.md`, `data/learnings.md`, `data/realm.md`, `data/backlog.md` (from masterplan), `state/*.meta`, `state/*.status`; `ABSENT` markers are meaningful | Brokk wakes knowing the fleet |
| B-6 | **Cron startup** — `bin/nornir-cron-start.sh` ensures the cron spine is running (idempotent) at every session start; jobs from `config/cron.yaml` (07:00 briefing, git sync, observer, social, memory housekeeping per W0011/W0063/W0089) under Valhalla/PM2; dead-man alert | **cron jobs start with the high seat** |
| B-7 | **Supervision** — `bin/syn-watch-arm.sh` + per-harness protocols in a new `docs/supervision-protocols/`; zero-token event-driven wake (Brokk's own), cron stays for scheduled jobs | no polling, no babysitting |
| B-8 | **Spawn + supervise Eindri** — `bin/einherjar-spawn.sh` (Norse: Einherjar) over Yggdrasil worktrees + Utgard sandboxes + Valhalla supervision; brief scaffold `bin/erindi-brief.sh`; dispatch profiles `config/eindri-dispatch.json` | sub-agents launch isolated and supervised |
| B-9 | **Supervision branch** — Pi supervision branch for routine wakes (W0073/W0053) | cheap background handling |

### 5B. Platform APIs the runtime reads/writes

| # | Task | Delivers |
|---|---|---|
| B-10 | Gate API (W0027): `/api/me|workspace|agents|tasks|well|runes|processes|reviews` + `/api/stream` | frontend goes live |
| B-11 | Run-store + trace ingest, run control, rosters/models, decisions/stats (W0075–W0079) | smidja observability backend |
| B-12 | Observer, Houses/Entities, external-systems, Hermóðr, cross-realm grants, four-layer gates, context budget (W0086–W0097) | the plan-21–27 backlog |

---

## 6. The session-start digest contract (the core deliverable)

`bin/saga-session-start.sh` prints **one ordered digest** and does nothing else. Stages,
mirroring `the upstream digest` plus Ymir's cron:

1. **LOCK** — acquire the per-home session lock first; a refused lock = read-only mode
   (no spawn, steer, merge, drain, or repair).
2. **BOOTSTRAP** — detect-only: tool floors, `.env.realm`, harness override, dispatch
   profile, backend; consent-gated installs; silent when healthy.
3. **WAKE QUEUE** — drain Ratatoskr A2A inbox wakes + Glitnir approval gates; print raw
   records; keep durable until acknowledged; print bounded `OPEN DECISIONS`.
4. **SUPERVISION INSTRUCTIONS** — exactly one operating block for the detected harness.
5. **FLEET DIGEST** — Eindri tasks from `data/backlog.md` + every `state/*.meta` + bounded
   `state/*.status` tail + `state/.afk` + endpoint liveness.
6. **NETWORK CHECKS** — deferred, off the blocking path (GitHub auth, tunnel, remotes).
7. **CONTEXT DIGEST** — `data/realm.md`, `data/projects.md`, `data/operator.md`,
   `data/learnings.md`, open masterplan orders — each delimited, `ABSENT` explicit.
8. **CRON START** — `bin/nornir-cron-start.sh` ensures the scheduled jobs are running;
   prints job/next-fire or the exact reason it could not start. *(Ymir extension — upstream distro
   uses a watcher only; Ymir adds the scheduled spine.)*
9. **NEXT STEP** — closing pointer back to the supervision block and the read-once contract.

**Read-once:** the digest is this turn's startup + recovery input. Do not re-read the
context/backlog/status it just printed unless a source was reported absent or corrupt.

---

## 7. Harness adapter matrix

| Harness | Surface | Mechanism |
|---|---|---|
| OpenCode | `.opencode/plugins/saga-sessionstart.js`, `syn-watch-arm.js`, `syn-turnend-guard.js` | `session.created` → run digest; `session.idle` → watch-arm; turn-end guard |
| Pi | `.pi/extensions/syn-turnend-guard.ts`, `gna-pi-watch.ts` | native session-open run (digest injected pre-turn); watcher continuity |
| Claude Code | `.claude/settings.json` `SessionStart` + `Stop` hooks | run-tier; turn-end re-arm |
| Grok | not yet implemented | — |
| Codex | `.codex/hooks.json` `SessionStart` + `PreToolUse` + `Stop` (`[features].hooks=true`) | run-tier |
| Cursor | `.cursor/hooks.json` `sessionStart` + `stop` + `preToolUse` | run-tier |

Dispatch is **fail-closed**: never launch on an unverified adapter; a missing dependency or
auth failure is a blocker, never a silent fallback. `bin/einherjar-spawn.sh` owns launch flags
and validation (Norse: Einherjar).

---

## 8. Acceptance criteria

1. Launching a verified harness in `BROKK_HOME` makes the agent respond **as Brokk** and
   address the operator as Allfather, before any tool call.
2. The digest is injected **before the model's first turn** on a run-tier harness, and a
   nudge appears on a nudge-tier harness.
3. The digest contains all eight stages; a truncated startup names exactly which stage never ran.
4. Context sources (`operator.md`, `projects.md`, `learnings.md`, open orders, state metas)
   appear delimited, with explicit `ABSENT` markers.
5. **Cron jobs are running after session start** (07:00 briefing, git sync, observer, social,
   memory housekeeping); `bin/nornir-cron-start.sh` is idempotent and reports why if it fails.
6. A lock-refused session is read-only: no spawn, steer, merge, drain, or repair.
7. Brokk can spawn an Eindri through `bin/einherjar-spawn.sh` into a Yggdrasil worktree sealed
   by Utgard, supervise via Valhalla, and deliver a PR/local merge through Glitnir's human gate.
8. Restart is a non-event: durable `data/` + `state/` + live backend inventory are authoritative.
9. No platform backend order was started before the frontend gate (§4) went green.

---

## 9. ADD / NOT / KEEP

**ADD**
- `docs/plans/29-brokk-distro-runtime.md` — this plan.
- `bin/saga-session-start.sh`, `bin/hamr-harness.sh`, `bin/einherjar-spawn.sh`, `bin/erindi-brief.sh`, `bin/syn-watch-arm.sh`, `bin/nornir-cron-start.sh`.
- `.opencode/plugins/syn-*.js`, `.pi/extensions/syn-*.ts`, `.claude/settings.json`, `.cursor/hooks.json`.
- `data/ state/ config/` home layout + `BROKK_HOME`; `docs/supervision-protocols/`.
- Hlidskjalf runtime digest / cron status / context editor views (frontend, Phase 1).

**NOT**
- A new agent framework, queue, or scheduler — reuse upstream distro's patterns, Ratatoskr (A2A), and the cron spine (W0011/W0063/W0089).
- A second UI engine — Hlidskjalf only (plan 22).
- Writing into Ymir's own runtime tree or the upstream distro — read-only by contract (plan 23).
- Starting any platform backend before the frontend gate.

**KEEP**
- Norse naming; `AGENTS.md` as the always-loaded contract; `.agents/skills` as the single skill source.
- OSS-first: upstream distro is the validated pattern, adopted — not rebuilt.
- Append-only masterplan + Runes; human-in-the-loop for merges.
- Realm boundaries sacred; Utgard + Yggdrasil isolation by default.

---

## 10. Orders mapping

| Plan phase | Masterplan orders |
|---|---|
| Phase 0 identity | W0031, W0073 |
| Frontend (gate) | W0080–W0085, W0087, W0088, W0090; W0044–W0047 |
| Backend — Brokk runtime | W0006 (context injection), W0011/W0063/W0089 (cron), W0031/W0053/W0073 (PI primary, harness), W0012/W0086 (observer) |
| Backend — platform | W0027, W0075–W0079, W0086–W0097 |

**New orders to file (on approval):** the Sága digest + adapters; `BROKK_HOME`
layout; the Nornir cron spine; Einherjar spawn/supervision. These extend W0031/W0073 and W0011
rather than duplicating them.

---

## 11. Open questions (for the Allfather)

1. **Harness order of adoption** — OpenCode + Pi first (already in `opencode.json`/`.pi`),
   or Claude/Grok co-primary as upstream distro does? (Recommendation: OpenCode + Pi first.)
2. **`BROKK_HOME` scope** — one platform home at the repo root, or per-realm homes under
   `svartalfaheim/<realm>/`? (Recommendation: platform home now, realm homes when W0022 lands.)
3. **Cron daemon** — Valhalla/PM2 (already planned) or systemd timers? (Recommendation: Valhalla/PM2.)
4. **Watcher vs cron** — adopt upstream distro's event-driven watcher for supervision *and* keep
   cron strictly for scheduled jobs (recommended), or fold both into cron?

---

## 12. Norse naming law (runtime components)

Every runtime component is named for the figure whose role matches its work —
this is the **Norse methodology** the platform applies everywhere. Conversational
flavor may season a line, but it never names a subsystem and never leaks into
docs. The operator is the **Allfather** (Odin), addressed as such.

| Component | Norse figure | Why | File(s) |
|---|---|---|---|
| Operator | **Allfather** | the one who sees all realms from Hlidskjalf | (address) |
| Primary agent | **Brokk** | the smith who keeps the forge hot | `AGENTS.md`, `opencode.json`, `.agents/agents/brokk.md` |
| Sub-agent worker | **Eindri** | "the one who runs the errand" | `.agents/subagents/*` |
| Session-start digest | **Sága** | the seeress who sees all that happens | `bin/saga-session-start.sh`, `bin/saga-sessionstart-run.sh` |
| Watch / supervision | **Sýn** | watchful sight; guards the turn boundary | `bin/syn-watch-arm.sh`, `bin/syn-turnend-guard.sh`, `.pi/extensions/syn-turnend-guard.ts` |
| Watch wake messenger | **Gná** | Frigg's rider who carries word | `.pi/extensions/gna-pi-watch.ts` |
| Digest process supervisor | **Vörðr** | the warden who holds the child | `.pi/extensions/lib/vordr-sessionstart-supervisor.mjs` |
| Operational wire | **Rödd** | the voice between Allfather, Brokk, and Eindri | `bin/rodd-operational-input.sh`, `.pi/extensions/lib/rodd-operational-input.ts` |
| Session lock | **Gleipnir** | the chain that binds one session | `bin/gleipnir-lock-lib.sh` |
| Harness detection | **Hamr** | the shape a being wears | `bin/hamr-harness.sh` |
| Worker spawn | **Einherjar** | the chosen who are gathered to fight | `bin/einherjar-spawn.sh` |
| Worker brief | **Erindi** | the errand given to a worker | `bin/erindi-brief.sh` |
| Worker-state reconciliation | **Vör** | awareness of what is | `bin/vor-crew-state.sh` |
| Scheduled jobs | **Nornir** | the fates who govern time | `bin/nornir-cron-start.sh`, `bin/nornir-job-*.sh` |
| Daily briefing | **Sága** | the daily seeing | `bin/nornir-job-daily-briefing.sh` |
| Memory housekeeping | **Muninn** | the raven of memory | `bin/nornir-job-memory-housekeeping.sh` |
| Command/firstmate observation | **Huginn** | the raven of thought/observation | `bin/nornir-job-observer.sh` |
| Git sync | **Yggdrasil** | the world-tree kept in order | `bin/nornir-job-git-sync.sh` |
| Audit ledger | **Runes** | the carved record | `bin/runes-append.sh`, `workspace/memory/runes_audit.md` |

## 13. Port status (2026-09-11)

**Landed and smoke-tested (Pi surface):**

- `.pi/extensions/syn-turnend-guard.ts` — injects the Sága digest before the first
  turn, re-emits on compaction, refuses a blind turn end.
- `.pi/extensions/gna-pi-watch.ts` — watcher continuity (calm + supervision branch
  intentionally dropped).
- `.pi/extensions/lib/vordr-sessionstart-supervisor.mjs` — digest child supervisor.
- `.pi/extensions/lib/rodd-operational-input.ts` — Rödd wire bridge.
- `bin/rodd-operational-input.sh` — encode/kind/classify/body (verified).
- `bin/saga-session-start.sh` + `bin/saga-sessionstart-run.sh` — 8-stage digest
  (verified end-to-end).
- `bin/syn-watch-arm.sh` — arms, heartbeats, exits on `signal:` (verified).
- `bin/syn-turnend-guard.sh` — exits 2 when supervision armed and watcher stale
  (verified).
- `bin/saga-wake-drain.sh`, `bin/gleipnir-lock-lib.sh`, `bin/nornir-cron-start.sh`
  (verified status/start), `bin/syn-{arm,cd}-pretool-check.sh`.

**Landed (production, no mocks):** `bin/hamr-harness.sh`; the `.opencode` / Claude /
Codex / Cursor adapters; `bin/einherjar-spawn.sh`, `bin/erindi-brief.sh`,
`bin/vor-crew-state.sh`, `config/eindri-dispatch.json`; `bin/nornir-job-*.sh` and
`bin/runes-append.sh`; real `data/` context sources and `config/cron.yaml`; the
`AGENTS.md` Allfather header. Verified live under Pi: both `.pi` extensions loaded
(markers `state/.pi-syn-turnend-loaded` and `state/.pi-gna-watch-loaded`), the
Gleipnir lock bound to the session pid, Nornir running 4 jobs, the Sága digest
injected, and the Runes ledger chained. Grok remains unimplemented.

## 14. Production mandate

- **No mocks, no examples, no placeholders** in the shipped runtime. `data/` and
  `config/` carry real, working files.
- **Boot Pi in `BROKK_HOME` and it behaves as Brokk**: the digest is injected
  before the first turn, the Allfather is addressed as such, supervision is armed,
  and the Nornir jobs are running.
- Every script is `bash -n` clean and smoke-tested; every failure reports a plain
  reason rather than a silent fallback.

