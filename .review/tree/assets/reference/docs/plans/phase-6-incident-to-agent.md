# Phase 6: Incident-to-Agent Pipeline

**Project**: command (COM)
**Priority**: Medium
**Estimated Effort**: 1 week
**Status**: ✅ CORE IMPLEMENTED (2026-09-10) — Infrastructure deferred
**Measurable Goal**: `incident_to_pr_latency:<30min:pagerduty:30d:<60min`

---

## Problem Statement

Dex Horthy: "**I don't wake up to an alert, I wake up to a pull request.**" Current factory has no incident-to-agent pipeline. David Ondrej's working version: GLM 5.2 reviews every uptime incident, classifies it (provider outage vs missing migration + specific fix), runs on cron (Vercel/GH Actions + render.com inference).

## Current State

- `process-event-sources` skill exists but no incident source types
- No incident classifier (GLM 5.2 style)
- No auto-brief generation from incident classification
- No cron infrastructure for incident polling

## What Was Implemented

### 1. Created `incident-to-agent` Skill
**Location**: `~/.config/opencode/skills/incident-to-agent/` + copied to `command/.agents/skills/incident-to-agent/`

- `SKILL.md` — skill definition with triggers and outputs
- `bin/incident-classifier.sh` — GLM 5.2 style classification (tested: JSON title extraction fixed)
- `bin/incident-to-brief.sh` — generates four-layer brief from classification (tested: fix brief + runbook brief both work)

### 2. Incident Classification (implemented)
```markdown
## Incident Classification

- Type: provider_outage | missing_migration | config_drift | code_regression | unknown
- Actionable: true/false
- Fix: specific fix description (if actionable)
- Priority: P1/P2/P3
```

### 3. Auto-Brief Generation (implemented)
- Actionable incidents → full four-layer brief targeting the fix
- Non-actionable incidents → documentation/update runbook brief
- Includes measurable goal (e.g., "restore API availability to 99.9%")

### 4. Deferred (Requires Captain Credentials/Deployment)
- **`process-event-sources` extension**: Add incident source types (PagerDuty, GH Actions, Vercel, custom health checks)
- **Cron infrastructure**: Vercel/GitHub Actions for polling + render.com for inference
- **`fm-spawn.sh` integration**: Accept incident-triggered briefs
- **`fm-pr-check.sh`/`fm-teardown.sh`**: Track incident-linked PRs/tasks
- **End-to-end test**: Simulate incident → classification → brief → spawn → PR

## Implementation Approach

**Created locally in opencode config first** (`~/.config/opencode/`), then copied to `command` project for MCP registration.

1. Created skill directory: `.config/opencode/skills/incident-to-agent/`
2. Wrote `SKILL.md`: Define triggers, outputs, classification schema
3. Wrote `bin/incident-classifier.sh`: LLM-based classification (JSON parsing fixed, tested on PagerDuty-style payload)
4. Wrote `bin/incident-to-brief.sh`: Four-layer brief generation (fix brief + `--runbook` brief tested)
5. Copied all artifacts to `command/.agents/skills/incident-to-agent/` for MCP registration

## Phases

- [x] Phase 6.1: Create incident-to-agent skill + classifier + brief scripts (2 days)
- [ ] Phase 6.2: Extend process-event-sources with incident sources (1 day) — **deferred, needs captain creds**
- [ ] Phase 6.3: Cron infrastructure (Vercel + render.com) (2 days) — **deferred, needs captain creds**
- [ ] Phase 6.4: Integrate with fm-spawn + fm-pr-check (1 day) — **deferred**
- [ ] Phase 6.5: End-to-end test with simulated incident (1 day) — **deferred**

## Success Criteria

### Automated Verification:
- [x] `bin/incident-classifier.sh` correctly extracts title from PagerDuty-style JSON
- [x] `bin/incident-to-brief.sh` generates valid fix brief + runbook brief
- [ ] Incident webhook triggers classification (deferred)
- [ ] Classification produces actionable/non-actionable verdict (deferred)
- [ ] Actionable incidents generate four-layer brief (deferred)
- [ ] Brief spawns agent via fm-spawn (deferred)
- [ ] PR created and tracked as incident-linked (deferred)

### Manual Verification:
- [ ] "Wake up to PR, not alert" workflow works (deferred)
- [ ] Classification accuracy > 90% on test incidents (deferred)
- [ ] Mean time to PR < 30 minutes (deferred)

## Acceptance Criteria

- [x] Core incident-to-agent skill created and tested locally
- [x] Copied to command project for MCP registration
- [ ] Incident-to-PR pipeline operational for `command` project (deferred)
- [ ] Measurable goal: < 30min incident-to-PR latency within 30 days (deferred)
- [ ] Rollback threshold: < 60min latency triggers review (deferred)
- [ ] Classification accuracy > 90% (deferred)

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Classifier accuracy low | Medium | High | Human-in-loop for first 2 weeks |
| Webhook security | High | High | Signature verification, secret rotation |
| Cron reliability | Medium | High | Multi-region, dead-man switches |
| False positive PRs | Medium | Medium | Require captain approval for P1 |

## References

- Research: `docs/agentic-engineering-workflow.md` (Incident Routing section)
- David Ondrej: GLM 5.2 reviews every uptime incident, cron on Vercel/GH Actions + render.com
- Dex Horthy: "Route the incident straight into the agent pipeline"