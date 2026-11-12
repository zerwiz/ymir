# tenants/

Multi-tenant provisioning & tenant config for shared instances.

## Files
- `<tenant>.env.example` — per-tenant provisioning profile.

## Rules
- Tenant identity is dynamic (per-request), isolated at runtime.
- Tenant-scoped config as templates; data isolation enforced at runtime.
- Never commit tenant secrets.

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
