## gate · unversioned · 2026-10-11 — Rule 16: the confidential session (Rule 15's companion)

### What

Rule 15 says *vault content never leaves*. Rule 16 makes it **structural**: a
confidential session in which there is no route off the vault.

- **`RULES/16-confidential-session.md`** — the law: work only inside the vault; every
  off-vault record door (well, tickets, runes, daily log) OFF; an explicit model tier;
  `--airlock`/`--sandbox` for isolation; nothing outside may be committed while live.
- **`bin/vault/confidential.sh`** — the door:
  - `start [--tier local|none|remote] [--airlock] [--sandbox] [--name NAME] [-- CMD…]`;
  - the workdir is **inside the vault** (`$VAULT_MNT/confidential/<name>`);
  - **tier `local`** (default) uses the on-machine router only; **`none`** = no model;
    **`remote`** = the operator's provider, chosen explicitly;
  - **`--airlock`** = an interactive `bwrap --unshare-net` shell (no network at all);
  - **`--sandbox`** = a sealed one-shot through **Utgard** (`bin/forge/utgard.sh run …
    --network none`): read-only rootfs, **only the workdir mounted**, caps — the
    strongest isolation, and it uses the sandbox engine Ymir already deploys
    (sandcastle/docker) rather than a hand-rolled barrier.
- **`bin/gates/guards/confidential-guard.sh`** — while a session marker is live, it
  **refuses to commit any file whose path is not inside the vault**. Seated in
  `guards.sh` and in both pre-commit hooks (`secret-guard --install`,
  `hoard-guard --install` now write it).
- **`AGENTS.md`** — the duty: for vault work, use a session; do not work on vault
  content outside one. `FEATURES.md` + `docs/features/confidential-session.md` carry
  the user-facing how-to.

### Verified

- `tests/e2e/confidential-proof.sh` — **all pass**: no-session clean; a file outside
  the vault is refused while a session is live; a file inside is allowed; the door
  reports the session; and **the Utgard sandbox one-shot actually runs**.
- `guards.sh` → runtime · defaults · cron · features · vault · **confidential** all PASS.

### Files

- `RULES/16-confidential-session.md` (new), `RULES/README.md`
- `bin/vault/confidential.sh` (new)
- `bin/gates/guards/confidential-guard.sh` (new), `bin/gates/guards.sh`,
  `bin/gates/guards/secret-guard.sh`, `bin/gates/guards/hoard-guard.sh`
- `tests/e2e/confidential-proof.sh` (new)
- `AGENTS.md`, `FEATURES.md`, `docs/features/confidential-session.md`
