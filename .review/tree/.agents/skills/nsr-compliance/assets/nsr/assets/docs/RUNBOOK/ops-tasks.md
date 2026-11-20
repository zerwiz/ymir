# Ops Tasks — __PROJECT__

## Routine
- Health check: `.agents/skills/lifecycle/status.sh`.
- Log review: `.agents/skills/features/<feature>/logs.sh`.
- Token/cost review: `.compliance/telemetry/logger.py`.

## Maintenance Windows
- Document in `docs/HOSTING/<host>.md`.
- Schedule DB migrations outside peak hours.

## Cleanup
- Rotate secrets quarterly per `RULES/security.md`.
- Remove stale feature branches via `.agents/skills/git_ops/sync_upstream.sh`.