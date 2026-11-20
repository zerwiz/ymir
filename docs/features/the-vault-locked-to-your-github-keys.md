# The vault locked to your GitHub SSH keys

## What it is

Your credentials live in the vault — `hodd/secrets/platform.env.age` in your home — and
the vault is encrypted with `age`. This page is about **which keys can open it**.

The lock used to be a key file kept in the same repository as the vault
(`hodd/secrets/age.key`). One lock with its key taped to it: whoever could read the
repository held both halves. Now the vault is encrypted to **your GitHub SSH keys**. Each
machine opens it with its own private SSH key, which never leaves that machine, and no key
file sits in the repository at all. A machine is added or removed by adding or removing
its key on GitHub and re-locking.

## What you need

- `age` and the OpenSSH client (`ssh-keygen`) on the machine.
- `gh`, signed in to **your own** GitHub account — that login is how your public keys are
  read. No shared token is involved, and nothing here is specific to one person's machine.
- The keys you want on GitHub, added once per machine:
  `gh ssh-key add ~/.ssh/id_ed25519.pub --title <machine>`
- A declaration in your home: `config/vault-recipients.yaml`. Start from
  `config/vault-recipients.yaml.example` — invented titles, your own in their place.

## Do it

### 1. Say which machines may open the vault

```yaml
# <your home>/config/vault-recipients.yaml
vault: hodd/secrets/platform.env.age
recipients:
  - title: laptop-a
    fingerprint: SHA256:…
    machine: the everyday laptop
  - title: server-a
    fingerprint: SHA256:…
    machine: the always-on host
```

The **title** is how you find the key on GitHub. The **fingerprint** is how you prove it
is the same key — a title can be reused, a fingerprint cannot. Read a fingerprint with
`ssh-keygen -lf ~/.ssh/id_ed25519.pub`.

A key GitHub lists that you do not declare is **reported and never used**, so a phone or
an old box needs no ceremony to stay out. A key you declare that GitHub does not list
**refuses the re-lock**: quietly dropping that machine's access is the one thing this
file exists to prevent.

### 2. Look before you lock

```bash
bin/vault/vault-relock.sh --plan
```

It names, by title, the keys that would be used, the keys GitHub lists that nobody
declared, and — against the record of your last re-lock — which machines would be **added**
or **dropped**. It writes nothing.

### 3. Re-lock

```bash
bin/vault/vault-relock.sh --relock
```

Three guards run before anything is replaced. The vault is decrypted with this machine's
own key; it is re-encrypted to every declared key; the **new** file is decrypted again and
compared with the old plaintext **byte for byte**. Only then does it replace the file, and
the old one is kept beside it as `platform.env.age.bak-<timestamp>`. The plaintext never
touches the disk except a temp file that is shredded on exit.

Add `--ship` to send the re-locked file through `bin/vault/home-sync.sh ship` in the same
breath.

### 4. Add this machine

```bash
bin/vault/vault-relock.sh --add-machine
```

It prints the one `gh ssh-key add` command for this machine and then re-locks. If GitHub
answers that the key is already in use, the key is listed — declare its **existing** title
in `config/vault-recipients.yaml` and re-run `--plan`.

### 5. Check it, any time

```bash
bin/vault/vault-relock.sh --check
```

It answers four things and prints no value: whether this seat opens the vault with its own
SSH key, whether the declared keys still match GitHub, how many GitHub keys nobody
declared, and whether a plain `*.env` or a returning `age.key` is still tracked under
`hodd/secrets` — **reported, never changed**. `--strict` turns those warnings into a fault;
`--quiet` leaves only the exit code, which is how Eir's `vaultkeys` surface reads it.

### 6. Read the vault

Nothing changes for a reader: `bin/vault/hodd.sh emit secrets/platform.env` decrypts with
this seat's SSH identity, and falls back to the old `age.key` only while that file still
exists. The order is one resolver, `bin/vault/vault-identity-lib.sh`:
`$YMIR_VAULT_IDENTITY` → `identity:` in the declaration → `~/.ssh/id_ed25519`,
`id_ed25519_sk`, `id_rsa` → `hodd/secrets/age.key`.

## What the ward refuses

`bin/gates/guards/secrets-plaintext-guard.sh` runs in the home's own pre-commit hook
(seated by `bin/gates/guards/hoard-guard.sh --install`). It refuses a commit that

- **adds a non-empty plain-text `*.env`** under `hodd/secrets/` — an empty scaffold is
  allowed, because the installer seeds one so `hodd.sh emit` resolves on a fresh home;
- **adds `hodd/secrets/age.key` back** — a key file beside the vault re-opens it for anyone
  who can read the repository;
- **changes a plain-text `*.env`** that is already tracked there.

## Limits, said plainly

- **The history still holds the old lock.** Every past commit still carries the old
  `age.key` and the old encrypted vaults, so anyone who can read the repository can open
  the *old* secrets. This page protects what you add from now on; it does not reach
  backwards. Rotating the credentials that are still live is the honest answer.
- **A title can be reused; a fingerprint cannot.** Declare fingerprints.
- **The re-lock needs one machine that can already open the vault**, because it decrypts
  before it re-encrypts. Keep a backup of a working identity until every recipient has
  proved it opens the vault.
- **A key can be copied off a compromised machine.** SSH keys are the lock, not a
  hardware token; FIDO2 is the stronger road for the document vault
  (`docs/features/fido2-unlock-the-vault.md`).

## If it does not work

- `cannot decrypt … this seat is not a recipient` — this machine's key is not among the
  declared keys, or was added to GitHub after the last re-lock. Run `--plan`, declare the
  title, then `--relock` from a machine that can still open it.
- `the owner's public keys could not be read` — `gh` lacks the scope and GitHub's public
  list did not answer: `gh auth refresh -s read:public_key`.
- `no declarations at …` — copy `config/vault-recipients.yaml.example` into the home as
  `config/vault-recipients.yaml`.
- `a declared key cannot be used` — the title is misspelled, the fingerprint is another
  key, or GitHub does not list it. `--plan` names which.

## The commands, in one block

```bash
bin/vault/vault-relock.sh --plan                        # who, and what changes
bin/vault/vault-relock.sh --relock [--ship]             # lock it, and prove it round-trips
bin/vault/vault-relock.sh --add-machine [--title NAME]  # this machine's key, then re-lock
bin/vault/vault-relock.sh --check [--strict] [--quiet]  # does this seat open it, does it match GitHub
bin/vault/hodd.sh emit secrets/platform.env             # read it, through this seat's SSH key
```

## CHANGE LOG

- **2026-11-20** — written with phase 1 of plan 342, at the Allfather's word: the re-lock door, the readers decrypting by SSH identity, the ward, and Eir's `vaultkeys` surface. The proof is `bin/vault/tests/test_vault_relock.sh`.
