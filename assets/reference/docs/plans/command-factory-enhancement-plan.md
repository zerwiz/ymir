# Command Factory Enhancement Plan

**Date**: September 2026  
**Scope**: Visualizer (frontend) + Factory Backend (Python)  
**Purpose**: Comprehensive roadmap for extending the software factory observability and execution capabilities

---

## Executive Summary

The Command Factory is a **Super Simple Software Factory** — deterministic Python scripts own sequencing/retries/acceptance; coding agents (Pi/opencode) work inside bounded phases; typed JSON envelopes carry context; everything streams into SQLite for the polled visualizer.

This plan identifies high-value enhancements across both surfaces, organized by impact and implementation complexity.

---

## Current Architecture Snapshot

### Visualizer (`apps/visualizer/`)
| Layer | Technology | Key Files |
|-------|------------|-----------|
| UI Framework | Vue 3 + TypeScript + Vite | `src/App.vue`, `src/components/*.vue` |
| State | Pinia-style composables | `src/lib/chat-store.ts`, `src/lib/api.ts` |
| Server | Bun HTTP + SQLite (readonly) | `server/index.ts`, `server/db.ts` |
| Real-time | 500ms polling + cursor pagination | `SessionTrace.vue` tick loop |
| Themes | CSS custom properties | `neutral` (default) + `classic` (deep-space) |
| Desktop | Electron (preload + main) | `desktop/main.js`, `desktop/preload.js` |
| Memory | Kaia engram bridge (Python) | `/api/memory/*` proxy to `:4602` |

**Current Views**: Sessions → Session Trace (lanes + waterfall) → Phase Detail + Envelopes + Gates + Thinking + Tool calls; Memory; Decisions (self-improving surface); Stats (tokens/cost/cache/savings); Orchestrator Chat (Kaia + session launch); Settings

### Factory Backend (`templates/factory/`)
| Layer | Technology | Key Files |
|-------|------------|-----------|
| Orchestration | Python 3.11+ (uv scripts) | `factory_*.py` |
| Data Contracts | Pydantic v2 | `factory_modules/data_types.py` |
| Agent Runtime | `agent_pi.py` (Pi), `agent_opencode.py` (opencode) | |
| Tracing | SQLite WAL + JSONL events | `factory_modules/tracer.py` |
| Quality Gates | Deterministic subprocess runs | `factory_modules/quality.py` |
| Permissions | Path-based write enforcement | `factory_modules/permissions.py` |
| Context Handoff | File-based `context_handoff/` dir | `factory_modules/agents.py` |
| Sub-agents | Task-tool lane materialization (G2) | `factory_modules/agents.py` |

**Current Factories**: `factory_scout`, `factory_simple_sdlc`, `factory_plan_build`, `factory_build_test`, `factory_plan_build_test`, `factory_plan_build_test_quality`, `factory_build_review`, `factory_document`, `factory_orchestrate`, `factory_recon_iv`, `factory_prompt`, `factory_quality`

---

## Enhancement Categories

### A. Visualizer — Observability & UX

#### A.1 Live Collaboration & Multi-User
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| A.1.1 | **Presence indicators** | Show other engineers viewing the same session (WebSocket presence) | Medium | High |
| A.1.2 | **Shared steer annotations** | Steer messages attributed to author, visible to all viewers | Medium | High |
| A.1.3 | **Session handoff** | "Take over" a paused run from another engineer's steer context | Medium | Medium |
| A.1.4 | **Comment threads on phases** | Pin discussion to specific phase blocks (like GitHub PR comments) | Medium | Medium |

#### A.2 Advanced Trace Analysis
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| A.2.1 | **Comparative trace diff** | Side-by-side waterfall of two runs (baseline vs current) | Large | High |
| A.2.2 | **Token flow Sankey** | Visualize input→cache→output→reasoning token flow per agent/phase | Medium | High |
| A.2.3 | **Failure pattern miner** | Auto-cluster similar failures across runs with suggested fixes | Medium | High |
| A.2.4 | **Critical path highlighter** | Auto-detect and highlight the longest dependency chain in waterfall | Small | Medium |
| A.2.5 | **Phase duration heatmap** | Calendar view of phase durations across runs (CI-style) | Small | Medium |

#### A.3 Kaia Memory & Knowledge
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| A.3.1 | **Memory graph explorer** | Interactive entity-relationship graph from engram facts/episodes | Large | Medium |
| A.3.2 | **Cross-project memory search** | Query Kaia memory across all factory repos from one UI | Medium | Medium |
| A.3.3 | **Memory decay visualization** | Show salience/confidence decay over time per fact/episode | Small | Low |
| A.3.4 | **Admission timeline** | Visualize Kaia's admission pipeline: prompt → recall → admit → dispatch | Small | Medium |

#### A.4 Orchestrator Chat Enhancements
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| A.4.1 | **Inline tool result preview** | Expand tool calls in chat to show args/result without leaving thread | Small | High |
| A.4.2 | **Chat-to-factory trace linking** | Click a launched session in chat → jump to its trace (exists) + back-link | Small | High |
| A.4.3 | **Structured task templates** | Quick-insert templates for common tasks (bug fix, feature, refactor) | Small | Medium |
| A.4.4 | **Multi-model chat** | Switch Kaia's model mid-conversation; show model badge per message | Small | Medium |
| A.4.5 | **Chat export / session resume** | Export chat + launched sessions as portable bundle; resume later | Medium | Low |

#### A.5 Settings & Configuration UI
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| A.5.1 | **Visual roster editor** | Drag-and-drop agent roster builder (replaces YAML editing) | Large | High |
| A.5.2 | **Model tier picker** | Visual model catalog with tier badges, pricing, local/online toggle | Medium | High |
| A.5.3 | **Factory chain builder** | Visual pipeline editor for creating custom factory scripts | Large | Medium |
| A.5.4 | **Theme builder** | Custom CSS variable editor with live preview + export/import | Medium | Low |

#### A.6 Mobile & Accessibility
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| A.6.1 | **Responsive waterfall** | Horizontal scroll + collapsed lanes for mobile viewport | Medium | Medium |
| A.6.2 | **Screen reader support** | ARIA labels, live regions for polling updates, keyboard nav | Medium | High |
| A.6.3 | **High contrast theme** | WCAG AAA compliant theme variant | Small | Medium |
| A.6.4 | **PWA installability** | Service worker + manifest for offline session browsing | Medium | Low |

---

### B. Visualizer — Data & API

#### B.1 API Extensions
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| B.1.1 | **WebSocket event stream** | Replace polling with server-sent events for live updates | Medium | High |
| B.1.2 | **GraphQL endpoint** | Flexible queries for custom dashboards / external tools | Large | Medium |
| B.1.3 | **Batch session export** | `/api/sessions/export?ids=...` → NDJSON/CSV/Parquet | Small | Medium |
| B.1.4 | **Run comparison API** | `/api/compare?a=<id>&b=<id>` → structured diff | Medium | High |

#### B.2 Data Enrichment
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| B.2.1 | **GitHub PR linking** | Auto-link sessions to PRs via commit messages / branch names | Medium | High |
| B.2.2 | **Jira/Linear ticket sync** | Bidirectional sync: session ↔ ticket (status, comments, links) | Large | Medium |
| B.2.3 | **Cost allocation tags** | Tag runs by project/team/feature for cost center reporting | Small | Medium |
| B.2.4 | **Custom metric ingestion** | POST `/api/metrics` for arbitrary KPI tracking (deployment freq, etc.) | Small | Low |

---

### C. Factory Backend — Execution & Orchestration

#### C.1 New Factory Chains (Templates)
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| C.1.1 | **`factory_security_audit`** | Scout → threat model → code review → fix → retest → document | Medium | High |
| C.1.2 | **`factory_perf_optimize`** | Benchmark → profile → optimize → benchmark → regression test | Medium | High |
| C.1.3 | **`factory_migration`** | Analyze → plan migration → execute → verify → rollback plan | Medium | Medium |
| C.1.3 | **`factory_dependency_update`** | Scan → plan updates → test → staged rollout → verify | Small | Medium |
| C.1.4 | **`factory_incident_response`** | Triage → diagnose → fix → verify → postmortem → Kaia memory | Medium | High |
| C.1.5 | **`factory_feature_flag_rollout`** | Gradual rollout with metric gates + automatic rollback | Medium | Medium |

#### C.2 Agent Capability Extensions
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| C.2.1 | **Multi-modal agents** | Vision input (screenshots, diagrams) for UI builder / documenter | Large | High |
| C.2.2 | **Agent skill marketplace** | Pluggable agent capabilities (npm-style packages with prompts + tools) | Large | Medium |
| C.2.3 | **Agent sandbox profiles** | Per-agent filesystem/network caps (beyond `writes:`) via WASM/deno | Large | Medium |
| C.2.4 | **Reasoning budget control** | Per-phase token/$$ ceiling; auto-escalate to stronger model if needed | Medium | High |
| C.2.5 | **Agent spec compliance** | Validate agent output against OpenAPI/AsyncAPI/GraphQL schemas | Medium | Medium |

#### C.3 Quality & Gates
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| C.3.1 | **Property-based test gate** | Generate + run quickcheck-style tests from type signatures | Medium | High |
| C.3.2 | **Contract test gate** | Consumer-driven contracts (Pact) for API changes | Medium | Medium |
| C.3.3 | **Security gate (SAST/DAST)** | Integrate Semgrep/CodeQL/Trivy as deterministic quality blocks | Small | High |
| C.3.4 | **Performance regression gate** | Compare benchmarks against baseline; fail on >5% regression | Medium | High |
| C.3.5 | **Accessibility gate** | axe-core / lighthouse CI as quality block | Small | Medium |
| C.3.6 | **License/compliance gate** | FOSSA / SPDX license check on dependency changes | Small | Low |

#### C.4 Context & Handoff
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| C.4.1 | **Semantic context compression** | LLM-based summarization of handoff files (not truncation) | Medium | High |
| C.4.2 | **Cross-repo context sharing** | Shared `context_handoff/` across monorepo factories | Medium | Medium |
| C.4.3 | **Context versioning** | Git-like history for handoff files with diff/blame | Small | Medium |
| C.4.4 | **Structured checkpoint format** | Replace markdown checkpoints with typed `Checkpoint` envelopes | Medium | Medium |

#### C.5 Orchestration & Scheduling
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| C.5.1 | **Parallel phase execution** | DAG-based phase scheduler (independent phases run concurrently) | Large | High |
| C.5.2 | **Cron / scheduled factories** | `factory schedule "0 2 * * *" factory_simple_sdlc "nightly refactor"` | Medium | Medium |
| C.5.3 | **Event-driven factories** | `process-event-sources` → factory trigger (GitHub webhook, cron, etc.) | Medium | High |
| C.5.4 | **Factory composition** | `factory_chain: [factory_plan, factory_build_test, factory_document]` | Medium | Medium |
| C.5.5 | **Distributed execution** | Offload agent phases to remote workers (Kubernetes, modal, fly.io) | Large | Low |

---

### D. Factory Backend — Developer Experience

#### D.1 Configuration & Onboarding
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| D.1.1 | **`factory init --interactive`** | Guided setup: language, test runner, agents, models, quality blocks | Small | High |
| D.1.2 | **Config validation CLI** | `factory doctor` — full preflight (models, tools, prompts, perms) | Small | High |
| D.1.3 | **Config schema docs generator** | Auto-generate markdown from `factoryConfig` Pydantic model | Small | Medium |
| D.1.4 | **Roster inheritance** | `extends: base-roster` in YAML for shared agent definitions | Small | Medium |

#### D.2 Debugging & Diagnostics
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| D.2.1 | **`factory replay <session>`** | Re-run a session from any phase with same context (deterministic replay) | Medium | High |
| D.2.2 | **`factory diagnose <session>`** | Auto-analyze failure: root cause, suggested fix, similar past failures | Medium | High |
| D.2.3 | **Live agent REPL** | `factory shell <session> <agent>` — interactive prompt in agent's context | Large | Medium |
| D.2.4 | **Phase time-travel** | `factory phase <session> <phase> --at <timestamp>` — inspect state at point | Medium | Low |

#### D.3 Testing & Validation
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| D.3.1 | **Factory contract tests** | Test factory scripts against known-good fixtures (golden runs) | Medium | High |
| D.3.2 | **Agent prompt regression suite** | Test agent prompts against model versions for drift detection | Medium | Medium |
| D.3.3 | **Chaos testing harness** | Inject faults (network, model errors, OOM) into factory runs | Large | Low |

---

### E. Infrastructure & Platform

#### E.1 Deployment & Operations
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| E.1.1 | **Docker/OCI images** | Pre-built images for factory runner + visualizer + Kaia bridge | Medium | High |
| E.1.2 | **Kubernetes operator** | `FactoryRun` CRD for cluster-native execution + visualizer ingress | Large | Medium |
| E.1.3 | **GitHub App integration** | Installable app: PR checks, status checks, auto-factory on labels | Large | High |
| E.1.4 | **Self-hosted telemetry** | OpenTelemetry export (traces/metrics/logs) to Tempo/Prometheus/Loki | Medium | Medium |

#### E.2 Multi-Tenancy & Teams
| ID | Enhancement | Description | Effort | Priority |
|----|-------------|-------------|--------|----------|
| E.2.1 | **Team workspaces** | Isolated factory configs, visualizer instances, Kaia memory per team | Large | Medium |
| E.2.2 | **RBAC for visualizer** | Viewer/Operator/Admin roles per workspace | Medium | Medium |
| E.2.3 | **Audit log** | Immutable log of all factory runs, steers, stops, config changes | Medium | High |

---

## Implementation Roadmap

### Phase 1: Quick Wins (Weeks 1-2)
**Goal**: High-impact, low-effort improvements to daily workflow

| Task | Owner | Deliverable |
|------|-------|-------------|
| A.2.4 Critical path highlighter | Visualizer | Waterfall shows longest dependency chain |
| A.4.1 Inline tool result preview | Visualizer | Expandable tool cards in chat |
| A.4.2 Chat↔trace back-links | Visualizer | Bidirectional navigation |
| B.1.3 Batch session export | API | `/api/sessions/export` endpoint |
| B.2.1 GitHub PR linking | Backend | Auto-link via commit message parsing |
| C.3.3 Security gate (SAST) | Backend | Semgrep integration in `quality.py` |
| C.3.5 Accessibility gate | Backend | axe-core in `quality.py` |
| D.1.1 `factory init --interactive` | Backend | Guided setup wizard |
| D.1.2 `factory doctor` | Backend | Full preflight validation |

### Phase 2: Core Enhancements (Weeks 3-6)
**Goal**: Substantial new capabilities for power users

| Task | Owner | Deliverable |
|------|-------|-------------|
| A.1.1 Presence indicators | Visualizer | WebSocket presence in SessionTrace |
| A.1.2 Shared steer annotations | Visualizer | Attributed steer messages |
| A.2.1 Comparative trace diff | Visualizer | Side-by-side waterfall view |
| A.2.2 Token flow Sankey | Visualizer | Interactive token flow diagram |
| A.2.3 Failure pattern miner | Visualizer + Backend | Clustered failures with fix suggestions |
| A.3.1 Memory graph explorer | Visualizer | Kaia engram entity graph |
| A.5.1 Visual roster editor | Visualizer | Drag-drop agent config UI |
| A.5.2 Model tier picker | Visualizer | Visual model catalog |
| B.1.1 WebSocket event stream | Visualizer + API | Replace 500ms polling |
| B.1.4 Run comparison API | API | Structured diff endpoint |
| C.1.1 Security audit factory | Backend | New `factory_security_audit.py` |
| C.1.2 Perf optimize factory | Backend | New `factory_perf_optimize.py` |
| C.1.5 Incident response factory | Backend | New `factory_incident_response.py` |
| C.2.4 Reasoning budget control | Backend | Per-phase token/$$ ceilings |
| C.3.1 Property-based test gate | Backend | Hypothesis/quickcheck integration |
| C.3.4 Perf regression gate | Backend | Benchmark comparison gate |
| C.4.1 Semantic context compression | Backend | LLM summarization of handoffs |
| C.5.3 Event-driven factories | Backend | `process-event-sources` integration |
| D.2.1 `factory replay` | Backend | Deterministic session replay |
| D.2.2 `factory diagnose` | Backend | Auto failure analysis |
| E.1.1 Docker images | Infra | Published OCI images |
| E.1.3 GitHub App | Infra | Installable PR integration |

### Phase 3: Platform Maturity (Weeks 7-12)
**Goal**: Enterprise readiness, extensibility, scale

| Task | Owner | Deliverable |
|------|-------|-------------|
| A.1.3 Session handoff | Visualizer | Take over paused runs |
| A.1.4 Comment threads | Visualizer | Phase-pinned discussions |
| A.2.5 Phase duration heatmap | Visualizer | Calendar view |
| A.3.2 Cross-project memory | Visualizer | Multi-repo Kaia query |
| A.5.3 Factory chain builder | Visualizer | Visual pipeline editor |
| A.6.1-6.3 Mobile + a11y | Visualizer | Responsive, WCAG AAA, PWA |
| B.1.2 GraphQL endpoint | API | Flexible query layer |
| B.2.2 Jira/Linear sync | Backend | Bidirectional ticket sync |
| C.1.3 Migration factory | Backend | `factory_migration.py` |
| C.1.4 Dependency update factory | Backend | `factory_dependency_update.py` |
| C.1.5 Feature flag rollout | Backend | `factory_feature_flag_rollout.py` |
| C.2.1 Multi-modal agents | Backend | Vision input support |
| C.2.2 Agent skill marketplace | Backend | Pluggable capability packages |
| C.4.2 Cross-repo context | Backend | Shared handoff in monorepo |
| C.4.3 Context versioning | Backend | Git-like handoff history |
| C.4.4 Typed checkpoints | Backend | `Checkpoint` envelope type |
| C.5.1 Parallel phase execution | Backend | DAG scheduler |
| C.5.2 Cron scheduled factories | Backend | `factory schedule` command |
| C.5.4 Factory composition | Backend | Chain factory scripts |
| D.1.3 Config docs generator | Backend | Auto-generated schema docs |
| D.1.4 Roster inheritance | Backend | YAML `extends:` support |
| D.2.3 Live agent REPL | Backend | Interactive agent shell |
| D.3.1 Factory contract tests | Backend | Golden run test suite |
| D.3.2 Agent prompt regression | Backend | Model drift detection |
| E.1.2 K8s operator | Infra | `FactoryRun` CRD |
| E.1.4 OTel export | Infra | Tempo/Prometheus/Loki |
| E.2.1 Team workspaces | Infra | Multi-tenant isolation |
| E.2.2 RBAC | Infra | Role-based access |
| E.2.3 Audit log | Infra | Immutable operation log |

---

## Technical Considerations

### Visualizer Tech Debt to Address
1. **Polling → WebSocket**: Current 500ms polling is simple but scales poorly; SSE/WebSocket for live updates
2. **State management**: Migrate from composables to Pinia for devtools + persistence
3. **Bundle size**: Code-split views (Memory, Decisions, Stats, Chat) — lazy load
4. **Type safety**: Strict TypeScript + `vue-tsc --noEmit` in CI (already configured)
5. **Test coverage**: Add Vitest unit tests for components + Playwright e2e for critical flows

### Backend Tech Debt to Address
1. **Plugin architecture**: Factory modules should be discoverable plugins, not hardcoded imports
2. **Async execution**: `agent_pi.run` is synchronous; move to `asyncio` for parallel phases
3. **Config hot-reload**: Watch `factory.config.yaml` for changes without restart
4. **Structured logging**: Replace `console.py` Rich output with structured JSON logs + OTel
5. **Migration system**: Versioned DB migrations for `factory.db` schema changes

### Data Model Extensions Needed
```python
# New types for enhancement support
class Checkpoint(EnvelopeBase):        # C.4.4
    phase: str
    summary: str
    artifacts: list[str]
    context_summary: str

class MetricPoint(BaseModel):          # B.2.4
    name: str
    value: float
    timestamp: str
    tags: dict[str, str]

class TeamWorkspace(BaseModel):        # E.2.1
    id: str
    name: str
    factory_config: str
    visualizer_url: str
    kaia_bridge_url: str
    members: list[str]
    rbac: dict[str, list[str]]         # role → permissions
```

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| WebSocket complexity breaks polling fallback | Medium | High | Keep polling as fallback; feature flag WebSocket |
| Multi-modal agents need new harness support | High | Medium | Start with Pi vision extensions; opencode later |
| Parallel phases break context handoff assumptions | Medium | High | Design DAG with explicit data dependencies |
| Kaia memory bridge becomes bottleneck | Medium | Medium | Add caching layer; async proxy |
| Docker images bloat with all model deps | Low | Medium | Multi-stage builds; optional model layers |
| GitHub App permissions scope creep | Medium | High | Minimal permissions; user-granted per repo |

---

## Success Metrics

| Metric | Baseline | Target (6mo) | Target (12mo) |
|--------|----------|--------------|---------------|
| Mean time to detect failure | ~5 min (polling) | <30 sec (WebSocket) | <10 sec |
| Factory script authoring time | ~2 hours | <30 min (visual builder) | <15 min |
| Cross-run failure correlation | Manual | Auto-clustered | Auto-fix suggested |
| Agent context window utilization | Unknown | Tracked + visualized | Optimized via compression |
| Factory adoption (repos stamped) | ~5 | 25 | 100+ |
| Visualizer daily active users | ~3 | 15 | 50+ |

---

## Appendix: Quick Reference — Current Commands

```bash
# Visualizer
just ui                    # Start visualizer (API :4600, UI :4601)
bun run server/index.ts    # API only
bun run dev                # Vite dev server (proxies /api)

# Factory
uv run factory/factory_simple_sdlc.py "add health endpoint"
uv run factory/factory_orchestrate.py "refactor auth" --factory-id a1b2c3d4
factory doctor             # Preflight check
factory team list          # Show rosters
factory mission T1         # Bench missions

# Kaia Memory
just kaia                  # CLI memory interface
# UI: http://localhost:4601/#/memory
```

---

## Appendix: Key Files to Modify per Enhancement

| Enhancement Area | Primary Files |
|------------------|---------------|
| Visualizer views | `apps/visualizer/src/components/*.vue` |
| Visualizer API | `apps/visualizer/server/index.ts`, `server/db.ts` |
| Visualizer types | `apps/visualizer/shared/types.ts`, `src/lib/types.ts` |
| Factory chains | `templates/factory/factory_*.py` |
| Factory modules | `templates/factory/factory_modules/*.py` |
| Data contracts | `templates/factory/factory_modules/data_types.py` |
| Agent prompts | `templates/prompt_engineering/<agent>/system.md`, `user.md` |
| Config schema | `templates/factory.config.yaml`, `references/config.md` |
| Observability spec | `references/observability.md` |
| Handoff protocol | `references/handoff.md` |

---

## Next Steps

1. **Captain reviews and prioritizes** — Select Phase 1 items for immediate sprint
2. **Create implementation tickets** — Use `ticket-create` with measurable goals
3. **Assign workstreams** — Visualizer vs Backend vs Infra tracks
4. **Weekly sync** — Track progress against roadmap
5. **Retrospective at Phase 1 end** — Adjust priorities based on learnings

---

*This plan is a living document. Update as enhancements are completed, new needs emerge, or priorities shift.*