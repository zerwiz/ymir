# Security Rules — __PROJECT__

## Access Control
- Auth via the project's identity provider; roles scoped per tenant.
- API tokens required on every request; tenant resolved per-request from token claims.

## Secrets
- Never commit secrets. All secrets via env / secret manager.
- `.env` is git-ignored; only `.env.example` templates are committed.
- Keys injected at deploy time via `docs/CI_CD/deployment/deploy.sh` + secret manager.

## Tenant Isolation
- Queries are scoped by tenant at the DB layer — never fetch across tenants.

## Vulnerability Gates
- `.compliance/gates/check_env.sh` fails if required secrets are absent.
- Dependencies pinned in `TECH_STACK.md`; no floating/latest in production.
- Run `.agents/skills/features/<feature>/test.sh` before any PR.

## Enforced By
- `.compliance/gates/*` — exit-code gates.
- CI deploy order: `check_env → check_paths → check_platform → validate_code`.