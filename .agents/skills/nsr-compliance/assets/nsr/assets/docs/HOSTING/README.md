# docs/HOSTING/

Per-hosting core info — never break production.

## Consolidated Hosting List

1. **Hosting 1 — *(provider)*:** runs *(services)* for *(clients/tenants/envs)*; access via *(secret manager / service account)*; **critical rule:** always deploy via skill scripts, no manual live-config edits.
2. *(add each hosting here)*

## Core Rules

1. Never break hosting — ops via `.agents/skills/` scripts only.
2. No raw secrets — reference env/secret-manager names.
3. Relative paths only; cross-platform.
4. Every production hosting documented here + per-host file.
5. Rollback path exists for every host.

## Per-Host Files

- `_template.md` — copy for a new host.
- `hosting-N.md` — explicit doc per hosting.

## Verification

- `.compliance/gates/verify_docs.py` checks every hosting has a doc.