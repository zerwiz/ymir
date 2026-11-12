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

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
