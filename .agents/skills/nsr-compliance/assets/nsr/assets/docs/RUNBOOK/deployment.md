# Deployment Runbook — __PROJECT__

## Pre-Deploy
1. Run gates: `.compliance/gates/check_env.sh`, `check_paths.sh`, `check_platform.sh`.
2. Run feature tests: `.agents/skills/features/<feature>/test.sh`.
3. Confirm release tag from `docs/CI_CD/release.md`.

## Deploy
1. `docs/CI_CD/deployment/deploy.sh --env production --target client:<name>` (or `tenant:<name>`).
2. Verify with `.agents/skills/lifecycle/smoke_test.sh`.

## Post-Deploy
1. `.agents/skills/lifecycle/status.sh` → health check.
2. Watch telemetry via `.compliance/telemetry/logger.py`.
3. Update `docs/HOSTING/<host>.md` if anything changed.

## Rollback
- `.agents/skills/features/<feature>/rollback.sh` → previous release tag.
- Confirm in `docs/HOSTING/` doc + postmortem if needed.