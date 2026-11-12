# mail · 2026-11-12 — the mail job passes the real tree to the importer

## Files
- `bin/time/nornir-job-gna-mail.sh` — exports `YMIR_TREE` as the job's own root before the importer runs

## Why
The mail job called `gna_import.py` without `YMIR_TREE`. The importer defaults to `~/ymir`, so on any machine where
the checkout lives somewhere else the vault door was missing (`No such file: ~/ymir/bin/vault/hodd.sh`). The job
could never read mail.

## Fix
The job exports `YMIR_TREE="${YMIR_TREE:-$ROOT}"` before the importer runs. A value the operator set still wins. The
desk's own service already sets `YMIR_TREE`, so only the scheduled job was affected.

## Verified
- `bash -n bin/time/nornir-job-gna-mail.sh` passes.
- With the checkout outside `~/ymir`, a dry-run import (`gna_import.py --dry-run --days 1`) read the mailbox and
  classified the messages instead of failing on the missing vault door.

## CHANGE LOG

- **2026-11-12** — note written; the fix was carried over from the operator's fork onto upstream main.
