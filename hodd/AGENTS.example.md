# hodd/AGENTS.example.md — template for the operator's private contract
#
# Copy to hodd/AGENTS.md (private, untracked). Root AGENTS.md is the PUBLIC
# user contract; this one carries the operator's own context — tenant, private
# plans, secrets, and personal setup — so the public file stays clean.

## Operator

- **Name / handle:** …
- **Private plans, secrets:** `$YMIR_HOME/` — never inline; reference by path.

## Private material

- Plans & strategy: `$YMIR_HOME/docs/` (never `docs/` — Rule 04).
- Secrets: `$YMIR_HOME/secrets/`; load with `eval "$(bin/secret-guard.sh emit <file>)"`.
- Identity/portfolio: `$YMIR_HOME/identity/`.

## Personal setup

- Agent models/harness: `config/agents.yaml` + per-machine `config/agents.<host>.yaml`.
- Sync between my machines: `bin/tailscale-sync.sh` (see the runbook).

## Notes to Brokk

- …                          # anything the operator wants the agent to know here
