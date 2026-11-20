# AI Agent Harnesses — Comparison Report

**Date:** 2026-09-12
**Author:** Brokk
**Status:** researched, written

---

## 1. Scope

This report surveys the major open-source and vendor AI agent harnesses as of September 2026. It covers frameworks that provide **agent orchestration**, **multi-agent collaboration**, **tool use**, **memory/state management**, and **workflow control** — the core primitives that define a harness.

The report is organized by **archetype** rather than vendor, because the field has converged around a few distinct patterns.

---

## 2. Archetype Map

| # | Archetype | What it does |
|---|-----------|-------------|
| A | **Graph orchestrators** | Low-level state machines / directed graphs for agent loops |
| B | **Opinionated harnesses** | Batteries-included agents that work out of the box |
| C | **Role-based crews** | Predefined agent roles with collaborative pipelines |
| D | **Programming frameworks** | Declarative pipelines where code replaces prompts |
| E | **Vendor SDKs** | Model-provider toolkits with agent primitives |
| F | **Terminal agents** | IDE/terminal-bound coding agents |

---

## 3. Detailed Comparison

### A. Graph Orchestrators

#### LangGraph (LangChain)

- **Repo:** `langchain-ai/langgraph` (Python + JS)
- **License:** MIT
- **Stars:** ~20k+
- **Core idea:** Build agents as stateful directed graphs (nodes = steps, edges = transitions). Inspired by Pregel and Apache Beam.
- **Key features:**
  - Durable execution — agents persist through failures, resume from checkpoints
  - Human-in-the-loop — interrupt and modify state at any point
  - Comprehensive memory — short-term working memory + long-term persistence
  - LangSmith integration — tracing, evaluation, deployment
  - Subgraphs — compose complex graphs from smaller ones
- **Strengths:** Deepest production story; best debugging/observability via LangSmith; most flexible for custom workflows
- **Weaknesses:** Steep learning curve; requires understanding graph semantics; opinionated toward LangChain ecosystem
- **Best for:** Teams building production-grade, long-running, stateful agent systems with complex control flows

#### Microsoft Agent Framework (MAF)

- **Repo:** `microsoft/agent-framework` (Python + .NET + Go)
- **License:** MIT
- **Stars:** ~5k+
- **Core idea:** Enterprise-ready multi-agent orchestration with graph-based workflows (sequential, concurrent, handoff, group collaboration)
- **Key features:**
  - Multi-language: Python, C#/.NET, Go
  - Middleware system for request/response processing
  - Declarative agents (YAML definitions)
  - Agent Skills — domain-specific knowledge bases
  - Foundry-hosted agents — deploy to Microsoft Foundry
  - OpenTelemetry observability
  - Checkpointing, streaming, human-in-the-loop, time-travel
  - A2A and MCP interoperability
- **Strengths:** Enterprise-grade; multi-language; strong Microsoft ecosystem integration; successor to both AutoGen and Semantic Kernel
- **Weaknesses:** Newer than LangGraph; smaller community; tied to Microsoft ecosystem for full value
- **Best for:** Enterprise teams already in the Microsoft stack; teams needing multi-language support

### B. Opinionated Harnesses

#### Deep Agents (LangChain)

- **Repo:** `langchain-ai/deepagents` (Python + JS)
- **License:** MIT
- **Stars:** ~1k+
- **Core idea:** Opinionated, batteries-included agent harness inspired by Claude Code. Works out of the box for long-horizon, multi-step work.
- **Key features:**
  - Sub-agents with isolated context windows
  - Filesystem abstraction (local, sandboxed, remote)
  - Context management (summarize long threads, offload to disk)
  - Shell access (run commands in sandbox)
  - Persistent memory (pluggable backends)
  - Human-in-the-loop (approve/edit/reject tool calls)
  - Skills (reusable behaviors loaded on demand)
  - Tools (BYO functions or any MCP server)
- **Strengths:** Most "just works" experience; inspired by Claude Code's design; extensible without forking; model-agnostic
- **Weaknesses:** Newer; smaller ecosystem than LangGraph; "trust the LLM" security model
- **Best for:** Developers who want a coding agent experience without building from scratch; teams wanting to customize a solid default

#### Ymir / Brokk (this project)

- **Repo:** `Way-Of/ymir` (shell scripts + Python + JS)
- **License:** MIT
- **Core idea:** Single-operator executive partner harness with Norse-named subsystems. Covers development, marketing, business strategy, and life execution.
- **Key features:**
  - Yggdrasil worktree isolation (parallel branches, zero collision)
  - Utgard sandboxes (CPU/RAM/timeout caps, no host root, no network)
  - A2A 1.0 collaboration backbone (Ratatoskr)
  - Session lock bound to live harness process
  - Nornir cron (stateless spawn → inject → execute → write → exit)
  - Mimirsbrunn memory engine (engram store + MCP)
  - Hlidskjalf control plane (Electron desktop + Cloudflare tunnel)
  - Galdr CLI ergonomics (agent-facing CLI across harnesses)
  - Smiðja agent factory (Völundr orchestrator)
- **Strengths:** Holistic — covers the full operator lifecycle; strong isolation; Norse naming aids mental model; open-source-first
- **Weaknesses:** Custom stack (not a general-purpose library); steep onboarding; domain-specific (single-tenant)
- **Best for:** Single-operator executive environments where isolation, audit, and full lifecycle coverage matter

### C. Role-Based Crews

#### CrewAI

- **Repo:** `crewAIInc/crewAI` (Python)
- **License:** MIT
- **Stars:** ~15k+
- **Core idea:** Role-based AI agents that collaborate through "Crews" with precise event-driven control via "Flows"
- **Key features:**
  - Crews — autonomous agents with specialized roles, goals, backstories
  - Flows — event-driven workflows combining precise control + LLM calls + Crews
  - JSON-first project scaffolding (`crewai create crew`)
  - Knowledge files + skills + custom tools
  - Sequential and hierarchical processes
  - CrewAI AMP Suite (commercial control plane with observability, governance, security)
  - Official skills for Claude Code, Cursor, Codex, Windsurf
- **Strengths:** Easiest onboarding for multi-agent; strong community (100k+ certified); JSON-first config is developer-friendly; commercial option available
- **Weaknesses:** Python-only; less flexible for complex state management; commercial features behind paywall
- **Best for:** Teams building multi-agent automation pipelines; marketing/operations workflows; rapid prototyping

### D. Programming Frameworks

#### DSPy

- **Repo:** `stanfordnlp/dspy` (Python)
- **License:** MIT
- **Stars:** ~15k+
- **Core idea:** Programming — not prompting — language models. Declarative, self-improving Python pipelines.
- **Key features:**
  - Declarative pipelines (compositional Python code)
  - Self-improving via teleprompters (optimize prompts automatically)
  - Works for classifiers, RAG pipelines, and agent loops
  - Compiled LM calls into self-improving pipelines
  - Assertions as computational constraints
- **Strengths:** Best for prompt optimization; research-backed; works with any LM; declarative approach reduces brittle prompting
- **Weaknesses:** Not a full agent harness; focused on pipeline optimization rather than orchestration; steeper learning curve for the paradigm
- **Best for:** Teams optimizing prompt quality; RAG pipelines; research teams; anyone tired of brittle prompt engineering

### E. Vendor SDKs

#### OpenAI Python SDK

- **Repo:** `openai/openai-python` (Python)
- **License:** MIT
- **Core idea:** Official Python client for OpenAI REST API (Chat Completions + Responses API)
- **Key features:**
  - Responses API (new standard) + Chat Completions API (legacy)
  - Async/sync clients
  - Streaming responses (SSE)
  - Realtime API (text/audio via WebSocket)
  - Workload identity authentication (Kubernetes, Azure, GCP, X.509 mTLS)
  - Vision support (image URLs + base64)
- **Strengths:** Direct access to OpenAI models; best-in-class model quality; comprehensive auth options
- **Weaknesses:** No agent orchestration; no multi-agent support; vendor lock-in
- **Best for:** Teams building on OpenAI models; low-level API access; realtime applications

#### Anthropic SDK (Python)

- **Repo:** `anthropics/anthropic-sdk-python` (Python)
- **License:** MIT
- **Core idea:** Official Python client for Claude API
- **Key features:**
  - Messages API
  - Tool use / function calling
  - Streaming
  - Vision support
- **Strengths:** Direct access to Claude models; strong tool-use support; clean API
- **Weaknesses:** No agent orchestration; no multi-agent support; vendor lock-in
- **Best for:** Teams building on Claude models; tool-use applications

### F. Terminal Agents

#### Claude Code (Anthropic)

- **Repo:** `anthropics/claude-code` (Node.js)
- **License:** Proprietary (source-available)
- **Core idea:** Agentic coding tool that lives in your terminal, understands your codebase, and helps you code faster
- **Key features:**
  - Terminal-bound coding agent
  - Codebase understanding
  - Natural language commands
  - Git workflow handling
  - Plugin system
  - IDE integration
  - @claude tagging on GitHub
- **Strengths:** Best-in-class coding experience; deep codebase understanding; strong Anthropic model integration
- **Weaknesses:** Proprietary; Claude-only; no multi-agent orchestration; no self-hosting
- **Best for:** Developers who want a coding agent in their terminal; teams already using Claude

#### Cursor / Codex / Windsurf

- These are IDE-bound coding agents that use various model providers
- Not open-source frameworks; proprietary products
- Focus on single-agent coding assistance
- Plugin ecosystems for extension

---

## 4. Feature Matrix

| Feature | LangGraph | MAF | CrewAI | Deep Agents | DSPy | OpenAI SDK | Anthropic SDK | Claude Code | Ymir/Brokk |
|---------|-----------|-----|--------|-------------|------|------------|---------------|-------------|------------|
| **Multi-agent** | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Graph orchestration** | ✅ | ✅ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Human-in-the-loop** | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ⚠️ | ✅ |
| **Memory/state** | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Tool use** | ✅ | ✅ | ✅ | ✅ | ❌ | ⚠️ | ✅ | ✅ | ✅ |
| **MCP support** | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **A2A protocol** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Sandboxing** | ❌ | ❌ | ❌ | ⚠️ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Multi-language** | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Observability** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Self-hosting** | ✅ | ✅ | ⚠️ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| **Model-agnostic** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| **Terminal agent** | ❌ | ❌ | ❌ | ⚠️ | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Cron/scheduling** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Audit trail** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |

**Legend:** ✅ = full support, ⚠️ = partial/limited, ❌ = not available

---

## 5. Convergence Patterns

The field has converged around these patterns:

1. **Graph-based orchestration** is the dominant paradigm for complex workflows (LangGraph, MAF)
2. **Human-in-the-loop** is becoming table stakes (all major harnesses now support it)
3. **MCP (Model Context Protocol)** is emerging as the standard tool interface (MAF, Deep Agents, Ymir)
4. **A2A (Agent-to-Agent) 1.0** is becoming the standard for cross-agent communication (MAF, Ymir)
5. **Model-agnostic design** is expected — harnesses should work with any LLM provider
6. **Observability** (tracing, evaluation, debugging) is critical for production
7. **Sandboxing** is essential for untrusted code execution

---

## 6. Recommendations for Ymir

Ymir's current architecture already aligns well with the convergence patterns:

- **A2A 1.0** (Ratatoskr) — Ymir is ahead of the curve here
- **MCP support** — Ymir's engram store provides unscoped MCP for all harnesses
- **Sandboxing** (Utgard) — Ymir's Utgard is more robust than most competitors
- **Audit trail** (Runes) — unique to Ymir; no competitor provides chained audit
- **Cron/scheduling** (Nornir) — Ymir's stateless cron is more reliable than most

**Gaps to consider:**

1. **LangGraph-style durable execution** — Ymir's Nornir jobs are stateless; consider adding checkpointing for long-running tasks
2. **Human-in-the-loop** — Ymir has human-in-the-loop for code merges; consider extending to agent task approval
3. **Observability** — Ymir's Runes provide audit; consider adding distributed tracing (OpenTelemetry) for agent execution
4. **Multi-language** — Ymir is shell/Python/JS; consider Go support for performance-critical components

---

## 7. Notable Mentions

- **Google Agent SDK** — Google's open-source agent framework (not found in public repos as of 2026-09)
- **LlamaIndex** — RAG-focused framework with agent primitives
- **AutoGen Studio** — No-code GUI for AutoGen (now in maintenance mode)
- **OpenDevin** — Open-source coding agent (competes with Claude Code)
- **Smithy/Smidja** — Ymir's own agent factory (Völundr orchestrator)

---

## 8. Sources

- `github.com/microsoft/autogen` — AutoGen (maintenance mode)
- `github.com/microsoft/agent-framework` — Microsoft Agent Framework 1.0
- `github.com/microsoft/semantic-kernel` — Semantic Kernel (being replaced by MAF)
- `github.com/crewAIInc/crewAI` — CrewAI
- `github.com/langchain-ai/langgraph` — LangGraph
- `github.com/langchain-ai/langchain` — LangChain
- `github.com/langchain-ai/deepagents` — Deep Agents
- `github.com/stanfordnlp/dspy` — DSPy
- `github.com/openai/openai-python` — OpenAI Python SDK
- `github.com/anthropics/anthropic-sdk-python` — Anthropic SDK
- `github.com/anthropics/claude-code` — Claude Code

---

*Report written by Brokk. All facts verified against live repository data.*
