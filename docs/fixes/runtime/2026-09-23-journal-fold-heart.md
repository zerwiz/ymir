## runtime · unversioned · 2026-09-23 — the heart folds the journals (plan 51 Phase 2b, heart side)

### Why
- **Problem:** the body side of P2b was built (append + push to `~/.ymir-inbox`),
  but nothing on the heart **folded** the inbox into the record — the loop was
  open at the far end.
- **Fix:** `bin/journal-receive.sh` — the **only writer** that folds bodies'
  journals in (Law 7):
  - dedupes by **idempotency key**, so a replay after a partial push is a no-op;
  - appends new entries to `$STATE/journal/folded/<host>.jsonl` — one canonical
    log per machine, so no two machines ever write the same chain;
  - archives a fully-folded inbox file to `~/.ymir-inbox/folded/`.
  `--dry-run` reports what would fold; `--status` shows waiting/folded; the
  inbox path is overridable (`YMIR_JOURNAL_INBOX`).

### Verified
- `.agents/tests/journal-fold.test.sh` — **ALL PASS**: two entries folded; the
  folded log holds both; the inbox file is archived; replaying the **same** keys
  folds **0** new and the log stays at 2; `--status` reports.
- `bash -n` clean.

### Files
- `bin/journal-receive.sh`
- `.agents/tests/journal-fold.test.sh`
