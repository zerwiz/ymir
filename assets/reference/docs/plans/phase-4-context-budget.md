# Phase 4: Create context-budget Skill

**Project**: command (COM)
**Priority**: Medium
**Estimated Effort**: 3 days
**Status**: ✅ COMPLETED (2026-09-10)
**Measurable Goal**: `context_budget_warning_accuracy:95%:token_tracking:30d:90%`

---

## Problem Statement

Dex Horthy: "The 'dumb zone' at ~50% context is real — for models AND humans." Current factory has no token budget awareness. Agents token-max while bottleneck is code review, leading to degraded model quality in the second half of context window.

## Current State

- No token tracking in `fm-session-start.sh`, `fm-spawn.sh`, or harness adapters
- No warning at 50% context ("dumb zone")
- No enforcement of "structural decisions early when cheap"
- Harness adapters don't report token usage

## What Was Implemented

### 1. Created `context-budget` Skill
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

### 3. Integration with Existing Skills
- `create-plan`: Added context budget check before design work; added `## Context Budget at Creation` to plan template
- `ticket-executor`: Added `Context Budget Enforcement` section; Phase 0 validation gate includes budget check
- `validate-implementation`: Added budget compliance check (Step 0.5) and report line

### 4. Deferred (Future Work)
- `fm-session-start.sh` budget initialization
- `fm-spawn.sh` passing budget to worker
- Harness adapter token reporting (Claude, Codex, OpenCode, etc.)
- `fm-brief.sh` budget section

## Implementation Approach

**Created locally in opencode config first** (`~/.config/opencode/`), then copied to `command` project for MCP registration.

1. Created skill directory: `.config/opencode/skills/context-budget/`
2. Wrote `SKILL.md`: Define triggers, thresholds, integration points
3. Wrote `bin/context-budget.sh`: Core tracking logic (tested working)
4. Wrote `config/context-budget.yaml`: Thresholds per harness
5. Updated `create-plan` skill: budget check + template section
6. Updated `ticket-executor` skill: enforcement section + Phase 0 gate
7. Updated `validate-implementation` skill: Step 0.5 + report
8. Copied all artifacts to `command/.agents/skills/context-budget/` for MCP registration

## Phases

- [x] Phase 4.1: Create skill structure + SKILL.md (0.5 day)
- [x] Phase 4.2: Write bin/context-budget.sh (1 day)
- [x] Phase 4.3: Update create-plan + ticket-executor + validate-implementation (0.5 day)
- [x] Phase 4.4: Copy to command project for MCP (0.5 day)
- [ ] Phase 4.5: fm-session-start.sh budget init (deferred)
- [ ] Phase 4.6: fm-spawn.sh pass budget to worker (deferred)
- [ ] Phase 4.7: Harness adapters token reporting (deferred)
- [ ] Phase 4.8: fm-brief.sh budget section (deferred)

## Success Criteria

### Automated Verification:
- [x] `bin/context-budget.sh` correctly categorizes: 10=green, 35=yellow, 55=red, 80=red, 90=critical
- [x] Skills updated with budget integration

### Manual Verification:
- [ ] Structural decisions made early (< 50% context)
- [ ] No token-maxing while bottleneck is code review

## Acceptance Criteria

- [x] Context budget skill created and tested
- [x] Integrated with create-plan, ticket-executor, validate-implementation
- [x] Copied to command project for MCP registration
- [ ] Context budget tracking active for all spawned tasks (deferred)
- [ ] Measurable goal: 95% warning accuracy within 30 days
- [ ] Rollback threshold: < 90% accuracy triggers review

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Harness token APIs differ | High | Medium | Abstract in context-budget skill |
| Token counting inaccurate | Medium | High | Calibrate per harness |
| Overhead too high | Low | Medium | Sample, don't count every token |

## References

- Research: `docs/agentic-engineering-workflow.md` (Context Engineering Principles)
- Dex Horthy: "One 43k-token session with sharp context > re-reading a 3,000-line diff later"
- Victor Tali trick: Ask model "which choices are you not confident about?" before run