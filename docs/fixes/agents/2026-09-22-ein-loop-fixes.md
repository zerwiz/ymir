## agents · unversioned · 2026-09-22 — the loop's first live-use fixes

### Why
The first REAL errand (fleet-verify-001) caught three truths: `--figure kvasir`
resolved to no card (the file is `kvasir-scout.md`), the scout was seated
without the role (classified wrong), and `status` kept showing accepted
errands as arming.

### What
- figure resolution by prefix card search (`kvasir` → `kvasir-scout.md`).
- the scout's seat passes `--role <figure>` through to eindri-start.
- `status` skips ledger rows already accepted/returned/failed.

### Files
- `bin/eindri-dispatch.sh`
