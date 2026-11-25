# `bin/gates/pack/` — the gate pack's source

This folder is the one place the gate pack is kept. `bin/gates/pack.sh seat <repo>` copies it into an app repository.

| Path | What it is |
|---|---|
| `files.txt` | Ymir's wards the pack copies, each at the same path in the app (VENDORED `files:`) |
| `tree/` | the pack's own files, laid out exactly as they sit in the app (VENDORED `pack:`) |
| `gitleaks.toml` | the first `.gitleaks.toml` an app gets; after that it is the app's own |

> [!IMPORTANT]
> A change here changes every app repository. Run `bin/gates/tests/test_gate_pack.sh`, then re-seat each app with
> `bin/gates/pack.sh seat` and open one pull request per repository. `bin/gates/pack.sh status` shows which are behind.

The how-to is `docs/features/gate-pack.md`; the plan is the operator's plan 372.
