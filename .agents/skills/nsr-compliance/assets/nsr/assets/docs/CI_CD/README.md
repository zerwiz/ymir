# CI_CD/

Pipeline configuration docs and deployment specs.

## Files
- `build.md`, `test.md`, `release.md` — pipeline stage docs (add as needed).
- `deployment/` — envs, clients, tenants, deploy.sh.

## Rules
- Every pipeline step calls `.agents/skills/` scripts — no ad-hoc inline shell.
- Deploy via `deployment/deploy.sh`.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
