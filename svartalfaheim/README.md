# SVARTALFAHEIM — the tenant-container root

**One operator.** There is one operator (the Allfather); there are no person
realms here. This tree holds the operator's own environment(s) — data and, later,
a Docker boundary per tenant.

```
svartalfaheim/<tenant>/          # YOUR tenant — create it for yourself
├── companies/                  # entity cards for ventures/brands
├── workspace/                  # tenant-scoped operational memory
│   ├── company/ marketing/ development/ life/ memory/
├── projects/                   # project working dirs
├── AGENTS.md                   # tenant persona / directives
  ├── .env.realm.example        # TRACKED tenant-secret template
  ├── .env.realm                # IGNORED — the real values, machine-local
  └── SECRETS.md                # how tenant secrets are set up and kept out of git

svartalfaheim/examples/         # shipped examples to copy — never the default
└── wayof/                      # the reference tenant the distro was built for
```

- The **operator's** personal and work scopes live under `workspace/` at the repo
  root (`workspace/work`, `workspace/personal`). A **work** workspace attaches to
  its tenant container here.
- **No tenant is the default.** The runtime resolves the active realm from
  `data/realm.md`, else the first non-example tenant under `svartalfaheim/`, else
  `default` (`bin/realm-lib.sh`). A fresh install ships no tenant of its own —
  only the example under `examples/` to copy.
- **Houses** are brand labels on company cards — not isolation, not domains.
- Future: each tenant here becomes a container.

Naming: tenant slugs are lowercase. Never a person realm.
