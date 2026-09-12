# Architecture — __PROJECT__

High-level system overview. Detail lives in `docs/` and `docs/features/`.

## System Layers

```
             CLIENTS / TENANTS
                   │
        ┌──────────┴───────────┐
        │  API / Services      │
        │  Frontend / Apps     │
        └──────────┬───────────┘
                   │
             ┌─────┴─────┐
             │   Data    │
             │   (DB)    │
             └───────────┘
```

## Components

- **API / services** — see `TECH_STACK.md` for the stack.
- **Frontend / apps** — see `TECH_STACK.md`.
- **Data layer** — schema, migrations, seed.
- **Deployments** — see `docs/CI_CD/deployment/` (envs, clients, tenants) and `docs/HOSTING/`.

## Multi-Tenancy

- Tenant identity is dynamic (per-request), isolated at runtime.
- Per-client deployments (`docs/CI_CD/deployment/clients/<client>/`) are isolated.
- Shared multi-tenant instances isolate data by tenant at runtime.

## Detail

Deep-dive specs live in `docs/` — `docs/features/` for features, `docs/research/` for background.