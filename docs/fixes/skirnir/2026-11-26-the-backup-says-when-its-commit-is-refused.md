# The backup says when its commit is refused

**Component:** skirnir (`systems/skirnir/services/backup.sh`)

## What was wrong

When the home's pre-commit refused the snapshot, the backup still printed `backup: commit made, push failed`.
The push message did not depend on the commit. 1,701 files stayed staged, and the next home commit was refused
too.

## What changed

- A refused `git add` or `git commit` exits 4 and prints a `backup: FAILED` line that names the refusal.
- On failure the shelf's index entries go back to what they were before the run. Earlier staging and other
  jobs' files are not touched.
- The commit names `hodd/saves/assistant`, so another job's staged files never ride along.
- The push runs only after a commit succeeded. A failed push still exits 0 and says so.

## Proof

`systems/skirnir/tests/test_backup_honest.sh` (gate `backup-honest`).

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #965
