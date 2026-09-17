# hodd/AGENTS.example.md — template for the operator's private contract
#
# Copy to hodd/AGENTS.md (private, untracked). Root AGENTS.md is the PUBLIC
# user contract; this one carries the operator's own context — tenant, private
# plans, secrets, and personal setup — so the public file stays clean.

## Operator

- **Name / handle:** …
- **Machines:** …

## The one law

**Never store personal or private data in the public repo.** Not a secret, a
key, a name, a plan, a schedule, a client, a credential, or a note. Private data
lives at `$YMIR_HOME`, under `hodd/`, and nowhere else.

## Private material (never in the public tree — Rule 04)

**`$YMIR_HOME/hodd/` IS the private data path** — there is no flat second copy.
`bin/hoard-lib.sh` (`hoard_root`) resolves it and is the single source of truth.

- Plans & strategy: `$YMIR_HOME/hodd/docs/` (never `docs/` — Rule 04).
- Identity / portfolio / registries: `$YMIR_HOME/hodd/identity/`.
- Operator data (machines, fleet, inventories): `$YMIR_HOME/hodd/data/`.
- Secrets: `$YMIR_HOME/hodd/secrets/` — encrypted (`platform.env.age` + `age.key`).
  Read by path, never inline: `eval "$(bin/hodd.sh emit secrets/platform.env)"`.

**Staging discipline:** stage named files in the home; **never `git add -A`** —
a scratch file will be swept into a commit and pushed.

## Personal setup

- Agent models/harness: `config/agents.yaml` + per-machine `config/agents.<host>.yaml`.
- Sync between my machines: `bin/tailscale-sync.sh` (see the runbook).

## Notes to Brokk

- …                          # anything the operator wants the agent to know here
