# Phase 5: Create pre-mortem-confidence Skill

**Project**: command (COM)
**Priority**: Medium
**Estimated Effort**: 2 days
**Status**: ✅ COMPLETED (2026-09-10)
**Measurable Goal**: `pre_mortem_coverage:100%:design_review:30d:95%`

---

## Problem Statement

Victor Tali technique: "After a change, ask the model *'while working on this, which choices did you make that you're not confident of?'*." Dex's system does this **before the run instead of after** — surfacing uncertain choices during program design, not post-hoc. Current factory has no pre-mortem confidence check.

## Current State

- No pre-mortem step in `create-plan`, `ticket-executor`, or `fm-brief.sh`
- No structured way to capture "low confidence choices" for review focus
- Models make silent structural decisions (Layer 3) without flagging uncertainty

## What Was Implemented

### 1. Created `pre-mortem-confidence` Skill
**Location**: `~/.config/opencode/skills/pre-mortem-confidence/` + copied to `command/.agents/skills/pre-mortem-confidence/`

- `SKILL.md` — skill definition with triggers, output format, integration
- `bin/pre-mortem-check.sh` — prompts agent for confidence assessment (tested: rejects confidence ≤6 without mitigation)

### 2. Pre-Mortem Output Format (implemented)
```markdown
## Pre-Mortem Confidence Check

While designing this, which choices are you NOT confident about?
(List each with reasoning — these become review focus areas)

| Choice | Confidence (1-10) | Reasoning | Mitigation |
|--------|-------------------|-----------|------------|
| ... | ... | ... | ... |
```

### 3. Integration with Existing Skills
- `create-plan`: Added Step 3 mention + `## Pre-Mortem Confidence Check` section in template (after Layer 3)
- `validate-plan`: Added section 1d "Pre-Mortem Confidence Validation" + output format

### 4. Deferred (Future Work)
- `fm-brief.sh`: Include pre-mortem section in brief scaffold
- `multi-model-review` skill (Phase 6): Use low-confidence items as review focus

## Implementation Approach

**Created locally in opencode config first** (`~/.config/opencode/`), then copied to `command` project for MCP registration.

1. Created skill directory: `.config/opencode/skills/pre-mortem-confidence/`
2. Wrote `SKILL.md`: Define triggers, output format, integration
3. Wrote `bin/pre-mortem-check.sh`: Prompts agent, produces table (tested working)
4. Updated `create-plan` skill: pre-mortem step after Layer 3 + template section
5. Updated `validate-plan` skill: section 1d validation
6. Copied all artifacts to `command/.agents/skills/pre-mortem-confidence/` for MCP registration

## Phases

- [x] Phase 5.1: Create skill structure + SKILL.md (0.5 day)
- [x] Phase 5.2: Write bin/pre-mortem-check.sh (0.5 day)
- [x] Phase 5.3: Update create-plan + validate-plan skills (0.5 day)
- [x] Phase 5.4: Copy to command project for MCP (0.5 day)
- [ ] Phase 5.5: fm-brief.sh pre-mortem section (deferred)
- [ ] Phase 5.6: multi-model-review uses low-confidence items (deferred)

## Success Criteria

### Automated Verification:
- [x] `bin/pre-mortem-check.sh` rejects confidence ≤6 without mitigation
- [x] Skills updated with pre-mortem integration

### Manual Verification:
- [ ] Reviewers focus on low-confidence areas
- [ ] Fewer post-hoc "I didn't like that decision" moments

## Acceptance Criteria

- [x] Pre-mortem confidence skill created and tested
- [x] Integrated with create-plan + validate-plan
- [x] Copied to command project for MCP registration
- [ ] 100% of plans have pre-mortem confidence check within 30 days
- [ ] Measurable goal: 100% coverage in design reviews
- [ ] Rollback threshold: < 95% coverage triggers process review

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Agents overconfident | High | Medium | Calibrate with examples |
| Adds process overhead | Medium | Low | Keep it lightweight (5 min) |
| Gaming confidence scores | Low | Medium | Review focuses on low scores anyway |

## References

- Research: `docs/agentic-engineering-workflow.md` (Pre-Mortem Confidence section)
- Victor Tali: "Ask the model which choices it was not confident about — before the run, not after"
- Dex Horthy: "Surfacing uncertain choices during program design, not post-hoc"