# Ymir vs. The Agent Harnesses — Where We Stand

**Date:** 2026-09-12
**Author:** Brokk

---

## The Fundamental Difference

The commercial harnesses are **frameworks** — libraries you import into your application.

Ymir is a **platform** — a complete operating system for autonomous agent work.

Every commercial harness assumes you already have:
- A machine to run on
- A repo to work in
- A way to isolate agents
- A memory system
- An audit trail
- A control plane UI
- A terminal for agent panes
- A scheduler

Ymir **provides all of that**. It's not a library you add to your project — it *is* the project.

---

## Head-to-Head Comparison

### 1. Agent Isolation

| | Ymir | LangChain | CrewAI | MAF | DSPy | Agno | OpenAI SDK | Claude SDK |
|---|---|---|---|---|---|---|---|---|
| **Isolation model** | Git worktrees + Docker sandboxes | None (same process) | None (same process) | Docker (optional) | None | Docker (optional) | None | None |
| **Parallel agents** | ✅ Zero-collision worktrees | ❌ Sequential | ❌ Sequential | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Untrusted code** | ✅ Utgard (CPU/RAM/timeout caps, no host root, no network) | ❌ Runs in your process | ❌ Runs in your process | ⚠️ Optional | ❌ | ⚠️ Optional | ❌ | ❌ |
| **Failure containment** | ✅ Failed Utgard never touches main | ❌ Crash = your crash | ❌ Crash = your crash | ⚠️ Partial | ❌ | ⚠️ Partial | ❌ | ❌ |

**Ymir wins on isolation.** Every agent runs in its own Git worktree and Docker sandbox. A bad agent can't corrupt your repo, leak secrets, or crash your process. The commercial harnesses all run agents in your process — if an agent goes rogue, it's your machine, your repo, your secrets.

### 2. Memory & Persistence

| | Ymir | LangChain | CrewAI | MAF | DSPy | Agno | OpenAI SDK | Claude SDK |
|---|---|---|---|---|---|---|---|---|
| **Persistent memory** | ✅ Mimirsbrunn (long-term, embeddings) | ❌ (you build it) | ❌ (you build it) | ❌ (you build it) | ❌ | ❌ (you build it) | ❌ | ✅ Managed sessions |
| **Session recall** | ✅ Kaia orchestrates memory recall | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Knowledge curation** | ✅ Tiered, decaying startup memory | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

**Ymir wins on memory.** Mimirsbrunn + Kaia give persistent, curated, long-term memory that survives session resets. The commercial harnesses either have no memory (LangChain, CrewAI, DSPy, Agno) or only session-scoped memory (Claude Managed Agents).

### 3. Audit & Accountability

| | Ymir | LangChain | CrewAI | MAF | DSPy | Agno | OpenAI SDK | Claude SDK |
|---|---|---|---|---|---|---|---|---|
| **Append-only ledger** | ✅ Runes (chain-verified, never rewritten) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Action tracing** | ✅ Every action inscribed | ✅ LangSmith (paid) | ✅ Control Plane | ❌ | ❌ | ✅ Control Plane | ❌ | ❌ |
| **Human approval** | ✅ Required for code merges, production deploys | ❌ | ✅ Gates | ❌ | ❌ | ✅ Approvals | ❌ | ❌ |

**Ymir wins on audit.** The Runes ledger is append-only, chain-verified, and never rewritten. Every significant action is inscribed. The commercial harnesses either have no audit trail or require a paid product (LangSmith, CrewAI Control Plane).

### 4. Control Plane & UI

| | Ymir | LangChain | CrewAI | MAF | DSPy | Agno | OpenAI SDK | Claude SDK |
|---|---|---|---|---|---|---|---|---|
| **Control plane UI** | ✅ Hlidskjalf (Odin's high seat) | ❌ | ✅ Studio | ❌ | ❌ | ✅ Control Plane | ❌ | ❌ |
| **Agent fleet view** | ✅ Live fleet of agents | ❌ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ |
| **Terminal panes** | ✅ Þjazi (sub-agent panes, protocol 14+) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Desktop shell** | ✅ Electron (Hlidskjalf/Smíðja) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

**Ymir wins on control plane.** Hlidskjalf gives a full control plane with live fleet view, terminal panes for agents, and an Electron desktop shell. The commercial harnesses either have no UI or a basic builder (CrewAI Studio).

### 5. Scheduling & Automation

| | Ymir | LangChain | CrewAI | MAF | DSPy | Agno | OpenAI SDK | Claude SDK |
|---|---|---|---|---|---|---|---|---|
| **Cron/scheduler** | ✅ Nornir (stateless spawn, 4 daily jobs) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Daily briefing** | ✅ Auto-generated | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Observation raven** | ✅ Huginn (daily fly) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

**Ymir wins on scheduling.** Nornir gives stateless cron jobs, daily briefings, and automated observation. The commercial harnesses have no built-in scheduling — you'd need to build it yourself.

### 6. Multi-Realm / Tenant Isolation

| | Ymir | LangChain | CrewAI | MAF | DSPy | Agno | OpenAI SDK | Claude SDK |
|---|---|---|---|---|---|---|---|---|
| **Tenant isolation** | ✅ Svartalfaheim (separate env, scoped ops) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Cross-tenant assets** | ✅ Midgard (shared) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Realm routing** | ✅ `.env.realm` per tenant | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

**Ymir wins on multi-tenant.** Svartalfaheim gives proper tenant isolation with separate env files and scoped operations. The commercial harnesses have no tenant concept at all.

### 7. Agent Factory & Lifecycle

| | Ymir | LangChain | CrewAI | MAF | DSPy | Agno | OpenAI SDK | Claude SDK |
|---|---|---|---|---|---|---|---|---|
| **Agent factory** | ✅ Smíðja (Völundr orchestrator) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Agent phases** | ✅ Multi-phase lifecycle | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Visualizer** | ✅ Smíðja UI (:8437) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Agent retirement** | ✅ Full lifecycle management | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

**Ymir wins on agent lifecycle.** Smíðja gives a full agent factory with phases, lifecycle management, and a visualizer. The commercial harnesses treat agents as one-off constructs.

### 8. Model Portability

| | Ymir | LangChain | CrewAI | MAF | DSPy | Agno | OpenAI SDK | Claude SDK |
|---|---|---|---|---|---|---|---|---|
| **Model portability** | ✅ Config-driven (pi/opencode) | ✅✅✅ | ✅ | ✅✅ | ✅✅ | ✅✅ | ❌ | ❌ |

**LangChain wins on model portability.** Ymir is configurable but defaults to a specific harness/model per agent. LangChain supports the broadest range of models out of the box.

---

## The Ymir Advantage — Summary

Ymir is not a framework you add to your project. **Ymir is the project.**

Where the commercial harnesses give you:
- A library to import
- Agents that run in your process
- No isolation, no audit, no memory, no scheduling

Ymir gives you:
- A complete platform
- Agents that run in isolated worktrees + Docker sandboxes
- Persistent memory (Mimirsbrunn), append-only audit (Runes), scheduling (Nornir), control plane (Hlidskjalf), agent factory (Smíðja), terminal panes (Þjazi), multi-tenant isolation (Svartalfaheim)

**Ymir is the difference between a hammer and a forge.**

The commercial harnesses are hammers — tools you pick up and use. Ymir is the forge — the entire operation, from raw material to finished product.

---

## When to Use What

| Use Case | Recommended | Why |
|----------|------------|-----|
| **Solo operator, full autonomy** | **Ymir** | Complete platform, isolation, audit, memory |
| **Team building agents into an app** | **LangChain** | Model portability, middleware composition |
| **Enterprise multi-agent with governance** | **CrewAI** | RBAC, audit trails, no-code builder |
| **Azure/Microsoft shop** | **MAF** | Azure integration, A2A/MCP interoperability |
| **LLM pipeline optimization** | **DSPy** | Automatic prompt compilation |
| **Managed agent deployment** | **Agno** | Batteries-included, fixed pricing |
| **OpenAI-only agents** | **OpenAI SDK** | Simplicity, native integration |
| **Claude reasoning + computer use** | **Claude SDK** | Best reasoning, desktop/browser automation |

---

*Ymir doesn't compete with these harnesses — it **envelops** them. Ymir can run agents built with any of these frameworks, but Ymir provides the platform they all lack: isolation, audit, memory, scheduling, and a complete control plane.*
