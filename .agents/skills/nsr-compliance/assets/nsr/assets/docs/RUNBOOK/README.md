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

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
