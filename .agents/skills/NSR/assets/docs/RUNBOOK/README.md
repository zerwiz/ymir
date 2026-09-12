# RUNBOOK/

Operational procedures. Step-by-step, reproducible.

## Files

- `deployment.md` — Pre-deploy checks, rollout, post-deploy verify.
- `disaster-recovery.md` — Restore, backup verification, escalation.
- `ops-tasks.md` — Routine ops (log rotation, health checks).
- *(add more as needed)*

## Rules

- Procedures invoke `.agents/skills/` scripts — never ad-hoc commands.
- Every step must be reproducible by an agent or on-call engineer.