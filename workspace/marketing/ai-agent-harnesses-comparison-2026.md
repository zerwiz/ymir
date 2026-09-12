# AI Agent Harnesses — A Comparison Report

**Date:** 2026-09-12
**Author:** Brokk (Ymir)
**Scope:** Open-source and managed agent orchestration frameworks

---

## Executive Summary

The AI agent harness landscape has matured from experimental prototypes to production-grade platforms. Seven frameworks dominate the current market, each with a distinct philosophy:

| Harness | Origin | License | Languages | Maturity |
|---------|--------|---------|-----------|----------|
| **LangChain / LangGraph** | LangChain Inc. | MIT | Python, JS | Production |
| **CrewAI** | CrewAI Inc. | MIT | Python | Production (GA) |
| **Microsoft Agent Framework** (ex-Semantic Kernel / AutoGen) | Microsoft | MIT | Python, .NET, Java | Production (v1.0) |
| **DSPy** | Stanford NLP | MIT | Python | Production |
| **Agno** | Agno Inc. | MIT | Python | Production |
| **OpenAI Agents SDK** | OpenAI | MIT | Python | Production |
| **Claude Agent SDK** | Anthropic | MIT | Python | Production |

---

## 1. LangChain / LangGraph

**URL:** https://docs.langchain.com

### Philosophy
"Agent = Model + Harness." LangChain provides a minimal, highly configurable agent harness (`create_agent`) and a low-level orchestration framework (LangGraph) for advanced deterministic + agentic workflows.

### Architecture
- **LangChain Agents** — `create_agent()` with middleware composition (guardrails, retries, routing, tool policies)
- **LangGraph** — durable execution, human-in-the-loop, persistence, state graphs
- **Deep Agents** — batteries-included agent with auto context compression, virtual filesystem, subagent-spawning
- **LangSmith** — tracing, debugging, evaluation, and automated fix proposals

### Strengths
- **Broadest model support** — OpenAI, Anthropic, Google, Fireworks, Baseten, Ollama, Azure, AWS Bedrock, HuggingFace, OpenRouter
- **Middleware composition** — add only what you need
- **Durable execution** via LangGraph (checkpointing, persistence, human-in-the-loop)
- **LangSmith** is the industry-standard observability layer
- **JS + Python** — dual-language coverage

### Weaknesses
- Steep learning curve for LangGraph's state-graph paradigm
- Middleware chain can become opaque at scale
- LangSmith is a separate (paid) product

### Best For
Teams that need maximum flexibility, multi-provider model portability, and production-grade observability.

---

## 2. CrewAI

**URL:** https://crewai.com

### Philosophy
Role-based multi-agent orchestration with a visual builder (CrewAI Studio) and an enterprise Control Plane. "Know what to automate before you build."

### Architecture
- **Role-based agents** — each agent has a role, goal, and backstory
- **CrewAI Studio** — no-code visual editor, exportable to Python
- **CrewAI Discovery** — AI-powered use-case generator (patterns from billions of agent runs)
- **Control Plane** — real-time tracing, RBAC, audit trails, human-in-the-loop gates, PII redaction
- **Cognitive Memory** — built-in memory for agentic systems
- **AMP (Agent Management Platform)** — enterprise fleet management

### Strengths
- **Enterprise-first** — RBAC, audit trails, IAM, PII redaction, human-in-the-loop
- **No-code builder** — domain experts can prototype without writing code
- **Discovery** — AI suggests automation opportunities from your data
- **Strong enterprise adoption** — 65% of Fortune 500, PwC, DocuSign, General Assembly
- **Cognitive Memory** — built-in long-term memory
- **NVIDIA integration** — NemoClaw, self-evolving agents

### Weaknesses
- Tightly coupled to CrewAI's own runtime (less portable than LangChain)
- Enterprise features require paid tier
- Less flexible for single-agent use cases

### Best For
Enterprise teams building multi-agent workflows with governance, auditability, and non-technical stakeholders.

---

## 3. Microsoft Agent Framework (MAF)

**URL:** https://github.com/microsoft/agent-framework

### Philosophy
Enterprise-ready multi-agent orchestration with stable APIs, long-term support, and cross-runtime interoperability via A2A (Agent-to-Agent) and MCP (Model Context Protocol).

### Architecture
- **Successor to Semantic Kernel** — Semantic Kernel rebranded as MAF v1.0
- **Successor to AutoGen** — AutoGen is now in maintenance mode; migrate to MAF
- **A2A + MCP interoperability** — agents work across runtimes
- **Multi-provider model support** — OpenAI, Azure OpenAI, HuggingFace, NVIDIA, Ollama
- **Multi-language** — Python, .NET, Java

### Strengths
- **Enterprise-grade** — stable APIs, LTS commitment, Azure integration
- **Cross-runtime** — A2A protocol for distributed agents
- **Three-layer design** — Core (event-driven) → AgentChat (opinionated) → Extensions
- **MCP native** — first-class MCP server integration
- **Docker code execution** — sandboxed code execution
- **AutoGen Studio** — no-code GUI for prototyping

### Weaknesses
- AutoGen is in maintenance mode (migration required for new projects)
- Smaller community than LangChain
- .NET-first heritage may feel less Pythonic

### Best For
Microsoft/Azure shops, enterprises needing cross-runtime interoperability, teams migrating from AutoGen.

---

## 4. DSPy

**URL:** https://dspy.ai

### Philosophy
"Program, don't prompt." Declarative composition of LLM calls with automatic prompt optimization.

### Architecture
- **Signatures** — typed inputs/outputs (no prompt management)
- **Modules** — Predict, ChainOfThought, ReAct, etc. (same interface, different strategy)
- **Optimizers** — GEPA, MIPROv2, etc. (compile against a metric, auto-tune prompts)
- **In-production** — Shopify, Dropbox, AWS, JetBlue, Replit, Databricks, Nous Research

### Strengths
- **Automatic prompt optimization** — compile your program against a metric
- **No prompt engineering** — declare signatures, let the optimizer tune
- **Research-backed** — Stanford NLP, 38k GitHub stars, 7.5M+ monthly downloads
- **Cost reduction** — Shopify saw ~550× cost reduction
- **Fine-tuning + prompt optimization** — BetterTogether methodology

### Weaknesses
- Not a full orchestration framework — focused on the prompt/program layer
- No built-in multi-agent orchestration
- Smaller ecosystem than LangChain/CrewAI
- Steeper conceptual learning curve

### Best For
Research teams, teams optimizing LLM pipelines, anyone tired of prompt engineering.

---

## 5. Agno

**URL:** https://www.agno.com

### Philosophy
"The agent platform that builds itself." Self-driving agent platform with SDK, runtime (AgentOS), and Control Plane.

### Architecture
- **Agno SDK** — agents, teams, workflows, 100+ toolkits
- **AgentOS Runtime** — durable execution, distributed state, request isolation, resumable streaming
- **Control Plane** — traces, sessions, evals, usage metrics, audit logs, RBAC
- **30+ model providers** — native support, API quirks handled
- **Any framework** — run agents built with Agno, LangGraph, DSPy, Claude SDK

### Strengths
- **Batteries-included runtime** — deployment, auth, audit, observability all built-in
- **Fixed pricing** — no storage fees, no per-trace charges
- **Framework-agnostic** — run agents from other frameworks
- **Self-driving** — coding agents manage the full lifecycle
- **On-prem / local** — run anywhere you can run a container

### Weaknesses
- Newer player — less community than LangChain/CrewAI
- Tightly coupled to Agno's own runtime
- Smaller ecosystem of integrations

### Best For
Teams wanting a managed, full-stack agent platform with fixed pricing and on-prem deployment.

---

## 6. OpenAI Agents SDK

**URL:** https://platform.openai.com/docs/guides/agents-sdk

### Philosophy
Minimal, opinionated agent harness from OpenAI. Simple API for single and multi-agent systems.

### Architecture
- **Agent class** — model, tools, instructions
- **Handoffs** — structured agent-to-agent communication
- **Tracing** — built-in OpenTelemetry integration
- **File search, code interpreter, tool use** — native OpenAI features

### Strengths
- **Simplicity** — minimal API surface
- **Native OpenAI integration** — best-in-class for OpenAI models
- **Handoffs** — clean agent-to-agent delegation pattern
- **Built-in tracing** — OpenTelemetry

### Weaknesses
- **OpenAI-only** — no model portability
- Smaller ecosystem
- Less flexible for complex orchestration

### Best For
Teams already invested in OpenAI, teams wanting simplicity over flexibility.

---

## 7. Claude Agent SDK

**URL:** https://docs.anthropic.com

### Philosophy
Claude-native agent SDK with managed agents, sub-agents, and AG-UI protocol.

### Architecture
- **Claude Agent SDK** — programmatic agent definition
- **Managed Agents** — persistent sessions, per-conversation state
- **Sub-agents** — Haiku as sub-agent for Opus (cost optimization)
- **AG-UI protocol** — streaming replies, interactive generative UI
- **Computer Use** — desktop automation via Claude
- **Browser Use** — Playwright-backed browser automation

### Strengths
- **Best-in-class reasoning** — Claude's capabilities
- **Managed Agents** — persistent sessions, multi-platform (Slack, Teams, Discord, Telegram, WhatsApp)
- **Computer Use** — desktop automation
- **AG-UI** — interactive UI components
- **Cost optimization** — sub-agent pattern with Haiku

### Weaknesses
- **Anthropic-only** — no model portability
- Newer ecosystem
- Less community than LangChain

### Best For
Teams wanting Claude's reasoning capabilities, desktop/browser automation, multi-platform chat agents.

---

## Comparison Matrix

| Feature | LangChain | CrewAI | MAF | DSPy | Agno | OpenAI SDK | Claude SDK |
|---------|-----------|--------|-----|------|------|------------|------------|
| **Multi-agent** | ✅ LangGraph | ✅ Native | ✅ Native | ❌ | ✅ Teams | ✅ Handoffs | ✅ Sub-agents |
| **Model portability** | ✅✅✅ | ✅ | ✅✅ | ✅✅ | ✅✅ | ❌ | ❌ |
| **No-code builder** | ❌ | ✅ Studio | ✅ Studio | ❌ | ✅ Self-driving | ❌ | ❌ |
| **Enterprise governance** | LangSmith (paid) | ✅ Built-in | ✅ Built-in | ❌ | ✅ Built-in | ❌ | ❌ |
| **Durable execution** | ✅ LangGraph | ❌ | ✅ | ❌ | ✅ AgentOS | ❌ | ✅ Managed |
| **MCP support** | ✅ | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ |
| **A2A support** | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Computer use** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Browser use** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Prompt optimization** | ❌ | ❌ | ❌ | ✅✅✅ | ❌ | ❌ | ❌ |
| **Languages** | Py, JS | Python | Py, .NET, Java | Python | Python | Python | Python |
| **License** | MIT | MIT | MIT | MIT | MIT | MIT | MIT |
| **Community size** | 🟢 Largest | 🟢 Large | 🟡 Medium | 🟡 Medium | 🔵 Small | 🟡 Medium | 🟡 Medium |

---

## Recommendations

### For a solo operator / small team
- **DSPy** — if you want to optimize LLM pipelines without prompt engineering
- **LangChain** — if you need model portability and a large ecosystem

### For enterprise multi-agent systems
- **CrewAI** — if you need governance, audit trails, and non-technical stakeholders
- **Microsoft Agent Framework** — if you're in the Microsoft/Azure ecosystem

### For managed, full-stack deployment
- **Agno** — if you want a batteries-included platform with fixed pricing

### For OpenAI or Anthropic shops
- **OpenAI Agents SDK** — if you're all-in on OpenAI
- **Claude Agent SDK** — if you want Claude's reasoning + computer/browser use

### For research / optimization
- **DSPy** — the clear winner for automatic prompt optimization

---

## Key Trends (2026)

1. **A2A + MCP convergence** — Microsoft's Agent Framework leads with cross-runtime interoperability
2. **Enterprise governance** — RBAC, audit trails, and human-in-the-loop are table stakes
3. **No-code builders** — CrewAI Studio and AutoGen Studio democratize agent building
4. **Computer use** — Claude leads with desktop automation; others are catching up
5. **Prompt optimization** — DSPy's "program, don't prompt" philosophy is gaining traction
6. **Managed agents** — persistent sessions, multi-platform deployment (Slack, Teams, Discord)
7. **Cost optimization** — sub-agent patterns, model routing, and prompt tuning to reduce token spend

---

*Report compiled from public sources on 2026-09-12.*
