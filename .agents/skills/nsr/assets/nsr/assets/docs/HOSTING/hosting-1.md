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