# API Best Practices — __PROJECT__

## REST Design
- Resource-based URLs under a versioned prefix (`/api/v1/...`).
- JSON everywhere; camelCase fields.

## Versioning
- Breaking changes → new major version (`/api/v2`).
- Deprecations documented in `docs/features/`.

## Error Handling
- Consistent error envelope: `{ error: { code, message, details } }`.
- 4xx for client errors, 5xx for server errors; never leak stack traces.
- Log errors with context via `.agents/skills/features/*/logs.sh`.

## Enforced By
- `.agents/skills/features/<feature>/test.sh` (API contract tests).