# SVARTALFAHEIM — the company container root

**Single tenant.** There is one operator (the Allfather); there are no person
realms here and no tenants. This tree is the **company's environment** — its
data and, later, its Docker boundary.

```
svartalfaheim/<company>/        # e.g. wayof
├── companies/                  # entity cards for the company's ventures/brands
├── workspace/                  # company-scoped operational memory
│   ├── company/ marketing/ development/ life/ memory/
├── projects/                   # company project working dirs
├── AGENTS.md                   # company persona / directives
  ├── .env.realm.example        # TRACKED company-secret template
  ├── .env.realm                # IGNORED — the real values, machine-local
  └── SECRETS.md                # how company secrets are set up and kept out of git
```

- The **operator's** personal and work scopes live under `workspace/` at the repo
  root (`workspace/work`, `workspace/personal`). A **work** workspace attaches to
  its company container here.
- **Houses** (Ymir Labs, Brokk Forge, …) are brand labels on company cards — not
  isolation, not domains.
- Retired: the multi-tenant realms `way-of`, `zerwiz`, `craig`. The company is
  **WayOf** (`svartalfaheim/wayof`); personal is not a tenant.
- Future: each company here becomes a container; a personalised copy is what a
  new user downloads and runs for their own personal workspace.

Naming: company slugs are lowercase (`wayof`). Never a person realm.
