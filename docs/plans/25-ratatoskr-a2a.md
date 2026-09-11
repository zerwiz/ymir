# Plan 25 — Ratatoskr: a Great A2A System

- **Status:** proposed → approved (ENTRY 2026-09-11-008)
- **Realm:** platform (cross-tenant)
- **Owner:** Brokk / Kaia
- **Directive:** We need a great A2A system. Ymir owns the UI/UX, the agent runtime, and *how agents collaborate* — cooperation is a differentiator, everything else is reused OSS.

## Objective

Make **Ratatoskr** the backbone over which every agent in the fleet —
Brokk, Kaia, the Eidri workers, personal agents, and any external A2A-compliant
agent — discovers each other, delegates work, and streams results. Built on the
**open A2A 1.0 protocol** (Linux Foundation), not a bespoke bus.

## Why A2A 1.0 (research, 2026)

| Fact | Decision impact |
|---|---|
| A2A absorbed IBM's ACP (Aug 2025); v1.0 stable 2026; 150+ orgs (AWS, Azure, Vertex, Salesforce, SAP) | Fragmentation over — build on A2A, not a custom protocol |
| JSON-RPC 2.0 over HTTPS + SSE streaming; gRPC optional | Mature, tool-agnostic plumbing |
| Agent Cards at `/.well-known/agent-card.json`, JWS-signable (RFC 8615) | Capability-based discovery + tamper-evident identity |
| Task state machine (SUBMITTED→WORKING→COMPLETED/FAILED/REJECTED/CANCELED/INPUT_REQUIRED/AUTH_REQUIRED); terminal states cannot restart | Retry + idempotency lives in the orchestrator, not the agent |
| MCP = vertical (agent→tools), A2A = horizontal (agent↔agent) | They compose: delegate over A2A, execute over MCP |
| SDKs: Python, JS/TS, Go, Java, .NET, Rust | One protocol, every runtime |

## Architecture

```
┌─ AI Agent Fleets (any framework) ───────────────────────────────┐
│  Brokk · Kaia · Eidri workers · personal agents · external peers │
└───────────────┬──────────────────────────────────────────────────┘
                │ A2A 1.0 — JSON-RPC 2.0 / HTTPS · SSE streaming
                ▼
┌─ BIFROST ─────┴── Heimdall ─────────────────────────────────────┐
│  gateway + router │ signed Agent Cards (JWS) · OAuth/API-key     │
└───────────────┬──────────────────────────────────────────────────┘
                ▼
┌─ RATATOSKR ─────────────────────────────────────────────────────┐
│  A2A task model (semantics)   +   Redis pub/sub (throughput)     │
│  Registry: agent cards, Svartalfaheim-scoped discovery            │
│  ./agents/bus/protocol.ts InterAgentMessage schema               │
└───────┬─────────────────────────────┬────────────────────────────┘
        │ observe every message         │ logged every message
        ▼                                ▼
   MIMIRSBRUNN (engram)            RUNES (append-only ledger)
```

## Phases

### Phase 1 — Bridge the existing `a2a-bridge` skill into Ymir (`scaffold`)
- Ship the current local A2A discovery (cards at `/.well-known/agent-card.json`,
  inbox hooks, `a2a_*` tools) as the seed of Ratatoskr.
- Agents poll their inbox each turn; complete tasks; FYI peers on
  contract/schema/infra changes. Self-label `<basename-cwd>-<4hex>`.

### Phase 2 — Registry + realm scoping (`scaffold`)
- Per-realm registry under Svartalfaheim: cards are **realm-scoped**, discovery
  returns only what a realm may see. Cross-realm calls require an explicit grant.
- Card contains name, capabilities/skills, `supportedInterfaces`, security
  schemes; **signed via Heimdall** (JWS over canonicalised card).

### Phase 3 — Task lifecycle + queue (`scaffold`)
- Redis pub/sub becomes the queue *under* the A2A task model (semantics on A2A,
  throughput on Redis). Task states mirrored to Redis for observability.
- Orchestrator handles retry/idempotency (tag tasks with idempotency keys);
  terminal states never restart.

### Phase 4 — Kaia the orchestrator (`active`)
- Kaia dispatches Eidri specialists as **A2A tasks** (SSE streaming for
  long-running workers), recalls Mimirsbrunn before dispatch, honours the
  `orchestrator_dispatched` anti-hallucination gate. Specialists reach tools
  via **MCP**.

### Phase 5 — Observability in Hlidskjalf (`draft`)
- Portal shows the fleet graph (who is talking to whom), live A2A task states,
  message queue depth, per-card status; every message is visible in the Runes
  ledger and the Mimirsbrunn timeline.

## OSS components to reuse (never rebuild)

| Layer | OSS project |
|---|---|
| Protocol + SDK | `a2aproject/a2a` · `a2a-js` / `a2a-python` / `a2a-go` |
| Queue | **Redis** (pub/sub under the task model) |
| Gateway / routing | **Traefik** or **Caddy** (Bifrost) |
| Auth / signing | **OAuth2-proxy / Authentik** + JWS card signing (Heimdall) |
| Memory | **engram/engdbram** (Mimirsbrunn bridge, `:4602`) |
| Tool access | **MCP servers** (every specialist) |
| Existing systems | `a2a-bridge` skill · `smidja` orchestration · `firstmate` supervision |

## Acceptance criteria

1. Two agents on different realms can discover each other and complete an A2A task with no bespoke glue.
2. A rejected/forged Agent Card is detected and refused at Heimdall.
3. Kaia can dispatch a worker as a streaming A2A task and observe the result into Mimirsbrunn.
4. Every A2A message appears in Runes with realm, actor, task state, and timestamp.
5. Hlidskjalf renders the live fleet graph from registry + Redis.

## ADD / NOT / KEEP

- **ADD:** Ratatoskr registry & bridge under `.agents/bus/`, realm-scoped discovery, signed cards, Redis queue mirror, Hlidskjalf fleet view.
- **NOT:** a custom inter-agent protocol, a bespoke message queue, a new auth system.
- **KEEP:** Norse naming, `InterAgentMessage` schema, the `a2a-bridge` skill pattern, MCP for all tool access.