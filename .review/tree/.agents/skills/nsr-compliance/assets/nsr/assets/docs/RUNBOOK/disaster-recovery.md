# Disaster Recovery — __PROJECT__

## Backup
- DB backups on a schedule via `.agents/skills/features/*/setup.sh` (or a backup job).
- Verify backups restore monthly.

## Restore Procedure
1. Stop traffic: `.agents/skills/lifecycle/stop.sh`.
2. Restore DB from latest backup.
3. Start: `.agents/skills/lifecycle/start.sh`.
4. Verify: `.agents/skills/lifecycle/smoke_test.sh` + `status.sh`.

## Incident Escalation
- On-call engineer → `docs/DEVELOPER_SETUP/developers/*.md` for owners.
- Post-incident: write a postmortem in `docs/research/`.