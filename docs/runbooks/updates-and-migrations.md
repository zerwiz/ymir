# Runbook — updating the runtime and healing old homes

## Update the code

```bash
bin/brokk-update.sh          # fast-forward this home + every registered Eindri-home
```
It never forces or stashes; it reports one row per target. After updating, run
the structure migrations below.

## Structure migrations (old homes heal forward)

Versioned, idempotent scripts in `.agents/migrations/` transform an older home
into the current layout (e.g. `0001-hodd-layout` moves private material into
`hodd/`).

```bash
bin/ymir-migrate.sh status            # what exists / what is applied
bin/ymir-migrate.sh apply --dry-run   # show what would run
bin/ymir-migrate.sh apply             # apply pending, in order
```
Applied ids are recorded in `state/migrations` (private). Each migration must be
idempotent — re-running is safe. `bin/ymir-install.sh` and `bin/brokk-update.sh`
call `apply` after an update.

## Add a migration

1. Create `.agents/migrations/NNNN-<name>.sh` (next number), idempotent.
2. It runs with `bash` from the repo; move/transform, print what it did.
3. Test: `bin/ymir-migrate.sh apply --dry-run`, then `apply`.

## First-time setup

```bash
bin/ymir-install.sh            # full setup (idempotent)
bin/ymir-install.sh --check    # all steps OK/WARN
```
