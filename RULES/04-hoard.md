# Rule 04 — Hodd, the private hoard, and YMIR_HOME

Every private thing the Allfather holds lives in **one** place: **Hodd**
(`hodd/`) at the repo, and **YMIR_HOME** (`$HOME/Documents/Ymir/`) as the
shareable private repo. *Hodd* is Old Norse for a hoard — guarded, and
never shown. The repo holds the **framework** (scaffolds, guards,
templates); the data lives at **YMIR_HOME**, committed and pushed to a
private GitHub repo so it can be shared between machines.

## What belongs in Hodd (at the repo)

Only **scaffolds and guards** live at the repo path `hodd/`:

- **Guards** — `hodd/.gitignore` (inner ward, tracks only itself, README,
  and `*.example` shapes)
- **README** — `hodd/README.md` (this map of the hoard)
- **Scaffolds** — `hodd/AGENTS.example.md`, `hodd/**/*.example` (templates
  so a new operator knows what belongs)

## What lives at YMIR_HOME (the real hoard)

All private data is committed to the **private YMIR_HOME git repo** and
pushed to a **private GitHub repo** for multi-machine sync. It is **NOT**
gitignored — the user owns it and shares it between computers:

| Repo location | YMIR_HOME location |
|---|---|
| `hodd/docs/` | `$YMIR_HOME/docs/` |
| `hodd/secrets/` | `$YMIR_HOME/secrets/` |
| `hodd/identity/` | `$YMIR_HOME/identity/` |
| `hodd/tenants/` | `$YMIR_HOME/tenants/` |
| `data/` | `$YMIR_HOME/data/` |
| `memory/kaia.engram*` | `$YMIR_HOME/memory/` |

## The law

- **Hodd at the repo is untracked.** `hodd/.gitignore` tracks only the guard
  and the README; everything beneath is private on every clone. A clone
  must never inherit another operator's hoard.
- **YMIR_HOME is committed.** All private data at YMIR_HOME is committed
  to the user's **private** git repo and pushed to a private GitHub repo
  for sync between machines. It is never gitignored (except runtime
  ephemera like `*.wal`, `*.shm`, `smidja/`, `state/`).
- **Secrets are referenced, never inlined.** Read them by path — `YMIR_HOARD`
  (default `$YMIR_HOME`), `bin/hodd.sh emit <file>` to set them in a shell. A
  value never enters a tracked file, a commit, or a document.
- **Two wards.** `bin/secret-guard.sh` is the outer ward (pre-commit + CI);
  `hodd/.gitignore` is the inner one. Nothing leaves without passing both.
- **Realm boundaries are sacred.** Private data at YMIR_HOME is
  scoped per operator; a clone must never inherit another's hoard.
- **The public tree keeps only the framework** (lore, architecture, scaffold)
  and `*.example` shapes.
- A change that contradicts this rule must change the rule first (append-only;
  never silently rewritten).

## docs/ is public — plans are not

`docs/` is the **public, user-facing** tree: it holds what a user of Ymir may
read. Operator-private documents — plans, strategy, roadmaps, the masterplan,
`append-only-log`, and project planning — belong in `hodd/docs/` at the repo
(never `docs/`), or live at `$YMIR_HOME/docs/` in the private repo.

`bin/docs-guard.sh` blocks a commit that stages such a document under `docs/`
(wired into the pre-commit hook beside `secret-guard.sh`). When it fires, move
the file to `$YMIR_HOME/docs/` in the private repo.
