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

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
