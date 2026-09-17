# MIDGARD — Shared Design Assets

Cross-tenant assets that are **public by design**: the design system and the
shared libraries any realm may pull.

**What does NOT belong here.** Company knowledge — policies, vision, specs,
client names, wiki pages. That is tenant data, scoped per company, and lives at
`$YMIR_HOME/hodd/identity/companies/`. This repo is public; a company wiki in it
would publish that company's internals.

## Contents
- `design-system/` — shared UI components, design tokens, icon set
- `shared-packages/` — internal npm/cargo/python libraries (public)
- `infrastructure/` — shared Terraform / Docker / Kubernetes configs
- `github_org_repos/` — central repositories
  - `shared-core-api/` — example shared repo (with `.yggdrasil/` worktrees)
