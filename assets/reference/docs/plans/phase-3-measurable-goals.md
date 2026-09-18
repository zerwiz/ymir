# Phase 3: Add Measurable Goals to ticket-manager Skill

**Project**: command (COM)
**Priority**: Critical
**Estimated Effort**: 3 days
**Measurable Goal**: `ticket_measurable_goal_coverage:100%:mcp_validation:30d:95%`

---

## Problem Statement

Dex Horthy: "An agent given a number to move will go much further than one given a description." Current ticket templates have **Acceptance Criteria** (descriptive) but no **Measurable Goal** (quantitative, business-tied). The "back-pressure" metric is what lets an agent run experiments, check data daily, and pick a winner.

## Current State

- Ticket template at `$HOME/.pi/thoughts/global/templates/ticket-template.md` has Acceptance Criteria (checkboxes)
- Ticket frontmatter in `ticket-manager/SKILL.md` has no `measurable_goal` field
- Plans have "Success Criteria" but they're descriptive, not quantitative
- No validation that goals are measurable vs descriptive

## Requirements

### 1. Add `measurable_goal` Frontmatter Field
```yaml
measurable_goal: "metric:target:method:timeframe:rollback"
# Examples:
# "checkout_conversion:15%:mixpanel:14d:11%"
# "api_p99_latency:200ms:datadog:7d:300ms"
# "deployment_frequency:daily:github:30d:weekly"
```

Format: `metric_name:target_value:measurement_method:timeframe:rollback_threshold`

### 2. Update Ticket Template
Add Measurable Goal section after Acceptance Criteria:
```markdown
## Measurable Goal (Back-Pressure Metric)

**Metric**: [e.g., checkout conversion rate]
**Current Baseline**: [e.g., 12.3%]
**Target**: [e.g., 15.0%]
**Measurement Method**: [e.g., Mixpanel event 'checkout_complete' / 'checkout_start']
**Timeframe**: [e.g., 14 days post-deploy]
**Rollback Threshold**: [e.g., < 11% for 48h]
```

### 3. Update `ticket-manager` Skill
- Add `measurable_goal` to frontmatter schema
- Validation: must match `metric:target:method:timeframe:rollback` format
- `create-plan` requires measurable goal from ticket
- `validate-implementation` checks goal achievement

### 4. Add Validation Script
`bin/measurable-goal-validate.sh` — checks goal is quantitative, not descriptive

## Implementation Approach

**Use MCP for all ticket/plan operations** — never hand-write markdown or git-push to f-rr-d. The MCP keeps DB row + canonical markdown + collision-safe numbering in sync.

1. **Edit `ticket-manager/SKILL.md`**: Add `measurable_goal` to frontmatter schema
2. **Edit global `ticket-template.md`**: Add Measurable Goal section (via MCP `templates_update`)
3. **Edit `create-plan/SKILL.md`**: Require measurable goal from linked ticket (read via `tickets_get`)
4. **Edit `validate-implementation/SKILL.md`**: Add goal validation step
5. **Create `bin/measurable-goal-validate.sh`**: Format + quantitative check
6. **Test via MCP**: Create ticket with `tickets_create` including measurable_goal, verify validation

## Phases

- [ ] Phase 3.1: Add frontmatter field + template section (1 day)
- [ ] Phase 3.2: Update create-plan to require goal (0.5 day)
- [ ] Phase 3.3: Update validate-implementation to check goal (0.5 day)
- [ ] Phase 3.4: Create validation script (0.5 day)
- [ ] Phase 3.5: Test with existing tickets (0.5 day)

## Success Criteria

### Automated Verification:
- [ ] New tickets require `measurable_goal` frontmatter
- [ ] Format validation rejects descriptive goals ("improve UX")
- [ ] `create-plan` fails if ticket lacks measurable goal
- [ ] `validate-implementation` reports goal status

### Manual Verification:
- [ ] Goals are quantitative (numbers, not adjectives)
- [ ] Measurement method is specific (tool + query)
- [ ] Rollback threshold defined

## Acceptance Criteria

- [ ] 100% of new tickets in `command` project have measurable_goal within 30 days
- [ ] Rollback threshold: < 95% coverage triggers review
- [ ] Descriptive goals ("make it faster") rejected by validation

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hard to quantify some work | Medium | Medium | Allow "learning goal" variant with captain sign-off |
| Metric infrastructure missing | Low | High | Document required analytics setup |
| Gaming the metric | Low | Medium | Rollback threshold + captain review |

## References

- Research: `docs/agentic-engineering-workflow.md` (Measurable Goals section)
- Dex Horthy: "If you can tell it a measurable output, the agent will move mountains for you"
- Back-pressure concept: LLM-as-judge acceptable, but real business metric drives convergence