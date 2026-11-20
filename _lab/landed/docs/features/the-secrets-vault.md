# The secrets vault

## What it is

Ymir's credentials live in **the hoard**, encrypted at rest, and are **referenced by
path** — never pasted into the tree, a script, or a config in the repo. A script that
needs a key asks the hoard; it never carries one. Private data lives at `$YMIR_HOME`
(Rule 04), and the secrets themselves are age‑encrypted (`platform.env.age`).

## What you need

- Ymir installed. `age` is used to decrypt; the installer provisions it.

## Do it

```bash
# where the hoard is
bin/vault/hodd.sh path

# create the layout (idempotent)
bin/vault/hodd.sh init

# what it holds — names, never contents
bin/vault/hodd.sh ls

# load a hoard env into your shell (quoting-safe), decrypting an .age sibling if needed
eval "$(bin/vault/hodd.sh emit secrets/platform.env)"

# source a tenant's env — that tenant only
bin/vault/hodd.sh tenant acme
```

Scripts do not read the ciphertext themselves: `hodd.sh` resolves the path, decrypting
in memory to a temporary file (mode 600) that it removes. A script asks for the
**resolved path**:

```bash
bin/vault/hodd.sh load secrets/platform.env    # loads it, then prints one TOON line
```

## Where things live

| Thing | Path |
|---|---|
| Hoard root | `$YMIR_HOARD` → `$YMIR_HOME` → `~/Documents/ymirhome` |
| Secrets | `<hoard>/secrets/` (`platform.env.age`, plus the `age.key`) |
| Tenants | `<hoard>/tenants/<name>/.env` |

## Notes and limits

- **The repo is public; the home is the vault.** A secret, a key, a name, a plan, a
  schedule — none may sit in the repo, in any form, not even as an "example" filled with
  the real value. `.example` files carry synthetic shapes.
- **Wards guard the boundary.** `secret-guard` (a credential value) and `private-guard`
  (operator identity/topology) run on every commit and push; a hit **refuses the push**.
- **Encrypted at rest.** The plaintext is not kept lying around; `hodd.sh` decrypts to
  a temp it removes. Keep a copy of the master key safe — losing it loses the data.
- **A secret is referenced, never inlined.** `GITHUB_TOKEN`, not the token; the path,
  not the value.

## If it does not work

| What you see | What to do |
|---|---|
| `not readable … and no …age` | The secret is absent — put it in `<hoard>/secrets/` (encrypted), not in the tree. |
| `encrypted but age is not installed` | `sudo pacman -S age` (or your platform's equivalent). |
| `encrypted … but no key at …/age.key` | The master key is missing from the hoard — restore it from your safe copy. |
| A commit is refused by `secret-guard` | A secret is staged — remove it and reference it from the hoard instead. |

See also: [`docs/guides/SECRETS.md`](../guides/SECRETS.md).
