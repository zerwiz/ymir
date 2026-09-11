# Plan 26 — A2A Planning for Ymir

- **Status:** proposed
- **Realm:** platform (cross-tenant)
- **Owner:** Brokk / Kaia
- **Directive:** Integrate A2A 1.0 protocol planning across the Ymir system, ensuring all subsystems — agent runtime, memory, observability, multi-tenancy, and portal — are aligned with the open A2A 1.0 standard (Linux Foundation, ratified 2026). Reuse validated OSS SDKs (`a2aproject/a2a`, `a2a-js`, `a2a-python`, `a2a-go`) where possible; differentiate Ymir on UI/UX, runtime, and A2A collaboration (Ratatoskr).

## Objective

Make **A2A 1.0** a first-class protocol layer throughout the Ymir platform, so that:

- Every agent in the fleet (Brokk, Kaia, Eindri workers, personal agents, external peers) can discover, delegate, and stream results via A2A 1.0.
- Ratatoskr remains the A2A 1.0 backbone with realm-scoped agent card registry, Redis pub/sub as the task-underlying queue, and signed cards via Heimdall.
- A2A task semantics (SUBMITTED→WORKING→COMPLETED/FAILED/REJECTED/CANCELED/INPUT_REQUIRED/AUTH_REQUIRED) map to Ymir's internal task model and observability (Mimirsbrunn + Runes).
- MCP complements A2A: MCP = vertical (agent→tools/resources), A2A = horizontal (agent↔agent, opaque stateful tasks). Composability is key: orchestrator delegates via A2A; specialists use MCP internally.
- Hlidskjalf renders the live fleet graph from registry + Redis + Mimirsbrunn timeline.
- Cross-realm discovery is realm-scoped (Svartalfaheim); cross-realm calls require explicit grant.
- Every A2A message is observed into Mimirsbrunn and logged to Runes with realm, actor, task state, and timestamp.

## A2A 1.0 Protocol Alignment

| Layer | Ymir Implementation | OSS Reference |
|---|---|---|
| **Protocol** | JSON-RPC 2.0 over HTTPS + SSE streaming (optional gRPC) | `a2aproject/a2a` · `a2a-js` / `a2a-python` / `a2a-go` |
| **Agent Cards** | `/.well-known/agent-card.json`, JWS-signed via Heimdall (RFC 8615) | Agent Card discovery, capability-based, tamper-evident identity |
| **Task Lifecycle** | SUBMITTED→WORKING→COMPLETED/FAILED/REJECTED/CANCELED/INPUT_REQUIRED/AUTH_REQUIRED; terminal states cannot restart | JSON-RPC 2.0 task state machine |
| **Discovery** | Realm-scoped (Svartalfaheim) — cards not globally visible; cross-realm requires explicit grant | Agent Card at `/.well-known/agent-card.json` |
| **Queue/Throughput** | Redis pub/sub as the queue *under* the A2A task model (semantics on A2A, throughput on Redis) | Redis pub/sub |
| **Signing/Auth** | OAuth 2.0 / API-key / mTLS, scoped per Agent Card; forged cards detected at Heimdall | OAuth 2.0 / API-key / mTLS |
| **Streaming** | SSE for long-running worker results (Kaia dispatches Eidri specialists as streaming A2A tasks) | SSE streaming |
| **MCP Composition** | MCP = vertical (agent→tools/resources), A2A = horizontal (agent↔agent, opaque stateful tasks) | MCP complements, not competes with A2A |
| **Observability** | Every A2A message → Mimirsbrunn + Runes (realm, actor, task state, timestamp) | OTel W3C trace context across every hop |
| **SDKs** | Python, JS/TS, Go, Java, .NET, Rust (via OSS SDKs) | One protocol, every runtime |

## System Integration Points

### 1. Ratatoskr — A2A 1.0 Backbone (per `docs/plans/25-ratatoskr-a2a.md`)

- **Agent Card Registry**: Per-realm cards at `/.well-known/agent-card.json`, JWS-signed via Heimdall. Realm-scoped discovery.
- **Redis Pub/Sub**: Queue *under* the A2A task model. A2A carries semantics; Redis carries throughput.
- **InterAgentMessage Schema** (`.agents/bus/protocol.ts`): sender/recipient (tenant+agent), messageType, payload, status.
- **Message Flow**: Every A2A message observed into Mimirsbrunn and logged to Runes with realm, actor, task state, and timestamp.
- **Heimdall Integration**: Signed cards detected and refused if forged/rejected.
- **Cross-Realm Calls**: Require explicit grant; cards are Svartalfaheim-scoped.

### 2. Kaia as A2A Orchestrator

- Dispatches Eidri specialists as **A2A tasks** (SSE streaming for long-running workers).
- Recalls Mimirsbrunn before dispatch, honours the `orchestrator_dispatched` anti-hallucination gate.
- Specialists reach tools via **MCP** (not A2A).
- Anti-hallucination gate: verify memory recall before task dispatch.

### 3. Mimirsbrunn — A2A Observability

- Every A2A message indexed with: realm, actor, task state, timestamp.
- Timeline integration: RAG queries against A2A message history.
- Recall via bridge (`:4602`): `GET /health`, `/inspect`, `/recall?q&k&mode`, `/timeline?entity`.
- Memory model: episodes (content, actors, tags, salience, importance, agent_id), facts (SPO triples), entities/edges (graph for spreading activation).

### 4. Runes — A2A Audit Ledger

- Append-only ledger entry for every A2A message:
  - `realm`, `actor`, `task_id`, `message_type`, `state`, `timestamp`, `jws_verified`
- Used for: audit, replay, debugging, compliance.
- Every message flow passes through Runes.

### 5. Hlidskjalf — A2A Fleet Graph

- Live fleet graph from registry + Redis + Mimirsbrunn timeline.
- Shows: who is talking to whom, live A2A task states, message queue depth.
- Tenant isolation: users only see their realm.
- Portal features: fleet view, inter-agent network stream, PR review cards, tenant switcher.

### 6. Multi-Tenancy — Svartalfaheim A2A Scoping

- Each realm = isolated A2A domain: `.env.realm`, `Brokk.md`, `projects/`, `workspace/`.
- Agent Cards are realm-scoped; discovery returns only what a realm may see.
- Cross-realm collaboration: explicit grant required; card signing via Heimdall provides tamper-evidence.
- Realm context loader (`tenant_context_loader.ts`) verifies boundaries before any A2A task.

### 7. MCP — Complement to A2A

- **MCP (Model-Context-Protocol)**: vertical layer, agent→tools/resources.
- **A2A 1.0**: horizontal layer, agent↔agent, opaque stateful tasks.
- **Composition**: orchestrator delegates via A2A; each specialist uses MCP internally for tool access.
- Ymir owns MCP servers (all tool access); A2A backbone is Ratatoskr.

### 8. Skills — A2A Bridge (`a2a-bridge`)

- Canonical collaboration skill: poll inbox each turn, complete tasks, FYI peers on contract/schema/infra changes.
- Self-label `<basename-cwd>-<4hex>`.
- Validated in Utgard before production use.
- Registered in skill index.

### 9. Cron Automation — A2A Task Polling

- Daily briefing at 07:00, written to `svartalfaheim/<realm>/workspace/memory/daily/YYYY-MM-DD.md`.
- Background git syncs on configurable schedule.
- Stateless spawning: fresh process → inject AGENTS.md + task prompt → execute → write output → exit.
- A2A inbox poll: each turn, agents poll their inbox; complete tasks; FYI peers on changes.

### 10. Portal & Dashboard — Hlidskjalf A2A Features

- Fleet view from registry + Redis + Mimirsbrunn.
- Live A2A task states streaming.
- Message queue depth per card.
- Per-card status with realm, actor, task state, timestamp.
- Inter-agent network stream.
- Tenant switcher (realm isolation).

## Acceptance Criteria (from Plan 25, reinforced)

1. **Cross-realm discovery**: Two agents on different realms can discover each other and complete an A2A task with no bespoke glue.
2. **Forged card detection**: A rejected/forged Agent Card is detected and refused at Heimdall.
3. **Kaia orchestration**: Kaia can dispatch a worker as a streaming A2A task and observe the result into Mimirsbrunn.
4. **Message observability**: Every A2A message appears in Runes with realm, actor, task state, and timestamp.
5. **Fleet graph**: Hlidskjalf renders the live fleet graph from registry + Redis.

## ADD / NOT / KEEP

**ADD** (to `docs/plans/`):
- `26-a2a-planning.md` — this A2A planning doc, aligning all Ymir subsystems with A2A 1.0.
- A2A task state mapping table (A2A → Ymir internal model → Runes + Mimirsbrunn).
- MCP/A2A composition spec (vertical vs horizontal, composability).
- Hlidskjalf fleet graph A2A integration spec.

**NOT** build:
- A custom inter-agent protocol — build on A2A 1.0, not a bespoke bus.
- A new queue system — Redis is the throughput *under* the A2A task model.
- A rebuilt portal/visualizer primitives — reuse Hlidskjalf + React/Expo.
- Bespoke feature builds where a validated OSS project already exists (e.g., `a2aproject/a2a` SDKs).

**KEEP**:
- Norse naming conventions (Ratatoskr, Heimdall, Mimirsbrunn, Runes).
- `InterAgentMessage` schema.
- `a2a-bridge` skill pattern.
- MCP for all tool access.
- `a2aproject/a2a` + SDKs (interop).
- Open-source first law (AGENTS.md:80).
- ENTRY-008 platform doctrine (reuse OSS, differentiate on UI/UX + runtime + A2A).

## Files Created/Modified

- **Created**: `docs/plans/26-a2a-planning.md` — this complete A2A planning document.
- **Modified**: `docs/Architecture.md` — enhanced Ratatoskr section with full A2A 1.0 integration (entry 008 alignment).
- **Created**: `docs/append-only-log.md` ENTRY 2026-09-11-009 — A2A Documentation Integration.
- **Referenced**: `docs/plans/25-ratatoskr-a2a.md` — master A2A plan; `AGENTS.md` law 8; `.a2a/bridge.log`; `AGENTS.md` law 8.

## Next Steps

1. **Validate**: Run the acceptance criteria against a minimal two-agent A2A task (cross-realm or same-realm).
2. **Implement**: `InterAgentMessage` schema in `.agents/bus/protocol.ts` (if not already present).
3. **Register**: `a2a-bridge` skill in `.agents/skills/` with Utgard validation.
4. **Observe**: Configure Mimirsbrunn recall for A2A messages (`/recall`, `/timeline` endpoints).
5. **Audit**: Set up Runes entries for every A2A message flow.
6. **Observe**: Hlidskjalf fleet graph integration (registry + Redis + Mimirsbrunn).
7. **Document**: MCP/A2A composition patterns for specialist tool access.
8. **Test**: Cross-realm A2A task completion with explicit grants.