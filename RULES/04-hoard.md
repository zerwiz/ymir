# Rule 04 — Hodd, the private hoard

Every private thing the Allfather holds lives in **one** place: **Hodd**
(`hodd/`). *Hodd* is Old Norse for a hoard — guarded, and never shown.

## What belongs in Hodd

- **Secrets** — env files, keys, tunnel tokens (`hodd/secrets/`).
- **Private documents** — masterplan, plans, notebooks (`hodd/docs/`).
- **Tenant material** — each tenant's private tree (`hodd/tenants/<tenant>/`).
- **Identity** — company & domain entity cards, portfolio, project registry
  (`hodd/identity/`).

## The law

- **Hodd is untracked.** `hodd/.gitignore` tracks only the guard and the README;
  everything beneath is private on every clone. A clone must never inherit
  another operator's hoard.
- **Secrets are referenced, never inlined.** Read them by path — `YMIR_HOARD`
  (default `<repo>/hodd`), `bin/hodd.sh emit <file>` to set them in a shell. A
  value never enters a tracked file, a commit, or a document.
- **Two wards.** `bin/secret-guard.sh` is the outer ward (pre-commit + CI);
  `hodd/.gitignore` is the inner one.
- **Realm boundaries are sacred.** `hodd/tenants/<tenant>/` is loaded only into
  that tenant's work — never across realms.
- **The public tree keeps only the framework** (lore, architecture, scaffold)
  and `*.example` shapes.
- A change that contradicts this rule must change the rule first (append-only;
  never silently rewritten).
