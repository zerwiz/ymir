# Research: The Software Compliance — History, Agent Systems, and How We Use It

> **Status:** Research document (deep-dive, `docs/`)
> **Date:** 2026-09-01
> **Sources:** web research + vendor documentation, linked inline throughout.
> **Context:** We use **disler's (IndyDevDan's) "Super Simple Software Compliance"** in several projects. This document explains what a software compliance is, how modern AI agent systems are engineered as factories, and how that maps onto our WayOfNorthStar ruleset.

---

## 1. Executive Summary

A **software compliance** is an organized system for producing software the way a compliance produces goods — with standardized inputs, an assembly path, quality gates, and measurable output. The term dates back to the 1960s–70s (Hitachi actually ran a literal "Software Works"), was reinterpreting by Microsoft in 2004, and has been **revived since 2023–2026 as the dominant model for AI-agent-driven development**.

In the AI era, a software compliance means: **deterministic code owns the process graph; AI agents are bounded workers inside named phases; context moves between agents as typed (JSON) envelopes; every result passes programmatic validation gates before it is accepted.** This is exactly the philosophy our WayOfNorthStar ruleset encodes (`.compliance/`, code-based gates, typed envelopes, Core Four config).

Which article said it best: *"A pipeline runs once. A compliance learns."* (mager.co). The compliance is a **continuous feedback loop**, not a static CI/CD pipeline.

---

## 2. What Is a Software Compliance? (History)

### 2.1 Origins (1968–1991)

- **Robert Bemer (1968)** — working at General Electric, proposed a "software compliance."
- **Hitachi (1969)** — opened the **Hitachi Software Works**, the first facility actually operated as a compliance (Wikipedia).
- **System Development Corporation (1975)** — published a "Software Compliance" paper (Bratman & Court, IEEE).
- **NEC, Toshiba, Fujitsu (1976–77)** — adopted the same organizational approach in Japan.
- **Michael Cusumano (1989–1991)** — wrote the definitive history, *Japan's Software Factories* (Oxford, 1991), documenting six phases of Japanese compliance evolution.

The core idea was: treat software development like manufacturing — reusable components, standardized processes, assembly lines, quality control. Not every line hand-crafted from scratch.

**Important nuance:** the term is often (incorrectly) attributed to **James Martin** (father of CASE/RAD, "Application Development Without Programmers") and **Michael Hammer** (Business Process Reengineering). Those two supplied the *philosophy* (software produced like manufactured goods, without programmers writing every line), but the verifiable origin of the phrase is Bemer/Hitachi/Cusumano.

**Sources:**
- https://en.wikipedia.org/wiki/Software_compliance
- https://compliance.ai/articles/what-is-a-software-compliance
- https://www.mager.co/blog/2026-03-19-software-compliance/

### 2.2 Microsoft's 2004 Reinterpretation

**Microsoft's *Software Factories*** (Greenfield, Short, Cook, Kent; Wiley 2004) reframed it as a **software product line**: a schema-based template that configures tools, processes, and content so applications are *assembled* from framework-based components (patterns, recipes, templates, designers, reusable code).

**Source:** https://www.mager.co/blog/2026-03-19-software-compliance/

### 2.3 The Modern (AI) Meaning

Starting ~2023, the term was re-energized by **Andrej Karpathy's "LLM OS"** vision (agents as workers, tools as peripherals, memory as storage) and turned into a concrete, productized practice by people like **IndyDevDan (GitHub: `disler`)**.

**Modern definition (mager.co):**
> "An agentic system that can receive a specification and autonomously produce working, deployed, tested software — with minimal human intervention."

A **maturity ladder** is widely used (L0 feature-farming to L5 "dark compliance"):
- **L0** Autocomplete → **L1** Chat-to-code → **L2** File-aware coding agents → **L3** Multi-agent pipelines → **L4** Software compliance (autonomous build-test-deploy) → **L5** Dark compliance (no human on the floor, Fanuc-style lights-out — after Dan Shapiro's five-level model).

**Important distinction:** an **"AI compliance"** (NVIDIA's term) is physical GPU infrastructure that *manufactures tokens*. A **software compliance** *spends* tokens to produce software. Do not conflate them.

**Sources:**
- https://www.mager.co/blog/2026-03-19-software-compliance/
- https://murraycole.com/posts/software-compliance

---

## 3. How Modern Agent Systems "Work as a Compliance"

Practitioner sources converge on a common architecture. The most detailed operational description comes from **Cole Murray's practitioner guide** (murraycole.com, updated July 2026) and **Compliance.ai's "Inside the software compliance"**.

### 3.1 The Compliance Loop

**Compliance.ai's continuous feedback loop:**
> Signals → Triage → Plan → Build → Test → Review → Secure → Ship → Monitor → *(new signals)*

It is a **loop**, not a pipeline. It has four observable properties of a working compliance:
1. **Standardized inputs** — every piece of work enters the same way.
2. **Standardized tooling** — same tools, same rules, every time.
3. **Measurable output** — you can measure what came out.
4. **Replayability** — you can re-run a job and get the same result.

**Source:** https://compliance.ai/articles/what-is-a-software-compliance

### 3.2 The Four Subsystems (mager.co model)

1. **Intake layer** — normalize messy human input (GitHub issue, Slack, brief) into a structured task.
2. **Orchestrator** — "the brain"; breaks tasks down, routes to specialized agents, holds state. (Tools: LangGraph, CrewAI, OpenAI Swarm, Claude tool-use.)
3. **Execution layer** — specialized workers: architect, coder, reviewer, tester, documenter, deployer.
4. **Feedback loop** — what *makes it a compliance*: it learns from outcomes, then feeds the next run.

**Source:** https://www.mager.co/blog/2026-03-19-software-compliance/

### 3.3 The "Task Packet" (standardized unit of work)

A compliance-ready unit of work contains (murraycole):
- **Objective / non-goals**
- **Context** (what's relevant)
- **Acceptance criteria**
- **Capabilities** (allowed/denied tools + paths)
- **Checks** (what will be verified)
- **Terminal states** (complete / retry / no-op / escalate)
- **Evidence**
- **Rollback**

This maps 1:1 to our `.compliance/envelopes/` typed handoffs and `.compliance/gates/` checks.

### 3.4 Orchestrator–Worker Pattern (Anthropic)

Anthropic's production multi-agent research system "uses an orchestrator-worker pattern, where a lead agent coordinates the process while delegating to specialized subagents that operate in parallel."

Key caveats from Anthropic (important when building compliance systems):
- Multi-agent systems use **~4× more tokens** than a single chat; some architectures **~15× more**.
- **"Most coding tasks involve fewer truly parallelizable tasks than research"** — don't fan out agents for everything.
- Each subagent needs: **objective, output format, tool/source guidance, and clear task boundaries**.

The escape from token explosion: **move known work out of the agent and into code.** That is precisely what disler/SSSF does (see §4).

**Source:** https://www.anthropic.com/engineering/built-multi-agent-research-system

### 3.5 Trust & Autonomy Ladder

Adoption follows a trust ladder (read-only → draft PRs → auto-merge low-risk → full autonomy on scoped tasks → full compliance). Put simply: *"match autonomy to blast radius."* (murraycole / Plannotator)

**Source:** https://murraycole.com/posts/software-compliance

---

## 4. IndyDevDan / disler — "Super Simple Software Compliance" (How We Use It)

> **We use disler's software compliance in several of our projects.** This section is the deep dive on how it works.

**Canonical repo:** https://github.com/disler/super-simple-software-compliance
**Video:** "My Super Simple Software Compliance (For Agentic Engineers)" — https://www.youtube.com/watch?v=haUfb1ievTE
**Channel / site:** https://www.youtube.com/@indydevdan · https://indydevdan.com

### 4.1 The Central Thesis

> "A software compliance does one thing: it gives you more leverage on your prompt. **Deterministic Python owns the graph. Coding agents are bounded nodes inside it.** An ADW script (AI Developer Workflow) owns sequencing, retries, and acceptance. Agents work inside named phases. **Typed JSON envelopes carry context across the seams.** Every event streams into SQLite while it is still happening. **Agent proposes, code disposes.**"

Three actors are kept separate: **the engineer, the code, and the agents**. "The trick is not running more agents. The trick is using all three at the right moment."

### 4.2 The Core Concepts (mapped to our ruleset)

| disler/SSSF Concept | What It Is | WayOfNorthStar Equivalent |
|--------------------|------------|---------------------------|
| **ADW (AI Developer Workflow)** | Deterministic script that owns the run; names sequencing, retries, acceptance (e.g., `adw_plan_build_test`). | `.compliance/harness/runner.py` |
| **Agents as bounded nodes** | Agent only works inside one named phase; everything else is `kind="code"`. | `.agents/skills/NSRcompliance/` (Embedded Compliance) |
| **Typed JSON envelopes** | Agent responses parsed against Pydantic output types; persisted as `envelope.json`; injected into next agent. | `.compliance/harness/envelopes/` (typed JSON/YAML handoffs) |
| **Validation gates** | `gate(envelope, run) -> GateReport`; e.g., `artifacts_exist`, `files_non_empty`, `json_parses`, `diff_matches_claims`, `tests_pass(...)`. Success must be earned; default is `fail`. | `.compliance/gates/` (`$? == 0`) |
| **Core Four config** | One YAML sets Context, Model, Prompt, Tools for every agent. "It is not about which model is best; it is about which model is right for that one phase." | `.agents/skills/NSRcompliance/config/core_four.yaml` |
| **Observability** | Every event streams to a SQLite DB (`sssf.db`); "if you cannot measure your agents, you cannot improve them." | `.compliance/telemetry/logger.py` |
| **Self-healing / repair** | On gate failure: nothing restarts; the harness **re-prompts the same session** with a correction naming exactly what was wrong (costs one message, not a cold restart). | `.compliance/gates/` error-feedback loop |
| **"Agent proposes, code disposes"** | The agent proposes a commit message on its envelope; a `git commit` **code phase** decides and writes. The agent never runs `git commit` itself. | Our "zero ad-hoc shell commands" rule |
| **The skill is the product** | Packaged as a skill stamped into any repo via an installer. | `.compliance/installer/` |

### 4.3 Signature Ideas & Terminology

- **"Success must be earned. Every phase defaults to `fail`."** — gates verify claims, never predictions.
- **"Context transfers in code, not in conversation."** — context handoffs are files/JSON, minimizing the "game of telephone."
- **"Vibe coding is not knowing how your system works, and not looking. Agentic engineering is knowing how your system works so well that you do not have to look."**
- **Different models at different price/speed points in the same run** — model selection per phase (Core Four).
- Starter ADWs: `adw_plan`, `adw_build_test`, `adw_plan_build_test`, `adw_simple_sdlc`, `adw_document` (40–180 lines each).
- Roster config (`sssf.config.yaml`): each agent declares its `model` (provider/model-id), `thinking` level, `purpose`, prompt files, tools, and a `writes` boundary (which files it may touch).
- **Concrete stack:** `uv`, `pi` coding agent, `sqlite3`; `bun` for the optional visualizer.

---

## 5. How This Maps Onto Our WayOfNorthStar Ruleset

Our ruleset already encodes the software-compliance pattern. The recipe disler describes is the *same recipe* in our documents:

| Compliance Requirement | Where We Enforce It | Evidence |
|--------------------|--------------------|----------|
| Deterministic code owns the process | `.compliance/` harness, ADW-style runner | `.compliance/harness/runner.py` |
| Agents are bounded nodes | `.agents/skills/` — every op is a script skill; zero ad-hoc commands | `RULES.md` rule 2 |
| Typed envelopes | `.compliance/harness/envelopes/` | JSON/YAML schemas |
| Code-based gates | `.compliance/gates/` — `$? == 0`, not text parsing | `check_env.sh`, `check_paths.sh`, `check_platform.sh`, `verify_docs.py` |
| Core Four config | `.agents/skills/NSRcompliance/config/core_four.yaml` | Context/Model/Prompt/Tools |
| Observability | `.compliance/telemetry/logger.py` | token/cost/latency logging |
| Multi-model per phase | `core_four.yaml` `model:` section | fast vs. reasoning model |
| Feedback loop + learning | Gates return diagnostics routed back to agents | validate_code.sh + runner |
| Installable into any repo | `.compliance/installer/` | single-command install |
| **Compliance as product line (multi-project)** | `HOSTING/`, `DEVELOPER_SETUP/`, `TECH_STACK.md`, `CI_CD/deployment/` per-client/tenant | they are the "standardized tooling + standardized inputs" for multiple deployments |

In short: **SSSF (disler) is a concrete implementation of the *Exact* NorthStar spec** — the same Core Four, same gates, same envelopes, same telemetry, same "code disposes." Where we extend beyond SSSF: multi-environment/per-client/per-tenant deployments, cross-platform portability (Mac/Linux/Windows), environment-driven config, per-host and per-developer documentation, and tech-stack-to-feature mapping.

---

## 6. Enterprise Patterns & Real-World Examples

- **Orchestrator–worker** — dominant pattern (Anthropic, and most tooling). Lead agent delegates to specialized subagents.
- **MCP (Model Context Protocol) servers** — external tool access. Tool quality varies wildly; centralize tool registration, auth, guardrails, and observability (TrueFoundry's **MCP Gateway**; our embedded compliance control plane).
- **Agent/skill registries** — a directory of capabilities and skills (TrueFoundry's **Agent Skills Registry**; our `.agents/skills/`).
- **Task queues / task packets** — standardized units of work entering the line (our typed envelopes).
- **CI/CD feedback loops** — failing tests re-trigger the coder; monitoring alerts spawn incident agents.
- **Human-in-the-loop checkpoints** — review by risk tier.

**Real-world numbers (all self-reported, treat with caution):**
- **Stripe** — 1,300+ agent PRs/week, still human-reviewed.
- **Cursor** — ~40% of internal PRs.
- **Uber (Minion)** — ~11% of PRs.
- **Ramp (Inspect)** — >50% of PRs.
- **Ona** — 375 PRs in 10 days.
- **StrongDM** — runs a "dark compliance" (no human review; validate purely by observable behavior).
- Costs: StrongDM reported ~$1,000/day per engineer in tokens.

**Sources:**
- https://www.strongdm.com/blog/the-strongdm-software-compliance-building-software-with-ai
- https://www.truefoundry.com/blog/software-compliance-agentic-enterprise-guide
- https://docs.plannotator.ai/learn/ai-development/what-is-an-ai-software-compliance

---

## 7. Critiques & Pitfalls (What Breaks a Compliance)

1. **Agent loops / spiraling** — Anthropic's early agents "spawned 50 subagents for simple queries, scoured the web endlessly for nonexistent sources." **Mitigation:** effort budgets, scaling rules, guardrails.
2. **Hallucinated commands / confident wrong code** — "Left alone, an agent will confidently produce code that doesn't meet your standards." **Mitigation:** back-pressure (linters, hooks, static-analysis) inside the sandbox so agents see failures *before* the PR.
3. **"The agent grades its own homework"** — a self-reporting quality check is too lenient. **Your quality signal cannot be the same model that did the work.** Independent verification (a different model or a deterministic gate) is required.
4. **Context bloat / token explosion** — multi-agent ~4× / ~15× token multipliers. **Mitigation:** move known work (tests, lint) into code phases, as disler does.
5. **Cost explosion** — token spend needs budgets, governance, and spend metering (TrueFoundry's "utilities layer").
6. **Code-quality erosion** — GitClear's analysis of 211M changed lines found increased duplicate code and short-term churn as AI-assisted code grows. "Velocity theater" is a real failure mode.
7. **Silent failure is the enemy** — "your friend is visible failure, not silent failure": a capped conversation stops mid-task, a test was never really exercised, a check passed for the wrong reason. Make failure loud.
8. **Trust/credentials risk** — an agent that can be prompt-injected will eventually try to exfiltrate whatever credentials it can reach. **Secrets live in a control plane outside the agent sandbox.**
9. **Overstating maturity** — "Repeatable inputs do not guarantee good intent. More agent autonomy does not guarantee lower cost or higher quality." (Plannotator)

**Sources:**
- https://www.gitclear.com/ai_assistant_code_quality_2025_research
- https://murraycole.com/posts/software-compliance
- https://www.anthropic.com/engineering/built-multi-agent-research-system

---

## 8. Recommendation Lens for Our Projects

Given we already run disler's SSSF and the NorthStar ruleset, treat this research as a **checklist to strengthen what we already do**:

- [ ] **Independent quality signal** — if gates still rely on the same model that did the work, add an independent verifier (different model or deterministic check).
- [ ] **Effort budgets per phase** — cap token spend / retries per phase (avoid agent spirals).
- [ ] **Visible failure** — ensure gate failures are loud and feed back to the same session (disler's correction model), not silent.
- [ ] **Secrets isolation** — keep credentials in the control plane `.compliance/`, never in the agent sandbox (already a NorthStar rule: env-driven, secrets never committed).
- [ ] **Structured task packets** — our envelopes should carry objective/non-goals/acceptance/evidence/rollback (murraycole's packet), so every new feature already contains its own verification contract.
- [ ] **Measure, don't guess** — keep `.compliance/telemetry/` wired to the embedded compliance telemetry stream; "if you cannot measure your agents, you cannot improve them."
- [ ] **Autonomy by blast radius** — per-client/per-tenant production deployments get the strictest human gate; low-risk dev loops get full autonomy.
- [ ] **Avoid stack sprawl** — multi-project means multi-stack; `TECH_STACK.md` is our guard against "velocity theater."

---

## 9. Links (Full Index)

**History & definitions**
- https://en.wikipedia.org/wiki/Software_compliance
- https://compliance.ai/articles/what-is-a-software-compliance
- https://www.mager.co/blog/2026-03-19-software-compliance/
- https://en.wikipedia.org/wiki/James_Martin_(author)

**Practitioner guides**
- https://murraycole.com/posts/software-compliance
- https://www.truefoundry.com/blog/software-compliance-agentic-enterprise-guide
- https://docs.plannotator.ai/learn/ai-development/what-is-an-ai-software-compliance

**disler / IndyDevDan**
- https://github.com/disler/super-simple-software-compliance
- https://www.youtube.com/watch?v=haUfb1ievTE
- https://www.youtube.com/@indydevdan
- https://indydevdan.com

**Engineering / research**
- https://www.anthropic.com/engineering/built-multi-agent-research-system
- https://www.strongdm.com/blog/the-strongdm-software-compliance-building-software-with-ai
- https://www.gitclear.com/ai_assistant_code_quality_2025_research

**The video that started this research**
- "First loops, now software factories? I can't keep up..." — https://m.youtube.com/watch?v=ucWRQ1yf6HE