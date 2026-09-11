# Plan 27 — Hermóðr: MCP/A2A Composition

- **Status:** proposed
- **Realm:** platform (cross-tenant)
- **Owner:** Brokk / Kaia
- **Directive:** Document the Hermóðr composition pattern that bridges MCP (vertical, agent→tools/resources) and A2A 1.0 (horizontal, agent↔agent, opaque stateful tasks). Hermóðr is the composition operator enabling Ymir's orchestrator to delegate work via A2A while specialists access tools via MCP — no bespoke glue, reuse validated OSS SDKs, Norse naming convention.

## Objective

Define **Hermóðr** as the canonical MCP+A2A composition pattern across the Ymir platform, so that:

- The orchestrator (Kaia) delegates tasks to specialists via **A2A 1.0** (horizontal, stateful, task-streaming).
- Each specialist reaches tools and resources via **MCP** (vertical, agent→tools/resources, opaque).
- The composition is realm-scoped (Svartalfaheim); cross-realm calls require explicit grant.
- Every Hermóðr-mediated operation is observed into **Mimirsbrunn** and logged to **Runes**.
- Hlidskjalf renders the live Hermóðr fleet graph: who is delegating via A2A, who is using MCP, and the composition state.
- The pattern is reusable: any agent in the fleet (Brokk, Kaia, Eindri workers, external A2A-compliant agents) can operate under Hermóðr.

## Hermóðr Composition Pattern

| Dimension | MCP | A2A 1.0 | Hermóðr (Composition) |
|---|---|---|---|
| **Direction** | Vertical: agent → tools/resources | Horizontal: agent ↔ agent, opaque stateful tasks | Orchestrator delegates via A2A; specialists use MCP internally |
| **Scope** | Single-agent: one agent's tool access | Multi-agent: fleet-wide agent discovery & task delegation | Cross-agent: one agent delegates, another executes via MCP |
| **State** | Resource access tokens, credentials | Task state machine (SUBMITTED→WORKING→COMPLETED/FAILED/REJECTED/CANCELED/INPUT_REQUIRED/AUTH_REQUIRED) | Task state mirrored: A2A carries semantics, MCP carries tool-access state |
| **Streaming** | Not typically streaming (resource access is request-response) | SSE streaming for long-running worker results | A2A task streams results; MCP tool access is intra-task |
| **Discovery** | Tool manifest (.agents/tools/, toolchain.md) | Agent Cards at `/.well-known/agent-card.json`, realm-scoped | Orchestrator knows which specialist to A2A-delegate; specialist knows which MCP tools to use |
| **Signing/Auth** | API-key / mTLS per tool | JWS-signed Agent Cards via Heimdall (RFC 8615) | Outbound A2A task carries JWS; inbound MCP tool calls authenticated per realm |
| **Observability** | Runes entries for tool access | Every A2A message → Mimirsbrunn + Runes (realm, actor, state, timestamp) | Hermóðr bridge: both A2A + MCP paths observed; task state + tool usage logged |
| **Idempotency** | Client-side; token renewal, credential rotation | Orchestrator handles retry/idempotency (terminal states cannot restart) | Orchestrator tags A2A task with idempotency key; MCP tool access is idempotent by design |
| **Typical Use** | Agent fetches data, writes to DB, sends email | Agent delegates sub-task to peer agent | **Hermóðr**: Kaia dispatches Eidri specialist as A2A task → specialist uses MCP to access DB/Supabase/Redis → result streams back via A2A → observed into Mimirsbrunn + Runes |

## System Integration Points

### 1. Kaia as Hermóðr Orchestrator

- **Dispatch**: Kaia creates an A2A task (SSE streaming) and delivers it to a specialist via Ratatoskr.
- **MCP Bridge**: Before/during execution, Kaia recalls Mimirsbrunn and maps required MCP tools for the specialist.
- **Anti-Hallucination Gate**: Verifies memory recall before dispatch; honours `orchestrator_dispatched` gate.
- **Result Collection**: Streams results back via A2A SSE; on completion, records both the A2A task state and the MCP tool usage into Mimirsbrunn and Runes.

### 2. Specialist Execution Under Hermóðr

- **Inbound**: Specialist receives A2A task via inbox poll (the `a2a-bridge` skill pattern).
- **Tool Access**: Specialist uses MCP (not A2A) to access tools: Supabase, Redis, vector DB, filebrowser, etc.
- **Completion**: Specialist marks A2A task as COMPLETED; the result (not the tool credentials) streams back via A2A.
- **Observability**: Every Hermóðr step is observed:
  - A2A task state → Mimirsbrunn + Runes (realm, actor, task_id, state, timestamp)
  - MCP tool usage → Runes (tool_name, operation, result_status, agent_id, timestamp)
  - Cross-realm grant → Runes (grant_id, from_realm, to_realm, granted_at)

### 3. Ratatoskr — Hermóðr Message Routing

- A2A tasks routed through Ratatoskr carry a `hermod_composition` flag/context.
- Realm-scoped discovery: specialist's Agent Card is Svartalfaheim-registered; cross-realm requires explicit grant.
- InterAgentMessage schema includes `hermod_context` field (optional): `{mcp_tool_set, orchestrator_id, grant_id, fallback_mcp}`.

### 4. Mimirsbrunn — Hermóðr Observability

- **A2A path**: Every task SUBMITTED/WORKING/COMPLETED/FAILED → indexed with realm, actor, task_id, state, timestamp, hermod=true.
- **MCP path**: Every tool operation (Supabase query, Redis command, filebrowser access) → indexed with realm, actor, tool_name, operation, result_status, agent_id, timestamp, hermod=true.
- **Recall**: `GET /timeline?hermod=true` returns both A2A task flow and MCP tool usage flow, interleaved by timestamp.
- **Hybrid Recall**: `hybrid` mode (0.5 cosine + 0.5 BM25) searches across both A2A and MCP indexed content.

### 5. Runes — Hermóðr Audit Ledger

Append-only entries for every Hermóðr composition step:

| Field | Description |
|---|---|
| `realm` | Svartalfaheim realm (way-of, zerwiz, craig) |
| `actor` | Agent ID or display name |
| `task_id` | A2A task ID (if applicable) |
| `hermod_flag` | `true` if Hermóðr composition |
| `mcp_tool` | MCP tool name (if applicable) |
| `mcp_operation` | MCP operation (query, write, etc.) |
| `mcp_result` | Result status (success, failure, partial) |
| `state` | A2A task state (SUBMITTED, WORKING, COMPLETED, FAILED, etc.) |
| `timestamp` | ISO 8601 |
| `grant_id` | Cross-realm grant reference (if applicable) |
| `jws_verified` | Whether Agent Card JWS verification passed |

### 6. Hlidskjalf — Hermóðr Fleet Graph

- **Fleet view**: Shows agents operating under Hermóðr composition.
- **Indicators**: 
  - A2A task state (streaming, completed, failed)
  - MCP tool set active for each specialist
  - Cross-realm grant status
  - Open tasks requiring MCP tool access
- **Tenant isolation**: Users only see their realm's Hermóðr operations.

### 7. Skills — `hermod-bridge` (Canonical)

- New skill in `.agents/skills/hermod-bridge.ts` (validated in Utgard).
- **Poll inbox** each turn for A2A tasks delegated via Hermóðr.
- **Complete tasks**: Execute via MCP tool set; stream results back via A2A.
- **FYI peers**: On contract/schema/infra changes, FYI other agents via A2A.
- **Self-label**: `<basename-cwd>-<4hex>`.
- **Registration**: Skill index; Utgard validation before production.

### 8. Cron — Hermóðr Background Polling

- Daily briefing at 07:00, written to `svartalfaheim/<realm>/workspace/memory/daily/YYYY-MM-DD.md`.
- Background git syncs on configurable schedule.
- Stateless spawning: fresh process → inject AGENTS.md + Hermóðr task prompt → execute → write output → exit.
- A2A inbox poll: each turn, agents poll their inbox for Hermóðr-delegated tasks; complete via MCP; FYI peers on changes.

## ADD / NOT / KEEP

**ADD** (to `docs/plans/`):
- `27-hermod-mcp-a2a-composition.md` — this Hermóðr composition planning doc.
- Hermóðr composition pattern table (above).
- Hlidskjalf fleet graph Hermóðr integration spec.
- Runes audit entry spec for Hermóðr operations.
- `hermod-bridge` skill scaffold (validated in Utgard).

**NOT** build:
- A custom MCP/A2A bridge protocol — reuse A2A 1.0 + existing MCP servers.
- A new task state machine — A2A 1.0's state machine is reused; Hermóðr composes on top.
- Bespoke tool-access patterns — reuse MCP servers (all tool access per AGENTS.md:79).

**KEEP**:
- Norse naming: Hermóðr as the bridge-rider (myth: traveled to Hel and back).
- `InterAgentMessage` schema (extended with `hermod_context`).
- `a2a-bridge` skill pattern (extended for Hermóðr composition).
- MCP servers for all tool access (AGENTS.md:79).
- Open-source first law (AGENTS.md:80).
- ENTRY-008 platform doctrine (reuse OSS, differentiate on UI/UX + runtime + A2A).
- Ratatoskr as A2A 1.0 backbone (Hermóðr composes on top).

## Files Created/Modified

- **Created**: `docs/plans/27-hermod-mcp-a2a-composition.md` — complete Hermóðr composition documentation.
- **Modified**: `AGENTS.md` — added Hermóðr as subsystem 13 (MCP/A2A Composition).
- **Referenced**: `docs/plans/25-ratatoskr-a2a.md` — master A2A plan; `docs/plans/26-a2a-planning.md` — A2A planning doc; `AGENTS.md` law 8; `docs/Architecture.md` — enhanced Ratatoskr section; `.a2a/bridge.log`; `docs/append-only-log.md` ENTRY 2026-09-11-009.

## Next Steps

1. **Validate**: Run a minimal Hermóðr composition scenario — Kaia dispatches a specialist as A2A task, specialist uses MCP tools, result streams back, both paths observed into Mimirsbrunn + Runes.
2. **Implement**: `hermod-bridge` skill in `.agents/skills/` with Utgard validation.
3. **Register**: Extend `InterAgentMessage` schema (`.agents/bus/protocol.ts`) with optional `hermod_context` field.
4. **Observe**: Configure Mimirsbrunn recall for Hermóðr paths (`/timeline?hermod=true`).
5. **Audit**: Set up Rune entries for both A2A and MCP paths (spec above).
6. **Observe**: Hlidskjalf fleet graph Hermóðr integration (registry + Redis + Mimirsbrunn).
7. **Document**: MCP tool sets per specialist role profile (.agents/subagents/).
8. **Test**: Cross-realm Hermóðr composition with explicit grants (from one Svartalfaheim realm to another).

## Composition Philosophy

> **Hermóðr** is the bridge: the orchestrator sends a task A2A-ward, and the specialist returns result MCP-ward. The composition is where Ymir's differentiator lives — not in building another protocol, but in composing two validated OSS standards (A2A 1.0 + MCP) so agents can delegate horizontally while accessing tools vertically. Everything else — discovery, signing, observability, audit — is reused from the validated OSS ecosystem. Only the composition operator is Ymir-specific: the Hermóðr pattern.

> *Hermóðr traveled to Hel and back. The MCP+A2A composer goes to the tool-realm and back, bringing results to the fleet.*