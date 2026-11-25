---
section: core-install-run-operate
---
| Gate | **The gate pack** (`bin/gates/pack.sh` · `bin/gates/pack/`) | Every app repository carries Ymir's own secret, personal-data, identity and vault wards, copied byte for byte with one door (`bin/gates/run-gates.sh`) for the hooks and for CI, a planted-fault test per gate, and a sync check that fails when a copy differs from Ymir or falls behind Ymir's `main`. `seat` · `check` · `status` are the verbs, and Eir's `gatepack` row shows each repository as current, behind or absent. The operator's deny list never leaves the home: the hooks read it there, and CI judges shapes only | [The gate pack](docs/features/gate-pack.md) |
