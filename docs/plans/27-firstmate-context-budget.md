# 27-firstmate-context-budget.md — Context Budget Awareness

**Status**: active  
**Source**: Integrated from `/home/zerwiz/firstmate/docs/plans/phase-4-context-budget.md` and `agentic-engineering-workflow.md`  
**Related**: Dex Horthy context engineering principles, Victor Tali pre-mortem technique  
**Norse naming**: Context budget tracked in Mimirsbrunn well, warnings at 50% "dumb zone"

## Problem Statement

Dex Horthy: *"The 'dumb zone' at ~50% context is real — for models AND humans."* Current factory has no token budget awareness. Agents token-max while bottleneck is code review, leading to degraded model quality in the second half of context window.

## Current State (Ymir Integration)

- No token tracking in `fm-session-start.sh`, `fm-spawn.sh`, or harness adapters
- No warning at 50% context ("dumb zone")
- No enforcement of "structural decisions early when cheap"
- Harness adapters don't report token usage via Mimirsbrunn bridge (`:4602`)

## What Ymir Has Implemented

### 1. Context-Budget Skill (Completed 2026-09-10)

**Location**: `~/.config/opencode/skills/context-budget/` + copied to `command/.agents/skills/context-budget/`

- `SKILL.md` — skill definition with triggers, thresholds, integration points
- `bin/context-budget.sh` — token tracking script (tested: green<30, yellow=30-50, red=50-85, critical≥85)
- `config/context-budget.yaml` — thresholds per harness

### 2. Token Thresholds (implemented)

```yaml
thresholds:
  green: 30      # < 30% — structural decisions optimal
  yellow: 50     # 30-50% — "dumb zone" — make structural decisions NOW
  red: 85        # 50-85% — warn, suggest compaction
  critical: 85   # > 85% — force compaction or handoff
```

### 3. Integration with Existing Ymir Skills

- **`create-plan`**: Added context budget check before design work; added `## Context Budget at Creation` to plan template
- **`ticket-executor`**: Added `Context Budget Enforcement` section; Phase 0 validation gate includes budget check
- **`validate-implementation`**: Added budget compliance check (Step 0.5) and report line

### 4. Deferred (Future Work)

- `fm-session-start.sh` budget initialization
- `fm-spawn.sh` passing budget to worker
- Harness adapter token reporting (Claude, Codex, OpenCode, etc.)
- `fm-brief.sh` budget section

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

## Integration with Ymir Systems

### Mimirsbrunn Well (`:4602`)
- Program design decisions observed into the well before agent dispatch
- Context budget status recalled via `GET /recall` before task spawn
- Every significant action carved into Runes audit log

### Yggdrasil Worktrees
- Context budget warnings displayed in fleet-state digest
- Structural decisions enforced at phase transitions
- Budget context passed to Eindri workers inside Utgard containers

### Brokk Agent Runtime
- Context budget check at `fm-session-start` → initialize tracking
- Budget status displayed in fleet-state digest
- Warn if any active task > 50% context
- Phase transitions respect budget thresholds (green/yellow/red/critical)

### Ratatoskr A2A Backbone
- Context budget metadata included in A2A task cards
- Specialists recalled from Mimirsbrunn before dispatch
- Anti-hallucination gate honours budget warnings

## Acceptance Criteria

### Automated Verification:
- [x] `bin/context-budget.sh` correctly categorizes: 10=green, 35=yellow, 55=red, 80=red, 90=critical
- [x] Skills updated with budget integration (create-plan, ticket-executor, validate-implementation)
- [x] Copied to command project for MCP registration

### Manual Verification:
- [ ] Structural decisions made early (< 50% context, "sharp zone")
- [ ] No token-maxing while bottleneck is code review
- [ ] Context budget warnings visible in fleet digest

### Measurable Goal:
- **`context_budget_warning_accuracy:95%:token_tracking:30d:90%`**
- Rollback threshold: < 90% accuracy triggers review

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Harness token APIs differ | High | Medium | Abstract in context-budget skill |
| Token counting inaccurate | Medium | High | Calibrate per harness |
| Overhead too high | Low | Medium | Sample, don't count every token |

## References

- **Research**: `docs/agentic-engineering-workflow.md` (Context Engineering Principles)
- **Dex Horthy**: *"One 43k-token session with sharp context > re-reading a 3,000-line diff later"*
- **Victor Tali trick**: Ask model "which choices are you not confident about?" before run
- **Ymir Integration**: Mimirsbrunn bridge `:4602`, Runes audit log, Brokk runtime