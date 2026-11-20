# CI_CD/

Pipeline configuration docs and deployment specs.

## Files
- `build.md`, `test.md`, `release.md` — pipeline stage docs (add as needed).
- `deployment/` — envs, clients, tenants, deploy.sh.

## Rules
- Every pipeline step calls `.agents/skills/` scripts — no ad-hoc inline shell.
- Deploy via `deployment/deploy.sh`.