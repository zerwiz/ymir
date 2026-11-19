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

## The private layout — read it from the YAML, never from this page

`$YMIR_HOME` (default `~/Documents/ymirhome`, resolved by `bin/vault/hoard-lib.sh`
`ymir_home_root`) is the private home. **Where each shelf lives is written in two files, and this page
does not restate it** (plan 331: a document points at the YAML, because the YAML says how *this* home
actually is):

- `$YMIR_HOME/.ymir-layout.yaml` — the home's shape: every shelf and its path (template:
  `hodd/.ymir-layout.yaml.example` in the code repo). Eir's `hoard` surface refuses a map that names a
  path that does not exist.
- `$YMIR_HOME/hodd/identity/home.yaml` — the master register: every register in the home, the shelf
  each one governs, and the layout version (template: `hodd/identity/home.yaml.example`).

What the page keeps is the rule the YAML cannot say — **four shelves, one kind of material each**:

| Shelf | Owns | Must never hold |
|---|---|---|
| `hodd/` | the **record**: memory, identity, plans, secrets, reference, docs | runtime artefacts, the operator's own material, build output |
| `life/` | the **operator's own material**: personal, work, marketing, meetings, outreach | the house's ledger, a secret, runtime state |
| `state/` | **runtime state** written by supervisors | anything append-only, anything another machine must read |
| `config/` | **settings**, per machine and per person | a secret value, a record |

Company and project material lives in its realm (`svartalfaheim/<realm>/`); each project's plan ledger is
discovered by `bin/vault/hoard-lib.sh` `ymir_plan_dir`, never typed here.

## Where material goes

| Kind | Shelf (the path is in `.ymir-layout.yaml`) |
|------|------|
| Business / strategy | the company's realm under `svartalfaheim/` |
| Marketing / social, software specs, personal notes, meetings, outreach | `life/<topic>/` |
| Daily logs, the runes ledger, the well | `hodd/memory/` — append-only, never moved |
| Plans (personal, live) | `hodd/plans/` |
| Secrets | `hodd/secrets/` — referenced by path, never inline |
| Anything a running program writes | `state/` |

## Secrets

```bash
eval "$(bin/vault/hodd.sh emit secrets/platform.env)"   # decrypts in memory
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

## CHANGE LOG

- **2026-11-12** — this document gained a CHANGE LOG section so it carries its history (RULES/06). Its earlier history is its git log; entries are appended below, never rewritten.
- **2026-11-19** — plan 331: the layout tree (dated 2026-09-17) and the "where material goes" table that named `hodd/life/*`, `hodd/state/` and `hodd/workspaces/` were replaced by the four shelves and by pointers to `.ymir-layout.yaml` and `hodd/identity/home.yaml`. The old tree is in this file's git history; a home still in that shape is moved by migration `0026-life-and-state-out-of-hodd`.
