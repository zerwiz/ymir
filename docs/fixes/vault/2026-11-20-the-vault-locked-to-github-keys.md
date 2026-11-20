## vault · 2026-11-20 — the vault is locked to the owner's GitHub SSH keys, not to a key file beside it

Plan 342, phase 1. The tools, the readers, the ward and the how-to; the switch on a real
home is phase 2 and its confirmations are the Allfather's.

### What was wrong

The secrets vault (`hodd/secrets/platform.env.age`, 93 keys) was encrypted to
`hodd/secrets/age.key`, **committed in the same repository**. The lock and its key travelled
together, so the vault's only real protection was that the home repository is private, and
a plain-text `marketing-stack.env` sat beside it in the clear. Anything that could read the
repository held both halves.

### What this change does

- **`bin/vault/vault-relock.sh`** — the re-lock door. It reads the owner's public SSH keys
  through `gh api user/keys` (titles and keys) and falls back to
  `https://github.com/<login>.keys` when `gh` lacks the scope; it keeps **only** the keys the
  home declares in `config/vault-recipients.yaml` (by title and fingerprint), reports every
  GitHub key nobody declared and never uses it, and **refuses** to re-lock when a declared
  key cannot be used. It decrypts with this seat's own identity, re-encrypts to every
  declared recipient with `age -R`, decrypts the NEW file again and compares it **byte for
  byte** with the old plaintext before anything is replaced, keeps a timestamped backup, and
  ships only when asked (`--ship`, through `bin/vault/home-sync.sh`). Verbs: `--plan`,
  `--check`, `--relock`, `--add-machine`, `--recipients`.
- **`bin/vault/vault-identity-lib.sh`** — the one resolver for *which key opens the vault*:
  `$YMIR_VAULT_IDENTITY` → `identity:` in the declaration → `~/.ssh/id_ed25519`,
  `id_ed25519_sk`, `id_rsa` → `hodd/secrets/age.key` while it still exists. One order, every
  door.
- **The readers decrypt by SSH identity.** `bin/vault/hodd.sh` (`emit` / `load`) and
  `bin/vault/hodd-set.sh` walk that resolver instead of hardcoding `age.key`; `hodd-set.sh`
  re-encrypts to the declared recipients when no `age.key` is present (`vault-relock.sh
  --recipients`), so the writer keeps working after the key file is retired. **`hodd-set.sh`'s
  parser and guards were not touched** — only its identity and recipient lines — because
  errand `vault-writer-whole` is mending that half.
- **`bin/gates/guards/secrets-plaintext-guard.sh`** — refuses a commit that adds a
  non-empty plain-text `*.env` under `hodd/secrets/`, adds `hodd/secrets/age.key` back, or
  keeps changing a tracked plain-text secret there. An **empty** scaffold is allowed: the
  installer seeds one so `hodd.sh emit` resolves on a fresh home. It is seated in the home's
  own pre-commit hook by `bin/gates/guards/hoard-guard.sh --install`, beside the ward that
  reads for credential shapes.
- **Eir's `vaultkeys` surface** (`bin/agents/eir-doctor.sh`, registered in
  `config/surfaces.yaml`, risk `never`): the vault opens on this seat, the declarations match
  GitHub, and no plain `*.env` or `age.key` is tracked under `hodd/secrets` — **reported,
  never changed**, because a re-lock changes who may read the vault and that is the
  operator's step. A seat with no vault at all is a clean pass.
- **The public template** `config/vault-recipients.yaml.example` (invented titles) and the
  how-to `docs/features/the-vault-locked-to-your-github-keys.md` with its catalogue row.
- **The asset** `.agents/skills/galdr-ymirsystem/assets/vault-keys.md`.

Nothing here names a machine, a host or a person: the login is read from `gh` or declared in
the home, and the keys are whatever that account lists.

### Verified

- `bash bin/vault/tests/test_vault_relock.sh` — a throwaway home, four generated ed25519
  keys, a fake `gh` on `PATH`; **31 of 31 proofs pass**, and no value is ever printed:
  re-lock to keys A and B (each opens it, C cannot), an undeclared GitHub key reported and
  not used, a second re-lock byte-identical in content, a declared-but-absent key refusing
  and leaving the file byte for byte as it was, a failed re-encrypt keeping the old file,
  `hodd.sh emit`/`load` reading the vault with the SSH identity and **no `age.key` present**,
  a non-recipient seat refused, `hodd-set.sh` writing without `age.key`, the guard refusing a
  plain `.env` and a returning `age.key` and allowing an empty scaffold, and `--check`
  green for a recipient seat and exit 3 for one that cannot open it. It also proves the
  switch is not a cliff: a legacy `age.key` still opens an old vault while it exists, and an
  SSH key that is not a recipient does not stop that fallback.
- `bash bin/gates/guards/features-guard.sh` — every page catalogued, the woven catalogue
  current.
- `python3 bin/agents/surfaces.py config/surfaces.yaml` — `vaultkeys` reads back with risk
  `never`, roles `all`.
- `bin/agents/eir-doctor.sh check` on a fixture home — the `vaultkeys` row is not among the
  broken.

### Not done, and owed

Phases 2–4 of plan 342 are the Allfather's: declaring the recipients on the **real** home,
moving the marketing logins into the vault, retiring `hodd/secrets/age.key` with its Rule 11
record, shredding the stale plain text, and the history decision. This change never touches
the real vault and never imports a key.

### Files

- `bin/vault/vault-relock.sh` (new), `bin/vault/vault-identity-lib.sh` (new),
  `bin/vault/tests/test_vault_relock.sh` (new)
- `bin/vault/hodd.sh`, `bin/vault/hodd-set.sh` (identity selection only)
- `bin/gates/guards/secrets-plaintext-guard.sh` (new), `bin/gates/guards/hoard-guard.sh`
  (`--install` seats the new ward)
- `bin/agents/eir-doctor.sh` (`vaultkeys`), `config/surfaces.yaml`
- `config/vault-recipients.yaml.example` (new)
- `docs/features/the-vault-locked-to-your-github-keys.md` (new),
  `docs/features/_catalogue/entries/01-013-vault-the-vault-locked-to-your-github-keys.md` (new)
- `.agents/skills/galdr-ymirsystem/assets/vault-keys.md` (new), `SKILL.md`, `assets/README.md`

## CHANGE LOG

- 2026-11-20 — review-mend: added missing heading for #848
