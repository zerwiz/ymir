# Hosting N — *(provider)*

> Copy `_template.md` structure. Fill all sections before production.

## Overview
- **Provider/Name:** *(fill)*
- **What runs here:** *(fill)*
- **Purpose / SLA:** *(fill)*

## Environments / Deployments
| Env Tier | Target | Hosting Location |
|----------|--------|------------------|
| production | | |
| staging | | |
| development | | |

## Access & Auth
- **Mechanism:** *(fill — references only)*
- **Who can deploy:** *(fill)*
- **Secret references:** *(fill — names only)*

## Deployment
- **Deploy command:** `docs/CI_CD/deployment/deploy.sh --env <env> --target <target>`
- **Skill scripts:** *(fill)*
- **Artifact location:** *(fill)*

## Allowed Operations
- [ ] Deploy via skill script
- [ ] Rollback
- [ ] Restart / scale

## Forbidden Operations
- [ ] Manual live-config edits outside deploy
- [ ] Exposing logs/secrets
- [ ] Raw `kill`

## Rollback
- *(fill steps)*

## Gotchas
- *(fill)*

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
