# tenants/

Multi-tenant provisioning & tenant config for shared instances.

## Files
- `<tenant>.env.example` — per-tenant provisioning profile.

## Rules
- Tenant identity is dynamic (per-request), isolated at runtime.
- Tenant-scoped config as templates; data isolation enforced at runtime.
- Never commit tenant secrets.