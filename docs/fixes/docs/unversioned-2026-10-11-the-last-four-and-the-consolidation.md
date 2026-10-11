## docs · unversioned · 2026-10-11 — the last four how-tos, and all feature docs consolidated

### What

Two things:

1. Filled the last four blank `how-to` links in `FEATURES.md`:
   `the-vault-hnitbjorg.md`, `smidja-and-volundr.md`, `nornir-the-schedule.md`,
   `the-well-sync.md` — so **every row in the catalogue now links a page.**
2. **Consolidated the five feature-docs PRs** (#317, #318, #319, #321, #322), which all
   edited `FEATURES.md` and so conflicted, into this ONE branch
   (`yggdrasil/features-all`), resolving `FEATURES.md` by keeping every link.

### Verified

- `grep -c '| — |' FEATURES.md` → **0** (no blank how-tos remain).
- `docs/features/*.md` → 31 pages.
- `guards.sh` — all seven wards PASS, `features-guard` included.
