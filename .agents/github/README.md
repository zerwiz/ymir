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

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
