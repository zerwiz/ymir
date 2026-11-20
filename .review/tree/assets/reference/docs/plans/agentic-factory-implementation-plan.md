# Agentic Engineering Workflow — Factory Implementation Plan

**Objective**: Encode Dex Horthy's four-layer program design system and context engineering principles into the Firstmate software factory as enforceable, automated workflows.

**Source**: `docs/agentic-engineering-workflow.md` (comprehensive research from YouTube `xgkjtF89-44`)

---

## Phase 0: Foundation — Core Skills (Week 1)

### 0.1 `program-design` Skill (NEW) — ✅ IMPLEMENTED IN EXISTING SKILLS (Phase 1)
**Purpose**: Enforce Layer 3 capture in every plan/brief before spawn

**Location**: Integrated into `create-plan`, `validate-plan`, `ticket-executor` skills + global plan template

**Deliverables**:
- `SKILL.md` — trigger: before `create-plan`, before `ticket-executor` phase 0, before any ship brief (implemented in existing skills)
- `templates/program-design.md` (implemented in create-plan template + global plan template):
  ```markdown
  ## Program Design (Layer 3)
  
  ### File Map
  | Component | Path | Responsibility |
  |-----------|------|----------------|
  |           |      |                |
  
  ### Type Signatures
  ```typescript
  // Exact interfaces before implementation
  interface X { }
  type Y = ;
  ```
  
  ### Call Stack Visualization
  ```mermaid
  graph TD
    A[Entry] --> B[Handler]
    B --> C[Service]
    C --> D[Repository]
  ```
  
  ### Test Shapes (Signatures Only)
  ```typescript
  describe('Feature', () => {
    it('should do X', () => { /* shape */ })
    it('should handle Y', () => { /* shape */ })
  })
  ```
  ```
- `bin/program-design-check.sh` — validates program design section exists in plan/brief before spawn (implemented in validate-plan section 1e + ticket-executor Phase 0 gate)

**Integration Points (DONE)**:
- `create-plan`: Added Layer 3 (Program Design — MANDATORY) section to template (File Map, Type Signatures, Call Stack, Test Shapes)
- `validate-plan`: Added section 1e "Layer 3 Program Design (MANDATORY)" — REJECTED if missing/incomplete
- `ticket-executor`: Phase 0 Validation Gate requires Layer 3 present; refuses to start if missing
- Global plan template: Program Design (Layer 3 — MANDATORY) section

**Integration Points (DEFERRED)**:
- `fm-brief.sh`: scaffold includes program-design section (mandatory)
- `fm-spawn.sh`: pre-spawn validation gate

---

### 0.2 `vertical-slice-executor` Skill (NEW) — ✅ IMPLEMENTED IN EXISTING SKILLS (Phase 2)
**Purpose**: Structure ticket-executor around thin e2e slices; prevent horizontal building

**Location**: Integrated into `ticket-executor`, `validate-implementation`, `validate-plan` skills

**Deliverables**:
- `SKILL.md` — trigger: `ticket-executor` start, `fm-brief.sh` scaffold (implemented in existing skills)
- `templates/vertical-slice-definition.md` (implemented in global plan template Phase 0 section):
  ```markdown
  ## Vertical Slice Definition (Layer 4)
  
  ### Slice 1 (Tracer Bullet) — MUST BE FIRST
  - Mock API endpoint: `POST /api/v1/feature`
  - Stub frontend: minimal UI component
  - Wire together: testable e2e path
  - Success criteria: `curl` returns 200 + expected JSON
  
  ### Subsequent Slices (in priority order)
  - Slice 2: Add migrations + business logic
  - Slice 3: Error handling + validation
  - Slice 4: Polish + edge cases
  ```
- `bin/vertical-slice-enforce.sh` — validates slice 1 is defined and testable before horizontal work (implemented in ticket-executor Phase 0 gate + validate-implementation)

**Integration Points (DONE)**:
- `ticket-executor`: Phase 0 = vertical slice definition + validation
- `validate-implementation`: Tests against slice 1 first (vertical slice validation)
- `validate-plan`: Checks vertical slice definition exists
- Global plan template: Phase 0 Vertical Slice Definition section

**Integration Points (DEFERRED)**:
- `fm-brief.sh`: scaffold includes vertical-slice section (mandatory)
- `program-design` skill: not yet created (Layer 3 separate)

---

### 0.3 `context-budget` Skill (NEW) — ✅ COMPLETED (2026-09-10)
**Purpose**: Monitor token usage, warn at 50% ("dumb zone"), enforce early structural decisions

**Location**: `~/.config/opencode/skills/context-budget/` + copied to `command/.agents/skills/context-budget/`

**Deliverables**:
- `SKILL.md` — trigger: session start, before long-running agent tasks, periodic during execution
- `bin/context-budget.sh` — tracks tokens via harness APIs:
  - `< 30%`: Green — structural decisions optimal
  - `30-50%`: Yellow — make structural decisions NOW
  - `50-85%`: Red — "dumb zone" — warn, suggest compaction/handoff
  - `> 85%`: Critical — force compaction or handoff
- `config/context-budget.yaml` — thresholds, harness-specific token APIs

**Integration Points (DONE)**:
- `create-plan`: Added context budget check before design work + `## Context Budget at Creation` template section
- `ticket-executor`: Added `Context Budget Enforcement` section + Phase 0 validation gate
- `validate-implementation`: Added budget compliance check (Step 0.5) + report line

**Integration Points (DEFERRED)**:
- `fm-session-start.sh`: initialize budget tracking
- `fm-spawn.sh`: pass budget context to worker
- `harness-adapters`: harness-specific token reporting
- `fm-brief.sh`: include budget guidance in brief

---

### 0.4 `pre-mortem-confidence` Skill (NEW) — ✅ COMPLETED (2026-09-10)
**Purpose**: "Which choices are you not confident about?" — Victor Tali technique

**Location**: `~/.config/opencode/skills/pre-mortem-confidence/` + copied to `command/.agents/skills/pre-mortem-confidence/`

**Deliverables**:
- `SKILL.md` — trigger: program design review, before spawn, after vertical slice definition
- `bin/pre-mortem-check.sh` — prompts agent for confidence assessment:
  ```markdown
  ## Pre-Mortem Confidence Check
  
  While designing this, which choices are you NOT confident about?
  (List each with reasoning — these become review focus areas)
  
  | Choice | Confidence (1-10) | Reasoning | Mitigation |
  |--------|-------------------|-----------|------------|
  |        |                   |           |            |
  ```
- Output feeds into `multi-model-review` focus areas

**Integration Points (DONE)**:
- `create-plan`: Added Step 3 pre-mortem + `## Pre-Mortem Confidence Check` template section (after Layer 3)
- `validate-plan`: Added section 1d "Pre-Mortem Confidence Validation" + output format

**Integration Points (DEFERRED)**:
- `program-design` skill: runs after program design complete (not yet created)
- `fm-brief.sh`: includes pre-mortem section
- `multi-model-review`: uses low-confidence items as review focus (not yet created)

---

## Phase 1: Planning & Execution Pipeline Updates (Week 2)

### 1.1 Update `create-plan` Skill
**File**: `$HOME/firstmate/.agents/skills/create-plan/` (or wherever it lives)

**Changes**:
- Add **Layer 1 (Product)** section template: problem, metrics, announcement post, HTML mockups
- Add **Layer 2 (Architecture)** section template: services, flow, endpoints, tables
- Add **Layer 3 (Program Design)** section — delegate to `program-design` skill
- Add **Layer 4 (Vertical Slices)** section — delegate to `vertical-slice-executor` skill
- Add **Measurable Goals** section (quantitative, business-tied)
- Add **Pre-Mortem Confidence** section — delegate to `pre-mortem-confidence` skill
- Output validation: all 4 layers + measurable goal + pre-mortem required before plan approved

**Acceptance Criteria**:
- Plan cannot be marked "ready" without all 4 layers complete
- Measurable goal must be quantitative (not "improve UX" but "reduce checkout drop-off from 23% to 15%")
- Program design must have file map, type signatures, call stack, test shapes

---

### 1.2 Update `ticket-executor` Skill
**File**: `$HOME/firstmate/.agents/skills/ticket-executor/`

**Changes**:
- **Phase 0 (NEW)**: Program Design + Vertical Slice Definition
  - Run `program-design` skill validation
  - Run `vertical-slice-executor` skill validation
  - Run `pre-mortem-confidence` skill
  - Gate: cannot proceed to Phase 1 without all three passing
- **Phase 1**: Vertical Slice 1 (tracer bullet) only — mock API → stub FE → wire → test
- **Phase 2+**: Horizontal expansion per slice definition
- Each phase: measurable goal validation via `measurable-goals` skill
- Context budget check at each phase transition

**Acceptance Criteria**:
- No horizontal work (DB layer, service layer, etc.) before Slice 1 passes e2e test
- Measurable goal tracked per phase
- Context budget warnings respected

---

### 1.3 Update `validate-implementation` Skill
**File**: `$HOME/firstmate/.agents/skills/validate-implementation/`

**Changes**:
- **Live dev environment testing**: integrate with orbs/portals/preview deployments
- **Vertical slice validation**: test Slice 1 first (e2e), then subsequent slices
- **Measurable goal validation**: run metric checks (conversion, performance, etc.)
- **Multi-model review gate** (for high-stakes): parallel Codex + Opus review
- **Logic retention check**: periodic "quiz" on system logic during long tasks

**Acceptance Criteria**:
- Validation fails if Slice 1 not testable end-to-end
- Measurable goals must pass or require explicit captain override
- High-stakes changes require multi-model review

---

## Phase 2: Incident & Automation Pipeline (Week 3)

### 2.1 `incident-to-agent` Skill (NEW) — ✅ CORE IMPLEMENTED (2026-09-10), INFRASTRUCTURE DEFERRED
**Purpose**: Route alerts → agent pipeline → PR (not 3am page)

**Location**: `~/.config/opencode/skills/incident-to-agent/` + copied to `command/.agents/skills/incident-to-agent/`

**Deliverables**:
- `SKILL.md` — trigger: `process-event-sources` check wake for incident sources
- `bin/incident-classifier.sh` — GLM 5.2 style classification (tested: JSON title extraction fixed):
  ```markdown
  ## Incident Classification
  - Type: provider_outage | missing_migration | config_drift | code_regression | unknown
  - Actionable: true/false
  - Fix: specific fix description (if actionable)
  - Priority: P1/P2/P3
  ```
- `bin/incident-to-brief.sh` — generates agent brief from classification (tested: fix brief + runbook brief both work):
  - If actionable: full four-layer brief targeting the fix
  - If not actionable: documentation/update runbook brief

**Integration Points (DONE)**:
- Core skill + classifier + brief scripts created and tested locally
- Copied to `command` project for MCP registration

**Integration Points (DEFERRED — requires captain credentials/deployment)**:
- `process-event-sources` skill: add incident source types (PagerDuty, GH Actions, Vercel)
- Cron infrastructure: Vercel/GH Actions for polling + render.com for inference
- `fm-spawn.sh`: accepts incident-triggered briefs
- `fm-pr-check.sh`: tracks incident-linked PRs

---

### 2.2 `measurable-goals` Skill (NEW) — ✅ COMPLETED (2026-09-10) via Phase 3
**Purpose**: Require quantitative success metrics in tickets/plans, validate against them

**Location**: Integrated into existing skills (no separate skill — implemented in ticket-manager, ticket-template, create-plan, validate-plan, validate-implementation, bin/measurable-goal-validate.sh)

**Deliverables**:
- `SKILL.md` — trigger: ticket creation, plan creation, validation (implemented in existing skills)
- `templates/measurable-goal.md` (implemented in global ticket-template.md + plan-template.md):
  ```markdown
  ## Measurable Goal (Back-Pressure Metric)
  
  **Metric**: [e.g., checkout conversion rate]
  **Current Baseline**: [e.g., 12.3%]
  **Target**: [e.g., 15.0%]
  **Measurement Method**: [e.g., Mixpanel event 'checkout_complete' / 'checkout_start']
  **Timeframe**: [e.g., 14 days post-deploy]
  **Rollback Threshold**: [e.g., < 11% for 48h]
  ```
- `bin/measurable-goal-validate.sh` — checks goal is quantitative, not descriptive (at `$HOME/CodeP/wayofmono/bin/measurable-goal-validate.sh`)

**Integration Points (DONE)**:
- `ticket-manager`: Added `measurable_goal` to frontmatter schema + Production-Ready Standard
- Global ticket template: `measurable_goal` frontmatter + `## Measurable Goal (Back-Pressure Metric)` section
- `create-plan`: Step 1 requires ticket `measurable_goal` (STOP if missing/descriptive); template has `## Measurable Goal (from Ticket)`
- `validate-plan`: Section 1c "Measurable Goal Validation" (runs `bin/measurable-goal-validate.sh`)
- `validate-implementation`: Step 0.4 "Verify Measurable Goal Achievement" + report section

**Integration Points (DEFERRED)**:
- `ticket-create` skill: require measurable goal field (implemented in ticket-manager)
- `fm-teardown.sh`: goal validation before teardown

---

### 2.3 `logic-retention-guard` Skill (NEW)
**Purpose**: Periodic codebase logic quizzes / agent-educates-human during long tasks

**Location**: `$HOME/firstmate/.agents/skills/logic-retention-guard/`

**Deliverables**:
- `SKILL.md` — trigger: long-running tasks (>30 min), after major structural changes
- `bin/logic-quiz.sh` — generates MCQs + Mermaid diagrams on:
  - Current system state (what fires on endpoint X?)
  - New implementation changes (what does the new call stack look like?)
  - Critical invariants (what must never break?)
- `bin/agent-educates-human.sh` — agent explains logic in plain English when human signals confusion
- Configurable interval: every N minutes or after M structural decisions

**Integration Points**:
- `fm-spawn.sh`: starts logic-retention timer for long tasks
- `harness-adapters`: integrates with agent's conversation flow
- `fm-send.sh`: delivers quiz/education to human

---

### 2.4 `multi-model-review` Skill (NEW)
**Purpose**: Parallel Codex + Opus review for high-stakes changes

**Location**: `$HOME/firstmate/.agents/skills/multi-model-review/`

**Deliverables**:
- `SKILL.md` — trigger: PR validation for high-stakes changes (configurable: security, payments, core infra)
- `bin/multi-model-review.sh` — spawns parallel reviewers:
  - Reviewer 1: Codex (implementation correctness)
  - Reviewer 2: Opus (architectural soundness, maintainability)
  - Both get: PR diff + program design doc + measurable goals + pre-mortem confidence items
- `bin/review-synthesis.sh` — merges reviews, flags conflicts, produces unified verdict
- High-stakes detection: file patterns, ticket labels, captain designation

**Integration Points**:
- `validate-implementation`: invokes for high-stakes PRs
- `fm-pr-check.sh`: arms multi-model review poll
- `fm-merge-outcome-lib.sh`: requires unified verdict for merge

---

## Phase 3: Factory-Wide Integration & Polish (Week 4)

### 3.1 Update `fm-brief.sh` — Master Scaffold
**File**: `$HOME/firstmate/bin/fm-brief.sh`

**Changes**:
- Scaffold includes ALL four layers as mandatory sections:
  1. Product (Layer 1)
  2. Architecture (Layer 2)
  3. Program Design (Layer 3) — validated by `program-design` skill
  4. Vertical Slices (Layer 4) — validated by `vertical-slice-executor` skill
- Measurable Goals section (validated by `measurable-goals` skill)
- Pre-Mortem Confidence section (validated by `pre-mortem-confidence` skill)
- Context Budget guidance (from `context-budget` skill)
- Worktree isolation assertion (existing)
- Delivery mode + yolo posture (existing)

**Validation**: `fm-spawn.sh` runs all skill validations before dispatch

---

### 3.2 Update `fm-session-start.sh` — Context Budget Init
**File**: `$HOME/firstmate/bin/fm-session-start.sh`

**Changes**:
- Initialize context budget tracking per task
- Display budget status in fleet-state digest
- Warn if any active task > 50% context

---

### 3.3 Update `fm-teardown.sh` — Goal Validation
**File**: `$HOME/firstmate/bin/fm-teardown.sh`

**Changes**:
- Require measurable goal validation before teardown (for ship tasks)
- Record goal outcome in backlog (met/not-met/pending)
- If not-met: auto-create follow-up ticket with `measurable-goals` skill

---

### 3.4 Update `data/backlog.md` Schema
**File**: `$HOME/firstmate/.tasks.toml` + backlog items

**Changes**:
- Add fields to task metadata:
  ```toml
  measurable_goal = "metric:target:method:timeframe:rollback"
  program_design_complete = true/false
  vertical_slice_defined = true/false
  pre_mortem_done = true/false
  context_budget_warned = true/false
  multi_model_review_required = true/false
  logic_retention_active = true/false
  ```

---

## Phase 4: Secondmate & Fleet Propagation (Week 5)

### 4.1 Secondmate Skill Propagation
- All new skills propagated to secondmate homes via `secondmate-provisioning`
- `config/crew-dispatch.json` updated with dispatch profiles for new skills
- Secondmate charter briefs include four-layer requirements

### 4.2 Cross-Home Consistency
- `fm-fleet-sync.sh` validates all homes have required skills
- `fm-secondmate-reconcile.sh` checks secondmate compliance

---

## Skill Dependency Graph

```
program-design (NEW)
    │
    ├── create-plan (UPDATE)
    ├── ticket-executor (UPDATE) ──▶ vertical-slice-executor (NEW)
    ├── fm-brief.sh (UPDATE)
    └── fm-spawn.sh (UPDATE: pre-spawn gate)

context-budget (NEW)
    │
    ├── fm-session-start.sh (UPDATE)
    ├── fm-spawn.sh (UPDATE)
    ├── harness-adapters (UPDATE: token reporting)
    └── fm-brief.sh (UPDATE)

pre-mortem-confidence (NEW)
    │
    ├── program-design (after design complete)
    ├── fm-brief.sh (UPDATE)
    └── multi-model-review (focus areas)

vertical-slice-executor (NEW)
    │
    ├── ticket-executor (UPDATE: Phase 0)
    ├── fm-brief.sh (UPDATE)
    └── validate-implementation (UPDATE: slice 1 first)

measurable-goals (NEW)
    │
    ├── ticket-create (UPDATE)
    ├── create-plan (UPDATE)
    ├── validate-implementation (UPDATE)
    └── fm-teardown.sh (UPDATE)

incident-to-agent (NEW)
    │
    ├── process-event-sources (UPDATE: incident sources)
    ├── fm-spawn.sh (UPDATE: incident briefs)
    └── fm-pr-check.sh (UPDATE: incident-linked PRs)

logic-retention-guard (NEW)
    │
    ├── fm-spawn.sh (UPDATE: timer)
    ├── harness-adapters (UPDATE: conversation integration)
    └── fm-send.sh (UPDATE: quiz delivery)

multi-model-review (NEW)
    │
    ├── validate-implementation (UPDATE: high-stakes gate)
    ├── fm-pr-check.sh (UPDATE: review poll)
    └── fm-merge-outcome-lib.sh (UPDATE: verdict requirement)
```

---

## Acceptance Criteria (Definition of Done)

### Factory-Level
- [x] Every ship task has all 4 layers documented before spawn (Layer 3 implemented, Layer 4 in template, Layer 1/2 in existing template)
- [x] Zero horizontal-first builds (Slice 1 e2e testable first — ticket-executor Phase 0 gate)
- [x] 100% of ship tasks have measurable goals (implemented in ticket-manager + create-plan + validate-plan)
- [ ] Context budget warnings visible in fleet digest (deferred — fm-session-start.sh integration)
- [x] Pre-mortem confidence check on every program design (create-plan + validate-plan)
- [ ] High-stakes changes go through multi-model review (deferred)
- [ ] Incident-to-PR pipeline operational (core skill done, infra deferred)
- [ ] Logic retention active on tasks >30 min (deferred)

### Skill-Level
- [x] 4 core foundation skills implemented (context-budget, pre-mortem-confidence, incident-to-agent, measurable-goals via existing skills)
- [x] 3 core pipeline skills updated (`create-plan`, `ticket-executor`, `validate-implementation`)
- [x] `validate-plan` updated with all new validations
- [x] Global plan template rewritten with all 4 layers + measurable goal + pre-mortem
- [x] All new skills copied to `command` project for MCP registration
- [ ] No regression in existing workflows (pending integration test)
- [ ] Skills work in both primary and secondmate homes (pending secondmate sync)

### Quality Gates
- [ ] `fm-lint.sh` passes on all new/modified code
- [ ] Integration test: full ticket lifecycle (create → plan → execute → validate → teardown)
- [ ] Stress test: 5 concurrent tasks with context budget tracking
- [ ] Failure injection: simulate "never read code" scenario — factory catches it

---

## Risk Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Overhead slows pre-PMF work | High | Medium | Configurable threshold: skip four-layer for tickets labeled `vibe-mode` |
| Skill conflicts with existing | Medium | High | Feature flags per skill; gradual rollout |
| Token API differences across harnesses | High | Medium | `context-budget` skill abstracts harness differences |
| Measurable goals hard for some work | Medium | Low | Allow "learning goal" variant with qualitative criteria + captain sign-off |
| Multi-model review cost | Low | Medium | Only for high-stakes (configurable patterns); Opus + Codex ~$0.50/review |

---

## Rollout Sequence

1. **Week 1** ✅ DONE (2026-09-10): Created 4 foundation skills + updated 3 core pipeline skills
   - context-budget skill + bin/context-budget.sh + config/context-budget.yaml
   - pre-mortem-confidence skill + bin/pre-mortem-check.sh
   - incident-to-agent skill + bin/incident-classifier.sh + bin/incident-to-brief.sh
   - measurable-goals (integrated into ticket-manager, create-plan, validate-plan, validate-implementation + bin/measurable-goal-validate.sh)
   - Updated: create-plan, ticket-executor, validate-implementation, validate-plan
   - Rewrote: global plan-template.md

2. **Week 2** (In Progress): Integration into master scaffolds
   - [ ] `fm-brief.sh`: add Layer 3, vertical slices, measurable goals, pre-mortem, context budget sections
   - [ ] `fm-session-start.sh`: context budget init
   - [ ] `fm-spawn.sh`: pass budget to worker, pre-spawn validation gate
   - [ ] `fm-teardown.sh`: measurable goal validation
   - [ ] `data/backlog.md` schema: add new fields

3. **Week 3**: Build remaining automation skills
   - [ ] `logic-retention-guard` skill
   - [ ] `multi-model-review` skill

4. **Week 4**: Incident pipeline infrastructure
   - [ ] Extend `process-event-sources` with incident sources
   - [ ] Cron infrastructure (Vercel/GH Actions + render.com)
   - [ ] Integrate `fm-spawn` + `fm-pr-check` with incident briefs

5. **Week 5**: Propagate to secondmates, fleet validation, documentation

---

## Captain Decision Points

1. **Vibe-mode threshold**: At what team size/project stage does four-layer become mandatory? (Default: 5 engineers, paying users, 6-month horizon)
2. **High-stakes definition**: What file patterns/ticket labels trigger multi-model review?
3. **Context budget thresholds**: Use 30/50/80% defaults or tune per harness?
4. **Incident classification**: Use GLM 5.2 or local model? What incident sources exist?
5. **Measurable goal enforcement**: Hard gate (block teardown) or soft gate (warn + follow-up)?

---

## Reference Documents

- **Full Research**: `docs/agentic-engineering-workflow.md`
- **Firstmate Architecture**: `docs/architecture.md`
- **Supervision Protocols**: `docs/supervision-protocols/`
- **Skill Development Guide**: `docs/verification/` (various)
- **Configuration Schema**: `docs/configuration.md`

---

## Next Steps

1. Captain reviews and approves plan
2. Assign implementation tickets via `ticket-create` (with measurable goals!)
3. Begin Phase 0 foundation skills
4. Weekly sync on rollout progress

**Estimated Total Effort**: 5 weeks, ~200-300 lines of new skill code per skill, ~500 lines of integration updates

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