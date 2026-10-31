# Fix: clients register support (plan 128)

**Date:** 2026-10-24
**Plan:** 128 — clients are first-class

## What changed

- **`registry/clients.yaml.example`** — the clients register template (new)
- **`registry/companies.yaml.example`** — the companies register template (new)
- **`registry/projects.yaml.example`** — updated with `client:` field note
- **`bin/identity/clients.sh`** — load, validate, check the clients register (new)
- **`bin/identity/place-validate.sh`** — validate place.yaml `client_of` field (new)
- **`bin/identity/projects-validate.sh`** — validate projects.yaml `client:` field (new)
- **`bin/engine/ymir-install.sh`** — seeds clients.yaml and companies.yaml from templates;
  `--check` mode validates `client_of` references
- **`.agents/migrations/0013-clients-register.sh`** — migration for existing homes

## Why

On 2026-10-24 the Allfather said "opticat are its own company and project. its not ours …
our client" and then "its way of's client." The home had no way to hold that sentence:
companies.yaml holds the houses we ARE, collaborators.yaml holds people, projects.yaml
holds repos, place.yaml holds one company's surface. The one client-shaped realm already
present, inmostinvest, was filed as a house — that is the fault.

## Proof

- `clients.sh validate` passes on the hoard's clients.yaml
- `place-validate.sh` accepts OptiCat's place (declares `client_of: wayof`)
- `place-validate.sh` refuses a place with a client company but no `client_of`
- `place-validate.sh` accepts a house company without `client_of`
- `projects-validate.sh` validates all 23 projects (none have `client:` yet)
- `ymir-migrate.sh status` shows 0013 applied
- `grep -c "projects.yaml" bin/engine/ymir-install.sh` finds no heredoc (only cp)
