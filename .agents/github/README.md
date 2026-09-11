# HEIMDALL & MJOLLNIR — GitHub Integration

Zero-trust GitHub CI/CD, webhook security, and autonomous Issue-to-PR pipeline.

## Webhooks
- `webhooks/issue_listener.ts` — receives `issues.opened` events, verifies HMAC

## Workflows
- `workflows/deploy-staging.yml`
- `workflows/deploy-production.yml`

## Rules
- Webhooks verified via HMAC signature
- Secrets injected via `gh secret set` — never committed
- Mjollnir never force-merges