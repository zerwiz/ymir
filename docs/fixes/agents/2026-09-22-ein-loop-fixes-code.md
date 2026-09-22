## agents · unversioned · 2026-09-22 — ein-loop first-live-use fixes (the code)

### What
- figure resolution by prefix card search (`kvasir` → `kvasir-scout.md`);
  the plan's craft section cites the RESOLVED card.
- the scout's seat passes `--role <figure>` through to eindri-start.
- `status` skips ledger rows already accepted / returned / failed.

### Files
- `bin/eindri-dispatch.sh`

### Proof
syntax green; the figure gate accepts a prefix name; seat_args carries the
role (the first live scout was classified wrong — now it is named).
