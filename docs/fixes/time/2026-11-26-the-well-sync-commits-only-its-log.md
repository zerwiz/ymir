# The well sync commits only its log

**Component:** time (`bin/time/well-vault-sync.sh`)

## What was wrong

The well sync staged its log and then committed the whole index. Files another job had left staged made the
home's pre-commit refuse the well's commit too.

## What changed

Both commits, and the checks before them, name `hodd/memory/well/episodes.jsonl` only. Other staged files stay
staged and uncommitted.

## Proof

`bin/time/tests/test_well_sync_own_path.sh` (gate `well-sync-own-path`).

## CHANGE LOG

- 2026-11-26 — review-mend: added missing heading for #965
