# hodd/AGENTS.example.md — template for the operator's private contract
#
# Copy to hodd/AGENTS.md (private, untracked). Root AGENTS.md is the PUBLIC
# user contract; this one carries the operator's own context — tenant, private
# plans, secrets, and personal setup — so the public file stays clean.

## Operator

- **Name / handle:** …
- **Tenant(s):** …            # hodd/tenants/<tenant>/
- **Machines:** …             # tailnet names; see hodd/docs/tailscale-sync.md

## Private material

- Plans & strategy: `hodd/docs/` (never `docs/` — Rule 04).
- Secrets: `hodd/secrets/`; load with `eval "$(bin/hodd.sh emit <file>)"`.
- Identity/portfolio: `hodd/identity/`.

## Personal setup

- Agent models/harness: `config/agents.yaml` + per-machine `config/agents.<host>.yaml`.
- Sync between my machines: `bin/tailscale-sync.sh` (see the runbook).

## Notes to Brokk

- …                          # anything the operator wants the agent to know here
