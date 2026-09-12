# Hodd — the Allfather's hoard

Hodd (Old Norse *hodd* — a hoard) is the **one private place** for everything
that must never leave the Allfather's hall: secrets, private documents, tenant
material, and identity. Like Andvari's gold, it is guarded — the repository
tracks the guard and this map, never the treasure.

## The law

- **Hodd is private by default.** `hodd/.gitignore` tracks only this README and
  the guard file; everything beneath is untracked, on every clone.
- **Secrets are referenced, never inlined.** Scripts read from Hodd by path
  (`YMIR_HOARD`, default `<repo>/hodd`) — a value never enters a tracked file.
- **`bin/secret-guard.sh` is the outer ward** (pre-commit + CI); Hodd is the
  inner one. Nothing leaves without passing both.
- **Realm boundaries hold.** `hodd/tenants/<tenant>/` is loaded only into that
  tenant's work.

## Layout

| Path | Holds |
|------|-------|
| `hodd/secrets/` | env files, keys, tunnel tokens (`*.env`, `*.key`) |
| `hodd/docs/` | private strategy: masterplan, `plans/`, notebooks |
| `hodd/tenants/` | per-tenant private trees (e.g. `tenants/josef/`) |
| `hodd/identity/` | company + domain entity cards, portfolio, project registry |

Each directory keeps a tracked `*.example` where a shape is useful, so a new
operator knows what belongs without seeing another's contents.

## Loading

```bash
export YMIR_HOARD="${YMIR_HOARD:-$PWD/hodd}"
# secrets
set -a; . "$YMIR_HOARD/secrets/platform.env"; set +a
# a tenant (into that tenant's work only)
eval "$(bin/hodd.sh emit tenants/josef/.env)"
```

## Migrating private material in

Anything currently tracked that is private belongs here instead, then dropped
from git (kept on disk): `docs/masterplan.md`, `docs/plans/*`,
`docs/append-only-log.md`, `svartalfaheim/*/entity.md` + `AGENTS.md`,
`assets/data/aigf-*`, `workspace/projects.yaml`, daily memory notes.
