# Phase 2: Add Layer 4 (Vertical Slices) to ticket-executor Skill

**Project**: command (COM)
**Priority**: Critical
**Estimated Effort**: 5 days
**Measurable Goal**: `vertical_slice1_first:100%:validation_gate:30d:95%`

---

## Problem Statement

Models default to building **horizontally** — entire database layer → entire service layer → entire API → entire frontend — leaving **nothing testable until thousands of lines are done**. Dex Horthy: "I have never seen a model do this without a human telling it the order." The `ticket-executor` skill currently executes plans phase-by-phase but has no enforcement of **vertical slices** (thin end-to-end first).

## Current State

- `ticket-executor` skill at `.config/opencode/skills/ticket-executor/SKILL.md` executes phases sequentially
- Phases are arbitrary — no enforcement of "Slice 1 = tracer bullet (mock API → stub FE → wire → test)"
- `validate-implementation` checks automated verification, rules compliance, code review — but **does not verify vertical slice order**

## Requirements

### 1. Add Phase 0 to `ticket-executor`
**Phase 0: Vertical Slice Definition (MANDATORY, before any implementation)**

```markdown
## Phase 0: Vertical Slice Definition (MUST COMPLETE FIRST)

### Slice 1 (Tracer Bullet) — MUST BE FIRST
- Mock API endpoint: `POST /api/v1/feature`
- Stub frontend: minimal UI component
- Wire together: testable e2e path
- Success criteria: `curl` returns 200 + expected JSON
- **No horizontal work (DB layer, service layer, etc.) before Slice 1 passes**

### Subsequent Slices (in priority order)
- Slice 2: Add migrations + business logic
- Slice 3: Error handling + validation
- Slice 4: Polish + edge cases
```

### 2. Update `validate-implementation` Skill
Add validation gate:
- [ ] Phase 0 (Vertical Slice Definition) exists in plan
- [ ] Slice 1 defined with mock API + stub FE + wire + success criteria
- [ ] **First implementation phase targets Slice 1 only**
- [ ] Slice 1 passes e2e test before any horizontal expansion
- [ ] Measurable goal tracked per slice

### 3. Update `validate-plan` Skill
Add check: "Plan defines vertical slices with Slice 1 as tracer bullet"

## Implementation Approach

**Use MCP for all ticket/plan operations** — never hand-write markdown or git-push to f-rr-d. The MCP keeps DB row + canonical markdown + collision-safe numbering in sync.

1. **Edit `ticket-executor/SKILL.md`**: Insert Phase 0 before current phases; update workflow diagram
2. **Edit `validate-implementation/SKILL.md`**: Add vertical slice validation to Step 2 (Systematic Validation)
3. **Edit `validate-plan/SKILL.md`**: Add vertical slice check to Feasibility Check
4. **Test via MCP**: Execute plan with `implement_plan` skill, verify vertical slice gate via `validate_implementation`
5. **Update ticket via MCP**: `tickets_update` with phase completion status

## Phases

- [ ] Phase 2.1: Update ticket-executor skill with Phase 0 (1.5 days)
- [ ] Phase 2.2: Update validate-implementation with slice validation (1.5 days)
- [ ] Phase 2.3: Update validate-plan with slice check (0.5 day)
- [ ] Phase 2.4: Integration test with sample ticket (1 day)
- [ ] Phase 2.5: Update brief scaffold if needed (0.5 day)

## Success Criteria

### Automated Verification:
- [ ] `ticket-executor` requires Phase 0 before Phase 1
- [ ] `validate-implementation` fails if Slice 1 not testable e2e
- [ ] Horizontal work blocked until Slice 1 passes

### Manual Verification:
- [ ] First deliverable is always a thin end-to-end path
- [ ] No "database layer first" or "all services then API" patterns

## Acceptance Criteria

- [ ] Every executed plan has Phase 0 (Vertical Slice Definition)
- [ ] Slice 1 (tracer bullet) implemented and tested first
- [ ] Measurable goal: 100% of implementations start with vertical slice within 30 days
- [ ] Rollback threshold: < 95% compliance triggers process review

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Existing plans don't have slices | High | Medium | Migration script for in-flight plans |
| Slice 1 too vague | Medium | High | Template with concrete examples |
| Slowdown perception | High | Low | Measure: slice 1 typically < 2 hours |

## References

- Research: `docs/agentic-engineering-workflow.md` (Layer 4 section)
- Dex Horthy: "Models default to building horizontally... Vertical slice is thin and end-to-end"
- OpenClawDatabase: "Mock the API endpoint, stub the front end, wire them together, and only then add migrations, business logic and error handling"