# Hodd — the Allfather's hoard

Hodd (Old Norse *hodd* — a hoard) is the **one private place** for everything
that must never leave the Allfather's hall: secrets, private documents, tenant
material, and identity. Like Andvari's gold, it is guarded — the repository
tracks the guard and this map, never the treasure.

## The law

- **Hodd is private by default.** `hodd/.gitignore` tracks only this README and
  the guard file; everything beneath is untracked, on every clone.
- **Secrets are referenced, never inlined.** Scripts read secrets from
  `$YMIR_HOME/secrets/` (`YMIR_HOARD`, default `$HOME/Documents/Ymir`);
  a value never enters a tracked file.
- **`bin/secret-guard.sh` is the outer ward** (pre-commit + CI); Hodd is the
  inner one. Nothing leaves without passing both.
- **Realm boundaries hold.** Data at `$YMIR_HOME` is scoped per operator;
  a clone must never inherit another's secrets.

## Layout

| Path | Holds |
|------|-------|
| `hodd/` (this file) | Map of the Hoard |
| `hodd/.gitignore` | Inner ward — tracks only this README + the guard |
| `hodd/AGENTS.example.md` | Template for the operator's private contract |
| `$YMIR_HOME/docs/` | Private strategy: masterplan, plans, notebooks |
| `$YMIR_HOME/secrets/` | env files, keys, tunnel tokens |
| `$YMIR_HOME/identity/` | company + domain entity cards, portfolio |

Each directory keeps a tracked `*.example` where a shape is useful, so a new
operator knows what belongs without seeing another's contents.

## Loading

```bash
export YMIR_HOARD="${YMIR_HOARD:-$HOME/Documents/Ymir}"
# secrets
set -a; . "$YMIR_HOARD/secrets/platform.env"; set +a
```

## Migrating private material in

Anything currently tracked that is private belongs at `$YMIR_HOME/` instead,
then dropped from git (kept on disk): `docs/masterplan.md`, `docs/plans/*`,
`docs/append-only-log.md`, `identity/*`, `data/*`, `memory/*`.
