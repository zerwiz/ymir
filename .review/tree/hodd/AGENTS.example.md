# hodd/AGENTS.example.md — template for the operator's private contract

Copy to `hodd/AGENTS.md` (private, untracked — hodd tracks only `README.md`
and `*.example`). The **root `AGENTS.md`** (`$YMIR_HOME/AGENTS.md`) is the
private home contract; the repo's `AGENTS.md` is the PUBLIC user contract.
This one carries the operator's own context — tenants, private plans, secrets,
personal setup — so the public file stays clean.

## Operator

- **Name / handle:** …
- **Machines:** … (LAN + ssh aliases; facts: `hodd/data/machines.md`)

## The one law

**Never store personal or private data in the public repo.** Not a secret, a
key, a name, a plan, a schedule, a client, a credential, or a note. Private
data lives at `$YMIR_HOME`, under `hodd/`, and nowhere else.

## The private layout (current, 2026-09-17)

`$YMIR_HOME` (default `~/Documents/ymirhome`, resolved by `bin/hoard-lib.sh`
`hoard_root`) is the private git repo. `hodd/` **is** the hoard; everything
else under the home is runtime or realm material.

```
$YMIR_HOME/
├── README.md                    # home map (tracked)
├── AGENTS.md                    # private home contract (tracked)
├── .ymir-layout.yaml            # the layout map (validated by the placement ward)
├── hodd/                        # THE HOARD — guard tracks only README + *.example
│   ├── data/                    # operator data: machines, fleet, inventories
│   ├── docs/                    # masterplan.md, business/, daily/, server-knowledge/
│   ├── identity/                # company/domain entity cards, portfolio
│   ├── memory/                  # runes ledger, daily logs, the well
│   ├── plans/                   # live working plans (omarchy/…)
│   ├── secrets/                 # platform.env (+ .age) + age.key — by path, never inline
│   ├── state/                   # runtime state; stale-* backups (dropped-from-git storage)
│   └── workspaces/              # marketing/ personal/ work/
├── svartalfaheim/<realm>/workspace/<project>/plans/   # the plan LEDGER — one canonical shelf per project (tracked)
├── config/                      # agents.yaml + per-machine overlays, cron.yaml
├── smidja/  state/              # factory + runtime state (ephemeral)
└── svartalfaheim/<realm>/       # per-realm scoped material (never crossed without word)
```

Rule of thumb: **the hoard holds what must never leave; the archive
(`memory/plans/`) holds what must sync between machines.** Plans that are
still living live in `hodd/plans/`; settled plans are filed into
`memory/plans/<domain>/`.

## Where material goes

| Kind | Path |
|------|------|
| Business / strategy | `hodd/identity/companies/` |
| Marketing / social | `hodd/workspaces/marketing/` |
| Software specs | `hodd/workspaces/work/` |
| Personal / schedules | `hodd/workspaces/personal/` |
| Daily logs | `hodd/memory/daily/YYYY-MM-DD.md` |
| Plans (live) | `hodd/plans/` |
| Plans (archive) | `memory/plans/<domain>/` |
| Global audit ledger | `hodd/memory/runes_audit.md` |
| Secrets | `hodd/secrets/platform.env` — referenced by path, never inline |

## Secrets

```bash
eval "$(bin/hodd.sh emit secrets/platform.env)"   # decrypts in memory
```
`hodd/secrets/` stores `platform.env` (+ encrypted `platform.env.age`) and
`age.key`. A value never enters a tracked file. **Staging discipline:** stage
named files in the home; **never `git add -A`** — a scratch file sweeping into
a commit and pushing is the incident this rule exists to prevent.

## Realms

Scope every operation to the active realm (`svartalfaheim/<realm>`); a realm
carries its own `.env.realm` and never touches another without the word.

## Notes to Brokk

- …   # anything the operator wants the agent to know here