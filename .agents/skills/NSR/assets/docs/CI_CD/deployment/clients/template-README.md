# Client: <name>

Per-client deployment for a client.

## Templates
- `staging.env.example`
- `production.env.example`

## Rules
- Deploy via `docs/CI_CD/deployment/deploy.sh --env <env> --target client:<name>`.
- Client-specific branding/features come from these templates.