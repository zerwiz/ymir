## snotra · unversioned · 2026-10-21 — the access log is a hash chain

### What

`sensitive-gate.sh` now writes each access decision with `prev` and `entry`, a SHA-256 over
the canonical entry. `snotra-evidence.sh verify-access` recomputes the chain and fails at
the first broken entry. Legacy unchained lines are counted separately.

### Verified

- Synthetic suite 8/8: held refused on Trello, private allowed, tampered manifest refused,
  timestamp/cert written, chain valid, tampered chain refused.
- The pilot log reports `valid, 4 chained, 6 legacy`.

### Not verified

- Off-host shipping and a signed log head; those remain plan 94.
