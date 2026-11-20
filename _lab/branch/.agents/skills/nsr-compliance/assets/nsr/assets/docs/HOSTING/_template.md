# HOSTING — Host Template

Duplicate per hosting provider. Fill all sections before production.

## Overview
- **Provider/Name:**
- **What runs here:**
- **Purpose / SLA:**

## Environments / Deployments
| Env Tier | Target (client/tenant) | Hosting Location |
|----------|------------------------|------------------|
| production | | |
| staging | | |
| development | | |

## Access & Auth
- **Mechanism:** (references only, never raw secrets)
- **Who can deploy:**
- **Secret references:**

## Deployment
- **Deploy command:** `docs/CI_CD/deployment/deploy.sh --env <env> --target <target>`
- **Skill scripts used:**
- **Artifact location:**

## Allowed Operations
- [ ] Deploy via skill script
- [ ] Rollback
- [ ] Restart / scale

## Forbidden Operations
- [ ] Manual live-config edits
- [ ] Exposing logs/secrets
- [ ] Raw `kill` / destructive commands

## Rollback
- *(steps)*

## Gotchas
- *(limits, cost traps, failure modes)*