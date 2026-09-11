# 26-firstmate-four-layer.md — Firstmate Four-Layer Program Design Framework

**Status**: active  
**Source**: Integrated from `/home/zerwiz/firstmate/docs/plans/` (9 planning documents)  
**Related**: Dex Horthy agentic engineering workflow (YouTube `xgkjtF89-44`, August 2026)  
**Norse naming**: Four-layer framework documented within Ymir's seven-realm architecture

## Layer 1 — Product (What & Why)

**Problem statement**: What user problem are we solving?  
**Success metrics**: How will we measure it? (Quantitative, not vibes)  
**Announcement post**: Write the launch blog post *before* building the feature — forces you to explain value to a user first (Amazon practice)  
**HTML mockups**: Prototype relevant views as plain HTML at this stage  
**Zero tech**: No databases, no schemas, no architecture  

*Ymir alignment*: Maps to ticket creation (`ticket-create`), PRD workflow, and measurable goals in ticket frontmatter.

## Layer 2 — System Architecture (How Services Fit)

- Service topology and boundaries
- Request/response flow diagrams
- New endpoints and their contracts
- New tables and query outlines
- **Note**: Most experienced teams already operate at this level — people are generally comfortable designing architecture back-and-forth with a model

*Ymir alignment*: Complements `create-plan` skill's Architecture section (Layer 2).

## Layer 3 — Program Design ⚠️ THE SKIPPED LAYER

**One level below architecture** — this is where the agent makes decisions you will dislike later.

- **File locations**: Where does each piece live?
- **Types and method signatures**: Exact interfaces before implementation
- **Call stack visualization**: What does the execution path look like when this runs?
- **Test shapes**: What will the tests look like? (Not implementation — test *signatures*)
- **Deliberately NOT implementation detail**

> **Dylan Mulroy (Cloudflare)**: *"A good plan with the tests and the call stack. The point is that [the agent] will otherwise make silently, and that [you] may not like."*

*Ymir enforcement*: `validate-plan` skill section 1e mandates Layer 3 — REJECTED if missing/incomplete. File Map must have at least 1 entry, Type Signatures must have code block, Call Stack must have mermaid diagram, Test Shapes must have at least 2 test signatures.

## Layer 4 — Vertical Slices / Tracer Bullets (Execution Order)

**Models default to building horizontally** — entire database layer → entire service layer → entire API → entire frontend — leaving **nothing testable until thousands of lines are done**.

**Vertical slice = thin and end-to-end**:
1. Mock the API endpoint
2. Stub the frontend
3. Wire them together
4. *Then* add migrations, business logic, error handling

> **Dex**: *"I have never seen a model do this without a human telling it the order."*

*Ymir implementation*: `ticket-executor` Phase 0 gate requires vertical slice definition. No horizontal work (DB layer, service layer, etc.) before Slice 1 passes e2e test.

---

## Context Engineering Principles (Concurrent)

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

### Measurable Goals Beat Instructions
> **Both speakers converge**: an agent given a number to move will go much further than one given a description.

- **Dex calls it "back-pressure"**: LLM-as-judge is acceptable, but a **real metric tied to the business** (conversion rate, resource-reduction target for a CUDA kernel) lets an agent run experiments, check data daily, and pick a winner
- **David's framing**: *"If you can tell it a measurable output, the agent will move mountains for you."*

---

## Integration with Ymir Realms

| Four-Layer Concept | Ymir Equivalent |
|--------------------|-----------------|
| **Product Layer** | Ticket creation (`ticket-create`), PRD (`write-a-prd`), success metrics in ticket |
| **Architecture Layer** | `create-plan` with system architecture section, `improve-codebase-architecture` |
| **Program Design Layer** | **Mandatory** capture in plan/brief: file map, type signatures, call stack, test signatures |
| **Vertical Slices** | `github-branch` + worktree isolation (`worktree` skill), `ticket-executor` phase-by-phase, `validate-implementation` per slice |

## When to Apply Each Mode

| Context | Approach |
|---------|----------|
| **Pre-PMF / MVP** | Vibe faster — ship, learn, iterate (four-layer "overkill" here) |
| **~5+ engineers, paying users, 6-month maintenance horizon** | **Start earning its keep** — full four-layer discipline |
| **Enterprise fintech / regulated** | **This isn't optional** — a bug costs $1M+ |

---

**References**:
- **Full Research**: `agentic-engineering-workflow.md` (source)
- **Firstmate Plans**: `phase-1-layer3-program-design.md`, `phase-2-vertical-slices.md`, `phase-3-measurable-goals.md`, `phase-4-context-budget.md`, `phase-5-pre-mortem-confidence.md`, `phase-6-incident-to-agent.md`
- **Dex Horthy interview**: YouTube `xgkjtF89-44`
- **Dylan Mulroy (Cloudflare)**: Program design advocacy
- **Victor Tali**: Pre-mortem confidence technique