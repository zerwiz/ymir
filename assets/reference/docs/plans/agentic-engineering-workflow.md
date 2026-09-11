# Agentic Engineering Workflow — Ex-NASA Dev (Dex Horthy) Framework

**Source**: David Ondrej podcast interview with Dex Horthy (coined "context engineering")  
**Date**: August 2026  
**Reference**: YouTube `xgkjtF89-44`, OpenClawDatabase deep-dive, FrontierModels summary, Zovi AI, LinkedIn analysis by Wesley Stander

---

## Executive Summary

> **"Agents can solve problems. They cannot, yet, write maintainable code without you."** — Dex Horthy

The core thesis: **structured pre-coding design phases** are the difference between vibe-coding toys and shipping production software. The step everyone skips is **Program Design** — not product specs, not architecture diagrams, but the actual call stack, type signatures, and file placement decided BEFORE the agent writes code.

> **The failure that produced this system**: Dex's team ran a "light software factory" in July 2025 — reviewing plans and tickets, **never reading the code** — for three months. Then a bug hit a shipping desktop app. Several frontier models in a council kept diagnosing the wrong cause and shipping fixes that didn't fix it. Resolving it meant going back into a codebase nobody had read for three months and working through unfamiliar, sloppy code for weeks while users were angry. **His thesis: the odds of this happening to you are higher than the odds that models get good enough before it does.**

---

## The Four-Layer Program Design System

### Layer 1 — Product (What & Why)
- **Problem statement**: What user problem are we solving?
- **Success metrics**: How will we measure it? (Quantitative, not vibes)
- **Announcement post** (Amazon practice): Write the launch blog post *before* building the feature — forces you to explain value to a user first
- **HTML mockups**: Prototype relevant views as plain HTML at this stage
- **Zero tech**: No databases, no schemas, no architecture

### Layer 2 — System Architecture (How Services Fit)
- Service topology and boundaries
- Request/response flow diagrams
- New endpoints and their contracts
- New tables and query outlines
- **Note**: Most experienced teams already operate at this level — people are generally comfortable designing architecture back-and-forth with a model

### Layer 3 — Program Design ⚠️ THE SKIPPED LAYER
**One level below architecture — this is where the agent makes decisions you will dislike later.**

- **File locations**: Where does each piece live?
- **Types and method signatures**: Exact interfaces before implementation
- **Call stack visualization**: What does the execution path look like when this runs?
- **Test shapes**: What will the tests look like? (Not implementation — test *signatures*)
- **Deliberately NOT implementation detail**

> Dylan Mulroy (Cloudflare): *"A good plan with the tests and the call stack. The point is that [the agent] will otherwise make silently, and that [you] may not like."*

### Layer 4 — Vertical Slices / Tracer Bullets (Execution Order)
**Models default to building horizontally** — entire database layer → entire service layer → entire API → entire frontend — leaving **nothing testable until thousands of lines are done**.

**Vertical slice = thin and end-to-end**:
1. Mock the API endpoint
2. Stub the frontend
3. Wire them together
4. *Then* add migrations, business logic, error handling

> **Dex**: "I have never seen a model do this without a human telling it the order."

---

## Context Engineering Principles

### Right Tokens, Not More Tokens
- **"Dumb zone" at ~50% context is real** — for models AND humans
- Compaction and handoffs matter
- Don't token-max while your bottleneck is code review

### Make Structural Decisions Early
- In the context window where they are **cheap** and the model is **sharpest**
- One 43k-token planning session with PRD read in and most endpoint/flow decisions already made > re-steering a 3,000-line diff later
- Structural decisions = file placement, type signatures, call stack, test strategy
- **Prompt for output in code blocks** — types and method signatures — because those are fast for a human to scan and judge right-or-wrong (review takes minutes, not hours)

### The Victor Tali Trick (Pre-Mortem)
> After a change, ask the model: *"While working on this, which choices did you make that you're not confident of?"*

Dex's system does this **before the run instead of after** — surfacing uncertain choices during program design, not post-hoc.

---

## Measurable Goals Beat Instructions

> **Both speakers converge**: an agent given a number to move will go much further than one given a description.

- **Dex calls it "back-pressure"**: LLM-as-judge is acceptable, but a **real metric tied to the business** (conversion rate, resource-reduction target for a CUDA kernel) lets an agent run experiments, check data daily, and pick a winner
- **David's framing**: *"If you can tell it a measurable output, the agent will move mountains for you."*

---

## The Working Workflow for Real Teams

```
┌─────────────┐   ┌────────────────┐   ┌──────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  PRODUCT    │──▶│  ARCHITECTURE  │──▶│  PROGRAM DESIGN  │──▶│  VERTICAL SLICES │──▶│  YOU READ LOGIC │
│  (problem,  │   │  (services,    │   │  (files, types,  │   │  (thin e2e,     │   │  (or at least   │
│   metrics,  │   │   flow, tables)│   │   signatures,    │   │   test as you    │   │   the logic)    │
│   announcement)    │              │   │   call stack,    │   │   go)            │   │                 │
└─────────────┘   └────────────────┘   │   tests)         │   └─────────────────┘   └─────────────────┘
                                       └──────────────────┘
```

### When to Apply Each Mode

| Context | Approach |
|---------|----------|
| **Pre-PMF / MVP** | Vibe faster — ship, learn, iterate (Dex calls four-layer "overkill" here) |
| **~5+ engineers, paying users, 6-month maintenance horizon** | **Start earning its keep** — full four-layer discipline |
| **Enterprise fintech / regulated** | **This isn't optional** — a bug costs $1M+ |

---

## Strategic Positioning

### You're Not Competing With Google/Anthropic
- You're competing with **a product manager at Anthropic** with red tape and a roadmap
- Large orgs have rules, slow movement — a small founder/team who **gives a damn** can out-execute most internal teams
- OpenAI/Anthropic work hard to keep "startup energy" — but they still have PM overhead

### The Future Isn't "Agents Replace Engineers"
> **"It's engineers who know where to stay in the loop, and where to let the model cook."**

### Death of the Traditional PR Model
- **PR model breaks down** when agents generate tens of thousands of lines faster than any human can review
- **Running multiple model reviewers (Codex + Opus) in parallel** emerges as a practical proxy for human code trust at scale

---

## Dex's Practical Habits (No-Framework Approach)

### Prompting Like a Slack Message to a Senior Engineer
> *"The number one thing that's important for me when writing prompts is where does the information come from that the agent has access to to interpret what I mean."*

**Two sources only**: Training data + Context window

**Mental model**: Senior engineer who's seen it all, hooded, dropped at a desk with:
- Codebase
- Browser
- Terminal
- Text editor
- A prompt: "Implement this"

**If your prompt/context/AGENTS.md doesn't contain enough info → can't turn shitty prompt into good output**

### His Prompt Template (Porting Puck to CLI)
```
"Look at how it's implemented in the web UI. This is what you should take as the standard.
I want to port this to our CLI.
I think we should have a 'puck open' command. We have a command palette in our CLI that opens the puck for it.
That shows up in the sidebar. We have a sidebar in the TUI.
I think we should have a 'puck clear' thing...

[Research phase]
Research how it's implemented. Look at the news post. Document how it works in the doc.
Sit down and think about it. Compile what you learn.

[Design phase]
Come up with a good idea for how to translate it.

[Execution phase]
Use sub-agents for implementing this (GPT models).
Present me with the results."
```

### Sub-Agent Delegation
- Uses **sub-agents (GPT models)** for implementation grunt work
- Expensive — "scares me" — but isolates implementation from design
- Main agent = architect/reviewer; sub-agents = builders
- **Running Codex and Opus in parallel** as multiple reviewers

### Validation Loop
- **End-to-end tests > local dev environment** for validation
- Runs against live dev servers (orbs/portals)
- Spot-checks architectural choices after tests pass
- "If it did end-to-end tests, and I read through it, and I kind of agree with the architectural choices... what more do I need my local dev env for?"

---

## Critical Failure Modes & Guardrails

### The "Never Read Code" Experiment (July 2025 — Failed)
| Aspect | Detail |
|--------|--------|
| **Duration** | 3 months |
| **Method** | Review plans/tickets only, zero code review |
| **Failure trigger** | Bug in shipping desktop app |
| **Model behavior** | Council of frontier models kept diagnosing wrong cause, shipping non-fixes |
| **Recovery cost** | Weeks of unfamiliar, sloppy code while users angry |
| **Lesson** | Odds of this happening > odds models get good enough first |

### David's Accepted Counterpoint
> The requirement may be **understanding the *logic*** rather than literal code — what the first 5 minutes of onboarding does, what happens when someone cancels, what fires when this endpoint is hit. **The failure mode is losing the shape of the system, not skipping line-by-line read.**

### Guard Against Silently Losing the Thread
- **Prototype that quizzed operator mid-session**: multiple-choice questions + Mermaid diagrams on current codebase state and new changes
- **David's version**: Have the agent deliberately slow down and educate you when you start losing grip
- **Target**: Keep the system's logic in your head, not read every line

---

## Benchmark Critique (Structural, Not Vibes)

| Benchmark | Problem |
|-----------|---------|
| **SWE-bench** | Reinforcement learning scores traces on whether human-written tests pass |
| **Golden patches** | Often 100–200 lines — no penalty for bad design anywhere in the loop |
| **Result** | Models solve problems well but produce code that's hard to maintain |
| **Dex's objection** | Coherent explanation of why models solve problems but fail at maintainability |

---

## Incident Routing Into the Agent Pipeline

> **"I don't wake up to an alert, I wake up to a pull request."**

### Working Implementation (David's)
- **GLM 5.2** reviews every uptime incident on API product
- Returns report classifying: provider outage (nothing to do) vs missing migration (specific fix)
- Runs on cron jobs: Vercel + GitHub Actions
- Small agent loop on render.com doing inference
- Same applies to triaging support queue directly to agent

---

## Integration With Firstmate Factory

### Direct Mapping to Existing Firstmate Constructs

| Four-Layer Concept | Firstmate Equivalent |
|--------------------|----------------------|
| **Product Layer** | Ticket creation (`ticket-create`), PRD (`write-a-prd`), success metrics in ticket |
| **Architecture Layer** | `create-plan` with system architecture section, `improve-codebase-architecture` |
| **Program Design Layer** | **NEW** — needs explicit capture in plan/brief: file map, type signatures, call stack, test signatures |
| **Vertical Slices** | `github-branch` + worktree isolation (`worktree` skill), `ticket-executor` phase-by-phase, `validate-implementation` per slice |
| **Incident → PR** | `process-event-sources` + `fmx-respond` for automated incident-to-agent routing |
| **Measurable goals** | `ticket-context` with quantitative success criteria, `validate-implementation` against metrics |

### Recommended Factory Enhancements

1. **Add "Program Design" section to `create-plan` output** — enforce file locations, type signatures, call stack, test shapes before implementation
2. **Vertical slice enforcement in `ticket-executor`** — require thin e2e path before horizontal expansion (Phase 0 = vertical slice definition)
3. **Context budget awareness** — track token usage, warn at 50% ("dumb zone"), enforce structural decisions early
4. **Sub-agent pattern in briefs** — scaffold briefs to delegate implementation to cheaper models after design is locked
5. **Live validation integration** — `validate-implementation` against running dev environment (orbs, preview deployments)
6. **Pre-mortem confidence check** — add "which choices are you not confident about?" to program design review
7. **Measurable goal enforcement** — require quantitative success metric in every ticket/plan
8. **Incident-to-agent pipeline** — route alerts through `process-event-sources` → agent brief → PR
9. **Logic retention guard** — periodic "quiz the operator" or agent-educates-human during long tasks
10. **Multi-model review gate** — parallel Codex + Opus review for high-stakes changes

---

## Anti-Patterns to Avoid

| Anti-Pattern | Consequence | Fix |
|--------------|-------------|-----|
| Skip Layer 3 (Program Design) | Agent makes silent structural decisions you hate; 2000-line re-steer | Mandatory program design sign-off before spawn |
| Horizontal building (DB→Service→API→FE) | Nothing testable until 3000+ lines | Enforce vertical slice #1 in every task |
| Token-maxing context | Dumb zone at 50% — model quality degrades | Right tokens, structural decisions early |
| No announcement post | Building features nobody understands | Amazon practice: write launch post first |
| Vibe-coding in enterprise | $1M bugs, unreviewable PRs | Full four-layer discipline non-negotiable |
| "Never read code" factory | Silent degradation, catastrophic debug sessions | Keep logic in head; periodic code logic quizzes |
| Descriptive goals only | Agent wanders, no convergence | Measurable metric tied to business outcome |
| Single-model review | Blind spots in generated code | Parallel Codex + Opus review for critical paths |

---

## Skills to Create / Update

1. **`program-design`** — New skill: enforce Layer 3 capture in plans/briefs (file map, type signatures, call stack, test shapes)
2. **`vertical-slice-executor`** — New skill: structure ticket-executor around thin e2e slices (Phase 0 = vertical slice def)
3. **`context-budget`** — New skill: monitor token usage, enforce early structural decisions, warn at 50%
4. **`pre-mortem-confidence`** — New skill: "which choices are you not confident about?" integration in design review
5. **`measurable-goals`** — New skill: require quantitative success metrics in tickets/plans, validate against them
6. **`incident-to-agent`** — New skill: route alerts via `process-event-sources` → agent brief → PR
7. **`logic-retention-guard`** — New skill: periodic codebase logic quizzes / agent-educates-human during long tasks
8. **`multi-model-review`** — New skill: parallel Codex + Opus review gate for high-stakes changes
9. **Update `create-plan`** — Add program design section template + measurable goals + confidence check
10. **Update `ticket-executor`** — Phase 0 = vertical slice definition; measurable goal tracking
11. **Update `validate-implementation`** — Integrate live dev environment testing + metric validation
12. **Update `process-event-sources`** — Add incident classification + auto-brief generation

---

## Quick Reference Card

```
BEFORE SPAWNING ANY AGENT:
☐ Layer 1: Problem + Metrics + Announcement Post + HTML Mockups
☐ Layer 2: Services + Flow + Endpoints + Tables
☐ Layer 3: FILE MAP + TYPE SIGNATURES + CALL STACK + TEST SHAPES  ← CRITICAL
☐ Layer 4: First vertical slice defined (mock API → stub FE → wire)
☐ Measurable goal: quantitative metric tied to business outcome
☐ Pre-mortem: "Which choices are you not confident about?"

DURING EXECUTION:
☐ Sub-agents for implementation grunt work (GPT models)
☐ Vertical slice 1: end-to-end testable
☐ Validate against live dev env (orbs/portals)
☐ Human reads logic, approves architectural choices
☐ Multi-model review (Codex + Opus) for critical paths
☐ Logic retention: periodic quiz / agent educates human

CONTEXT DISCIPLINE:
☐ Structural decisions at <50% context (sharp zone)
☐ Right tokens > more tokens
☐ Compaction/handoffs planned
☐ 43k-token planning session > 3000-line diff re-steer

INCIDENT RESPONSE:
☐ Route alert → agent pipeline → PR (not 3am page)
☐ GLM 5.2 classifies: provider outage vs actionable fix
☐ Cron on Vercel/GH Actions + render.com inference

WHEN TO SKIP FOUR-LAYER:
☐ Pre-PMF: vibe faster, ship/learn/iterate
☐ Threshold: ~5+ engineers, paying users, 6-month horizon
```

---

## Related Resources

- **Original Video**: https://www.youtube.com/watch?v=xgkjtF89-44
- **OpenClawDatabase Deep-Dive**: https://openclawdatabase.com/news/videos/2026-08-07-program-design-system-agentic-engineering/
- **FrontierModels Summary**: https://frontiermodels.cc/video/ex-nasa-dev-reveals-his-agentic-engineering-workflow/
- **Zovi AI**: https://zoviai.com/ex-nasa-dev-reveals-his-agentic-engineering-workflow/
- **LinkedIn Analysis**: Wesley Stander breakdown
- **Reaction Podcast**: "Reacting to an Ex-NASA Dev's INSANE AI Engineering Workflow!"
- **Dylan Mulroy (Cloudflare)**: Program design advocacy
- **Victor Tali**: Pre-mortem confidence question technique
- **HumanLayer**: https://www.humanlayer.com/ (Dex's software factory platform)
- **Dexter Horthy**: https://x.com/dexhorthy
- **David Ondrej**: https://x.com/DavidOndrej1

---

## Appendix: Dex Horthy GitHub Profile (Source Context)

**Profile**: https://github.com/dexhorthy  
**Date Fetched**: August 2026  
**Relevance**: Primary source for the agentic engineering workflow framework documented above

---

### Profile Summary

**Dex Horthy** (@dexhorthy) — Ex-NASA dev, co-founder of HumanLayer, author of "12-Factor Agents" and "Agent Control Plane"

- **Followers**: 1.9k | **Following**: 47 | **Repos**: 163 | **Stars**: 152
- **Bio**: "Looking for a cool place to deploy my hugo site"
- **Links**: https://humanlayer.dev | X: @dexhorthy | LinkedIn: in/dexterihorthy

---

### Pinned Repositories (Top 3)

1. **humanlayer/humanlayer** (11.5k ⭐, 947 forks) — TypeScript
   > "The best way to get AI coding agents to solve hard problems in complex codebases."

2. **humanlayer/agentcontrolplane** (474 ⭐, 61 forks) — Go
   > "ACP is the Agent Control Plane - a distributed agent scheduler optimized for simplicity, clarity, and control. It is designed for outer-loop agents that run without supervision, and make asynchronous decisions."

3. **humanlayer/12-factor-agents** (25.8k ⭐, 2k forks) — TypeScript
   > "What are the principles we can use to build LLM-powered software that is actually good enough to put in the hands of production customers?"

---

### Achievements

- ⭐ Starstruck (x4)
- 🤝 Pair Extraordinaire (x3)
- 🦈 Pull Shark (x4)
- ⚡ Quickdraw
- 🎯 YOLO
- 🧊 Arctic Code Vault Contributor

---

### Professional Context

**HumanLayer** (https://humanlayer.dev) — Dex's software factory platform implementing the principles in this document. The four-layer program design system, context engineering principles, vertical slice execution, and measurable goals framework were developed through running HumanLayer's "light software factory" (reviewing plans/tickets without reading code) and learning from its failure modes.

**Key Insight from Failure**: The July 2025 experiment where models kept diagnosing wrong causes for a shipping bug while nobody had read the code for 3 months directly produced the thesis: *"The odds of this happening to you are higher than the odds that models get good enough before it does."*

---

### Framework Genealogy

This document's framework synthesizes:
- **David Ondrej Podcast** (YouTube `xgkjtF89-44`) — Primary interview
- **OpenClawDatabase Deep-Dive** — Technical breakdown
- **FrontierModels Summary** — Key takeaways
- **Zovi AI** — Visual summary
- **Wesley Stander LinkedIn Analysis** — Professional context
- **Dylan Mulroy (Cloudflare)** — Program design advocacy
- **Victor Tali** — Pre-mortem confidence technique
- **HumanLayer Platform** — Production implementation