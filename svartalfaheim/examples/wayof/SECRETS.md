# Where this company's secrets live

One rule: **a secret is never committed.** The tracked file is always a template;
the real file is always git-ignored, and it stays on the machine that uses it.

```
svartalfaheim/examples/wayof/
├── .env.realm.example        # TRACKED — the template (this is what you copy)
├── .env.realm                # IGNORED — the real values, machine-local
└── companies/<company>/
    ├── .env.example          # TRACKED — a venture's own template
    └── .env                  # IGNORED — a venture's own values
```

## Set it up

```bash
cd svartalfaheim/examples/wayof
cp .env.realm.example .env.realm     # then fill in what this company actually uses
```

Nothing else is required: the runtime finds it by path. `bin/saga-session-start.sh`,
the `bin/nornir-job-*.sh` jobs, `bin/workspace-rag.sh` and the Hlidskjalf gate all
read `svartalfaheim/<realm>/.env.realm` for the **active realm** — resolved from
`data/realm.md`, else the first non-example tenant under `svartalfaheim/`, else
`default`; it can also be set with `BROKK_REALM`. The values are loaded into the
process environment; they are never printed, echoed into a log, or written to a rune.

An empty value is honest. A placeholder that looks real is worse than nothing —
it silently pretends a service is wired when it is not.

## A venture with its own accounts

When a company must not share credentials with the rest (a separate Stripe
account, its own database), give it its own pair:

```bash
cd svartalfaheim/examples/wayof/companies/<company>
cp .env.example .env
```

## Why the split is enforced, not just documented

| Guard | What it does |
|---|---|
| `.gitignore` | `svartalfaheim/*/.env*` and `svartalfaheim/*/*/.env*`, with `!*.example` so the templates stay tracked |
| `bin/secret-guard.sh` | blocks a commit that stages a real env file, or content shaped like a credential |
| `bin/public-guard.sh` | blocks operator-private content from reaching the public tree at all |
| `RULES/` | the law behind both: platform secrets in `.env.local`, realm secrets in `.env.realm`, never inline |

Verify whenever you change any of this:

```bash
git check-ignore -v svartalfaheim/examples/wayof/.env.realm     # must be ignored
git status --short svartalfaheim/                      # must never list a real .env
bin/secret-guard.sh                                    # must pass on the staged change
```

## If a secret ever does land in git

Rotate it first, then clean: the value is in the history and in every clone, so
the credential must be considered spent. `git rm --cached` hides it from the next
commit and does not un-leak it.
