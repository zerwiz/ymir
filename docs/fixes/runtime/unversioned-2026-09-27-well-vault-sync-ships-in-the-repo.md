# runtime · 2026-09-27 — `well-vault-sync.sh` ships in the repo; the `@heart 06:35` row resolves again

## Why
The heart's `config/cron.yaml` declares `@heart 06:35 bin/well-vault-sync.sh
--mode push`, but the scheduler runs every job with `cwd = $BROKK_HOME` (the
**repo** root) and `well-vault-sync.sh` existed **only** under
`$YMIR_HOME/bin/` — it was absent from the repo `bin/` on every seat. So the
heart's memory-checkpoint push failed every 06:35, silently (exit non-zero into
`cron.log`). This is D1 of the 2026-09-27 heart stand-up report. The home's own
rule is explicit: every path in `config/cron.yaml` must be a REPO-relative
command.

Second finding, measured during the cutover: **`sqlite3` is absent on the fleet's
seats.** The script's `PRAGMA wal_checkpoint(TRUNCATE)` was guarded by
`command -v sqlite3`, so it silently no-op'd — the stores rode multi-MB WALs. The
well never left its WAL.

## What
- **Shipped `bin/well-vault-sync.sh` into the repo** (the same script the home
  holds), so the `@heart 06:35` row resolves at the repo-relative path the
  scheduler runs. The script's own resolution (`YMIR_HOME`, default
  `~/Documents/ymirhome`; named-file staging only, never `git add -A`; never
  force) is unchanged.
- **Python fallback for the WAL checkpoint.** When `sqlite3` is absent, the
  stdlib `python3` `sqlite3` module runs the same `PRAGMA wal_checkpoint(TRUNCATE)`.
  A missing CLI must never leave the WAL un-checkpointed.

## Files
- `bin/well-vault-sync.sh` (new in the repo)
- `.agents/skills/galdr-ymirsystem/assets/memory-well.md` (component table)

## Verified
- `bash -n bin/well-vault-sync.sh` — clean.
- `bash bin/well-vault-sync.sh --help` — resolves from the repo root (the
  scheduler's `cwd`).
- The `@heart 06:35 bin/well-vault-sync.sh --mode push` row now names a file
  that exists under `$BROKK_HOME/bin/`.
