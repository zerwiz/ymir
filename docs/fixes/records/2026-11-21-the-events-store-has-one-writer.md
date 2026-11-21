## records · unversioned · 2026-11-21 — the events store: one writer, two sources (plan 333 phase 1)

### Why
Plan 333 (Skíðblaðnir) and plan 332 need one record of what happened on the house. Cron failures
and Garmr findings each reached a person only through the hotline, and left nothing a keeper or a
console could read back.

### Files
- `bin/records/events.py` (new) — validation, dedupe, append, tail and search
- `bin/records/events-append.sh`, `events-tail.sh`, `events-search.sh` (new) — the doors; they resolve the home through `bin/vault/hoard-lib.sh`
- `bin/time/nornir-cron-start.sh` — a failed job also appends a HIGH row, keyed like its hotline alert
- `bin/ward/garmr/brain.py` — a judged non-INFO finding appends a row (best-effort)
- `tests/test_events_store.sh` (new), `docs/features/the-events-store.md`, `docs/features/_catalogue/entries/02-133-the-events-store.md`

### What
Rows carry exactly seven fields and are refused when invalid. The same key on the same day is
written once, under a file lock. Day files are `<state>/events/YYYY-MM-DD.jsonl`. Neither source
can fail its caller if the store cannot be written.

### Verified
`bash tests/test_events_store.sh` passes: validation, dedupe, tail and search, a real scheduler
pass with a failing fixture job, and a judged Garmr fixture finding. Both source tests run with the
hotline, the rune and the voice stubbed or absent, so nothing was sent.

### Not done
Phases 2 to 5 of plan 333. The second-machine proof from a release is owed after the PR merges.

## CHANGE LOG

- **2026-11-21** — opened.
