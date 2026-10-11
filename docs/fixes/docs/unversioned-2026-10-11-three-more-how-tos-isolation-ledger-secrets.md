## docs · unversioned · 2026-10-11 — three more how-tos (isolation · the ledger · the secrets vault)

### What

Continues Rule 14's catalogue debt, three more user pages:

- `docs/features/yggdrasil-and-utgard-isolation.md` — worktrees per task
  (`bin/forge/yggdrasil.sh`) and the sealed sandbox (`bin/forge/utgard.sh`, sandcastle),
  with herdr as the ordinary road and Utgard as the barrier.
- `docs/features/the-plan-ledger-and-runes.md` — where plans live (the project shelf +
  `register.md`), the append-only Runes ledger (`runes-append.sh`, `runes-project.sh`,
  `ymir-state.sh`), and the chain law.
- `docs/features/the-secrets-vault.md` — the hoard resolver (`bin/vault/hodd.sh`
  path/init/ls/load/emit/tenant), the age-encrypted secrets, and the wards.

`FEATURES.md` rows for isolation, the record, and the secrets vault now link the pages.

### Verified

- `guards.sh` — all seven wards PASS, `features-guard` included.
