# CI_CD/deployment/

Env-driven deployment specifications. Multiple deployments per project: env tiers, per-client, and shared multi-tenant instances.

## Layout

```
deployment/
├── envs/                    # Per-environment base templates
│   ├── development.env.example
│   ├── staging.env.example
│   └── production.env.example
├── clients/                 # Per-client deployments
│   └── <client>/            # staging.env.example, production.env.example
├── tenants/                 # Multi-tenant provisioning
│   └── <tenant>.env.example
└── deploy.sh                # Env-driven deploy runner
```

## Rules
- Templates only committed; real values injected at deploy time.
- Client/tenant identity is an env input, never hardcoded.
- Run `.compliance/gates/*` before any deploy.